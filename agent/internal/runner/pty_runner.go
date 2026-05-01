package runner

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"sync"

	"github.com/creack/pty"
)

type RunnerEvent struct {
	Type     string // "output" | "exit" | "error"
	Data     []byte
	ExitCode int
	Err      error
}

type CommandSpec struct {
	Bin     string
	Args    []string
	Workdir string
	Env     []string
	UsePTY  bool
}

type PTYRunner struct {
	cmd    *exec.Cmd
	ptmx   *os.File
	events chan RunnerEvent
	done   chan struct{}
	once   sync.Once
}

func NewPTYRunner() *PTYRunner {
	return &PTYRunner{
		events: make(chan RunnerEvent, 256),
		done:   make(chan struct{}),
	}
}

func (r *PTYRunner) Start(ctx context.Context, spec CommandSpec) error {
	r.cmd = exec.CommandContext(ctx, spec.Bin, spec.Args...)
	if spec.Workdir != "" {
		r.cmd.Dir = spec.Workdir
	}
	if len(spec.Env) > 0 {
		r.cmd.Env = append(os.Environ(), spec.Env...)
	}

	if spec.UsePTY {
		ptmx, err := pty.Start(r.cmd)
		if err != nil {
			return fmt.Errorf("pty start: %w", err)
		}
		r.ptmx = ptmx
	} else {
		r.cmd.Stdin = os.Stdin
		r.cmd.Stdout = os.Stdout
		r.cmd.Stderr = os.Stderr
		if err := r.cmd.Start(); err != nil {
			return fmt.Errorf("start: %w", err)
		}
	}

	go r.readLoop()
	go r.waitExit()

	return nil
}

func (r *PTYRunner) readLoop() {
	if r.ptmx == nil {
		return
	}
	defer close(r.done)

	buf := make([]byte, 4096)
	for {
		n, err := r.ptmx.Read(buf)
		if n > 0 {
			data := make([]byte, n)
			copy(data, buf[:n])
			r.events <- RunnerEvent{Type: "output", Data: data}
		}
		if err != nil {
			if err.Error() != "EOF" {
				r.events <- RunnerEvent{Type: "error", Err: err}
			}
			return
		}
	}
}

func (r *PTYRunner) waitExit() {
	err := r.cmd.Wait()
	exitCode := 0
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			exitCode = exitErr.ExitCode()
		}
	}
	r.once.Do(func() {
		r.events <- RunnerEvent{Type: "exit", ExitCode: exitCode}
		close(r.events)
	})
}

func (r *PTYRunner) Write(data []byte) error {
	if r.ptmx == nil {
		return fmt.Errorf("pty not initialized")
	}
	_, err := r.ptmx.Write(data)
	return err
}

func (r *PTYRunner) Resize(cols, rows int) error {
	if r.ptmx == nil {
		return fmt.Errorf("pty not initialized")
	}
	return pty.Setsize(r.ptmx, &pty.Winsize{Cols: uint16(cols), Rows: uint16(rows)})
}

func (r *PTYRunner) Stop() error {
	if r.cmd != nil && r.cmd.Process != nil {
		return r.cmd.Process.Signal(os.Interrupt)
	}
	return fmt.Errorf("process not running")
}

func (r *PTYRunner) Kill() error {
	if r.cmd != nil && r.cmd.Process != nil {
		return r.cmd.Process.Kill()
	}
	return fmt.Errorf("process not running")
}

func (r *PTYRunner) Events() <-chan RunnerEvent {
	return r.events
}

func (r *PTYRunner) Done() <-chan struct{} {
	return r.done
}
