package claude

import (
	"context"
	"fmt"
	"os/exec"
	"sync"
	"time"

	"github.com/Teddy-Zhu/magent/agent/internal/provider"
	"github.com/Teddy-Zhu/magent/agent/internal/runner"
	"github.com/google/uuid"
)

type ClaudeProvider struct {
	runners  map[string]*runner.PTYRunner
	sessions map[string]chan provider.ProviderEvent
	metadata map[string]provider.Session
	mu       sync.RWMutex
}

func New() *ClaudeProvider {
	return &ClaudeProvider{
		runners:  make(map[string]*runner.PTYRunner),
		sessions: make(map[string]chan provider.ProviderEvent),
		metadata: make(map[string]provider.Session),
	}
}

func (p *ClaudeProvider) Name() string { return "claude" }

func (p *ClaudeProvider) Detect(ctx context.Context) (*provider.ProviderInfo, error) {
	bin, err := exec.LookPath("claude")
	if err != nil {
		return nil, fmt.Errorf("claude not found: %w", err)
	}

	version := "unknown"
	if out, err := exec.CommandContext(ctx, bin, "--version").CombinedOutput(); err == nil {
		version = string(out)
	}

	return &provider.ProviderInfo{
		Name:    "claude",
		Version: version,
		Binary:  bin,
		Status:  "available",
		RunMode: "pty",
		Capabilities: provider.ProviderCapabilities{
			Protocol:          "pty",
			SupportsResume:    false,
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

func (p *ClaudeProvider) CreateSession(ctx context.Context, req provider.CreateSessionRequest) (*provider.Session, error) {
	req.ApplyDefaults(p.Config())
	sessionID := uuid.New().String()

	r := runner.NewPTYRunner()
	if err := r.Start(ctx, runner.CommandSpec{
		Bin:     "claude",
		Args:    claudeArgs(req),
		Workdir: req.Workdir,
		UsePTY:  true,
	}); err != nil {
		return nil, fmt.Errorf("start claude: %w", err)
	}

	session := provider.Session{
		ID:         sessionID,
		ProviderID: "claude",
		ProjectID:  req.ProjectID,
		Workdir:    req.Workdir,
		Status:     string(provider.SessionStatusRunning),
		RunnerType: "pty",
		Model:      req.Model,
		CreatedAt:  time.Now(),
		UpdatedAt:  time.Now(),
	}

	p.mu.Lock()
	p.runners[sessionID] = r
	ch := make(chan provider.ProviderEvent, 256)
	p.sessions[sessionID] = ch
	p.metadata[sessionID] = session
	p.mu.Unlock()

	if req.Prompt != "" {
		r.Write([]byte(req.Prompt + "\n"))
	}

	go p.collectOutput(sessionID, r)

	return &session, nil
}

func (p *ClaudeProvider) collectOutput(sessionID string, r *runner.PTYRunner) {
	p.mu.RLock()
	ch := p.sessions[sessionID]
	p.mu.RUnlock()

	for event := range r.Events() {
		evt, ok := claudeRunnerEvent(sessionID, event)

		if ok && ch != nil {
			select {
			case ch <- evt:
			default:
			}
		}

		if event.Type == "exit" || event.Type == "error" {
			p.mu.Lock()
			delete(p.runners, sessionID)
			delete(p.metadata, sessionID)
			p.mu.Unlock()
			return
		}
	}
}

func (p *ClaudeProvider) ResumeSession(ctx context.Context, sessionID, threadID string) error {
	return fmt.Errorf("claude does not support resume")
}

func (p *ClaudeProvider) ForkSession(ctx context.Context, sessionID, threadID string) (string, error) {
	return "", fmt.Errorf("claude does not support fork")
}

func (p *ClaudeProvider) SendInput(ctx context.Context, sessionID string, input provider.SendInputRequest) error {
	p.mu.RLock()
	r, ok := p.runners[sessionID]
	p.mu.RUnlock()
	if !ok {
		return fmt.Errorf("session %s not found", sessionID)
	}
	return r.Write([]byte(input.Input + "\n"))
}

func (p *ClaudeProvider) InterruptSession(ctx context.Context, sessionID string) error {
	p.mu.RLock()
	r, ok := p.runners[sessionID]
	p.mu.RUnlock()
	if !ok {
		return fmt.Errorf("session %s not found", sessionID)
	}
	return r.Stop()
}

func (p *ClaudeProvider) StopSession(ctx context.Context, sessionID string) error {
	p.mu.Lock()
	r, ok := p.runners[sessionID]
	if ok {
		delete(p.runners, sessionID)
	}
	ch, hasCh := p.sessions[sessionID]
	if hasCh {
		delete(p.sessions, sessionID)
	}
	delete(p.metadata, sessionID)
	p.mu.Unlock()

	if !ok {
		return fmt.Errorf("session %s not found", sessionID)
	}

	if hasCh {
		close(ch)
	}
	return r.Kill()
}

func (p *ClaudeProvider) CompactSession(ctx context.Context, sessionID string) error {
	return fmt.Errorf("claude does not support compact")
}

func (p *ClaudeProvider) RollbackSession(ctx context.Context, sessionID string, turns int) error {
	return fmt.Errorf("claude does not support rollback")
}

func (p *ClaudeProvider) ResolveApproval(ctx context.Context, sessionID, approvalID string, decision provider.ApprovalDecision) error {
	return fmt.Errorf("claude does not support approval")
}

func (p *ClaudeProvider) Subscribe(sessionID string) <-chan provider.ProviderEvent {
	p.mu.Lock()
	defer p.mu.Unlock()
	ch, ok := p.sessions[sessionID]
	if !ok {
		ch = make(chan provider.ProviderEvent, 256)
		p.sessions[sessionID] = ch
	}
	return ch
}

func (p *ClaudeProvider) Unsubscribe(sessionID string) {
	// No-op: channel is cleaned up when the session exits
}

func (p *ClaudeProvider) Capabilities() provider.ProviderCapabilities {
	return provider.ProviderCapabilities{
		Protocol:          "pty",
		SupportsResume:    false,
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

func (p *ClaudeProvider) ListThreads(ctx context.Context, cwd string, limit int) ([]provider.Session, error) {
	p.mu.RLock()
	defer p.mu.RUnlock()

	sessions := make([]provider.Session, 0, len(p.metadata))
	for _, session := range p.metadata {
		if cwd != "" && session.Workdir != cwd {
			continue
		}
		session.Status = string(provider.SessionStatusRunning)
		sessions = append(sessions, session)
		if limit > 0 && len(sessions) >= limit {
			break
		}
	}
	return sessions, nil
}

func (p *ClaudeProvider) HasSession(sessionID string) bool {
	p.mu.RLock()
	_, ok := p.runners[sessionID]
	p.mu.RUnlock()
	return ok
}

func (p *ClaudeProvider) ReadThreadEvents(ctx context.Context, threadID, cursor string, limit int) (*provider.EventPage, error) {
	return &provider.EventPage{SessionID: threadID, Events: []provider.ProviderEvent{}}, nil
}

func (p *ClaudeProvider) ReadThreadItems(ctx context.Context, threadID, cursor string, limit int) (*provider.ItemPage, error) {
	return &provider.ItemPage{SessionID: threadID, Items: []provider.SessionItem{}}, nil
}

func (p *ClaudeProvider) Close() error {
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
	p.metadata = make(map[string]provider.Session)
	return nil
}
