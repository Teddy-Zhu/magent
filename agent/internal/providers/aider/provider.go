package aider

import (
	"context"
	"fmt"
	"os/exec"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/Teddy-Zhu/magent/agent/internal/provider"
	"github.com/Teddy-Zhu/magent/agent/internal/runner"
)

type AiderProvider struct {
	runners  map[string]*runner.PTYRunner
	sessions map[string]chan provider.ProviderEvent
	mu       sync.RWMutex
}

func New() *AiderProvider {
	return &AiderProvider{
		runners:  make(map[string]*runner.PTYRunner),
		sessions: make(map[string]chan provider.ProviderEvent),
	}
}

func (p *AiderProvider) Name() string { return "aider" }

func (p *AiderProvider) Detect(ctx context.Context) (*provider.ProviderInfo, error) {
	bin, err := exec.LookPath("aider")
	if err != nil {
		return nil, fmt.Errorf("aider not found: %w", err)
	}

	version := "unknown"
	if out, err := exec.CommandContext(ctx, bin, "--version").CombinedOutput(); err == nil {
		version = string(out)
	}

	return &provider.ProviderInfo{
		Name:    "aider",
		Version: version,
		Binary:  bin,
		Status:  "available",
		RunMode: "pty",
		Capabilities: provider.ProviderCapabilities{
			Protocol:          "pty",
			SupportsResume:    true,
			SupportsFork:      false,
			SupportsSteer:     false,
			SupportsInterrupt: true,
			SupportsCompact:   false,
			SupportsRollback:  false,
			SupportsPTY:       true,
			StructuredOutput:  false,
			StreamingOutput:   true,
		},
	}, nil
}

func (p *AiderProvider) CreateSession(ctx context.Context, req provider.CreateSessionRequest) (*provider.Session, error) {
	req.ApplyDefaults(p.Config())
	sessionID := uuid.New().String()

	r := runner.NewPTYRunner()
	if err := r.Start(ctx, runner.CommandSpec{
		Bin:     "aider",
		Args:    aiderArgs(req),
		Workdir: req.Workdir,
		UsePTY:  true,
	}); err != nil {
		return nil, fmt.Errorf("start aider: %w", err)
	}

	p.mu.Lock()
	p.runners[sessionID] = r
	ch := make(chan provider.ProviderEvent, 256)
	p.sessions[sessionID] = ch
	p.mu.Unlock()

	if req.Prompt != "" {
		r.Write([]byte(req.Prompt + "\n"))
	}

	go p.collectOutput(sessionID, r)

	return &provider.Session{
		ID:         sessionID,
		ProviderID: "aider",
		ProjectID:  req.ProjectID,
		Workdir:    req.Workdir,
		Status:     string(provider.SessionStatusRunning),
		RunnerType: "pty",
		Model:      req.Model,
		CreatedAt:  time.Now(),
		UpdatedAt:  time.Now(),
	}, nil
}

func (p *AiderProvider) collectOutput(sessionID string, r *runner.PTYRunner) {
	p.mu.RLock()
	ch := p.sessions[sessionID]
	p.mu.RUnlock()

	for event := range r.Events() {
		evt, ok := aiderRunnerEvent(sessionID, event)

		if ok && ch != nil {
			select {
			case ch <- evt:
			default:
			}
		}

		if event.Type == "exit" || event.Type == "error" {
			p.mu.Lock()
			delete(p.runners, sessionID)
			p.mu.Unlock()
			return
		}
	}
}

func (p *AiderProvider) ResumeSession(ctx context.Context, sessionID, threadID string) error {
	return fmt.Errorf("aider resume not yet implemented")
}

func (p *AiderProvider) ForkSession(ctx context.Context, sessionID, threadID string) (string, error) {
	return "", fmt.Errorf("aider does not support fork")
}

func (p *AiderProvider) SendInput(ctx context.Context, sessionID string, input provider.SendInputRequest) error {
	p.mu.RLock()
	r, ok := p.runners[sessionID]
	p.mu.RUnlock()
	if !ok {
		return fmt.Errorf("session %s not found", sessionID)
	}
	return r.Write([]byte(input.Input + "\n"))
}

func (p *AiderProvider) InterruptSession(ctx context.Context, sessionID string) error {
	p.mu.RLock()
	r, ok := p.runners[sessionID]
	p.mu.RUnlock()
	if !ok {
		return fmt.Errorf("session %s not found", sessionID)
	}
	return r.Stop()
}

func (p *AiderProvider) StopSession(ctx context.Context, sessionID string) error {
	p.mu.Lock()
	r, ok := p.runners[sessionID]
	if ok {
		delete(p.runners, sessionID)
	}
	ch, hasCh := p.sessions[sessionID]
	if hasCh {
		delete(p.sessions, sessionID)
	}
	p.mu.Unlock()

	if !ok {
		return fmt.Errorf("session %s not found", sessionID)
	}

	if hasCh {
		close(ch)
	}
	return r.Kill()
}

func (p *AiderProvider) CompactSession(ctx context.Context, sessionID string) error {
	return fmt.Errorf("aider does not support compact")
}

func (p *AiderProvider) RollbackSession(ctx context.Context, sessionID string, turns int) error {
	return fmt.Errorf("aider does not support rollback")
}

func (p *AiderProvider) ResolveApproval(ctx context.Context, sessionID, approvalID string, decision provider.ApprovalDecision) error {
	return fmt.Errorf("aider does not support approval")
}

func (p *AiderProvider) Subscribe(sessionID string) <-chan provider.ProviderEvent {
	p.mu.Lock()
	defer p.mu.Unlock()
	ch, ok := p.sessions[sessionID]
	if !ok {
		ch = make(chan provider.ProviderEvent, 256)
		p.sessions[sessionID] = ch
	}
	return ch
}

func (p *AiderProvider) Unsubscribe(sessionID string) {
	// No-op: channel is cleaned up when the session exits
}

func (p *AiderProvider) Capabilities() provider.ProviderCapabilities {
	return provider.ProviderCapabilities{
		Protocol:          "pty",
		SupportsResume:    true,
		SupportsFork:      false,
		SupportsSteer:     false,
		SupportsInterrupt: true,
		SupportsCompact:   false,
		SupportsRollback:  false,
		SupportsPTY:       true,
		StructuredOutput:  false,
		StreamingOutput:   true,
	}
}

func (p *AiderProvider) ListThreads(ctx context.Context, cwd string, limit int) ([]provider.Session, error) {
	return nil, nil
}

func (p *AiderProvider) HasSession(sessionID string) bool {
	p.mu.RLock()
	_, ok := p.runners[sessionID]
	p.mu.RUnlock()
	return ok
}

func (p *AiderProvider) ReadThreadEvents(ctx context.Context, threadID, cursor string, limit int) (*provider.EventPage, error) {
	return &provider.EventPage{SessionID: threadID, Events: []provider.ProviderEvent{}}, nil
}

func (p *AiderProvider) ReadThreadItems(ctx context.Context, threadID, cursor string, limit int) (*provider.ItemPage, error) {
	return &provider.ItemPage{SessionID: threadID, Items: []provider.SessionItem{}}, nil
}

func (p *AiderProvider) Close() error {
	p.mu.Lock()
	defer p.mu.Unlock()
	for _, r := range p.runners {
		r.Kill()
	}
	for _, ch := range p.sessions {
		close(ch)
	}
	p.runners = make(map[string]*runner.PTYRunner)
	p.sessions = make(map[string]chan provider.ProviderEvent)
	return nil
}
