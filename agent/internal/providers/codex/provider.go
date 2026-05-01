package codex

import (
	"context"
	"fmt"
	"os/exec"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/magent/agent/internal/log"
	"github.com/magent/agent/internal/provider"
	"github.com/magent/agent/internal/ws"
)

type CodexConfig struct {
	Binary string
}

type CodexProvider struct {
	clients      map[string]*AppServerClient
	clientsMu    sync.RWMutex
	sessions     map[string]chan provider.ProviderEvent
	sessionsMu   sync.RWMutex
	approval     *ApprovalProxy
	cfg          CodexConfig
	cachedConfig *provider.ProviderConfig
	configMu     sync.RWMutex
}

func New(cfg CodexConfig, hub *ws.Hub) *CodexProvider {
	return &CodexProvider{
		clients:  make(map[string]*AppServerClient),
		sessions: make(map[string]chan provider.ProviderEvent),
		approval: NewApprovalProxy(hub),
		cfg:      cfg,
	}
}

func (p *CodexProvider) Name() string { return "codex" }

func (p *CodexProvider) Detect(ctx context.Context) (*provider.ProviderInfo, error) {
	binary := p.cfg.Binary
	if binary == "" {
		var err error
		binary, err = exec.LookPath("codex")
		if err != nil {
			return nil, fmt.Errorf("codex not found: %w", err)
		}
	}

	log.Debug("codex", "detected binary=%s", binary)
	return &provider.ProviderInfo{
		Name:    "codex",
		Binary:  binary,
		Status:  "available",
		RunMode: "app-server-stdio",
		Capabilities: p.Capabilities(),
	}, nil
}

func (p *CodexProvider) CreateSession(ctx context.Context, req provider.CreateSessionRequest) (*provider.Session, error) {
	binary := p.cfg.Binary
	if binary == "" {
		var err error
		binary, err = exec.LookPath("codex")
		if err != nil {
			return nil, fmt.Errorf("codex not found: %w", err)
		}
	}

	log.Debug("codex", "creating session binary=%s model=%s workdir=%s", binary, req.Model, req.Workdir)
	client, err := NewAppServerClient(ctx, binary)
	if err != nil {
		log.Error("codex", "appserver client failed: %v", err)
		return nil, err
	}

	if err := client.Initialize(ctx); err != nil {
		log.Error("codex", "initialize failed: %v", err)
		client.Close()
		return nil, err
	}

	threadID, err := client.StartThread(ctx, req.Model, req.Workdir, req.ApprovalPolicy, req.SandboxMode)
	if err != nil {
		log.Error("codex", "start thread failed: %v", err)
		client.Close()
		return nil, err
	}

	sessionID := uuid.New().String()
	log.Info("codex", "session created id=%s thread=%s", sessionID, threadID)
	p.clientsMu.Lock()
	p.clients[sessionID] = client
	p.clientsMu.Unlock()

	go p.forwardEvents(sessionID, client)

	if req.Prompt != "" {
		log.Debug("codex", "sending initial prompt len=%d", len(req.Prompt))
		if err := client.StartTurn(ctx, threadID, req.Prompt, req.Workdir, req.ApprovalPolicy, req.SandboxMode, req.Model, req.Effort); err != nil {
			log.Error("codex", "start turn failed: %v", err)
			p.StopSession(ctx, sessionID)
			return nil, err
		}
	}

	return &provider.Session{
		ID:         sessionID,
		ProviderID: "codex",
		ThreadID:   threadID,
		ProjectID:  req.ProjectID,
		Workdir:    req.Workdir,
		Status:     "running",
		RunnerType: "app-server",
		Model:      req.Model,
	}, nil
}

func (p *CodexProvider) forwardEvents(sessionID string, client *AppServerClient) {
	for event := range client.Events() {
		event.SessionID = sessionID

		if event.Type == "session.approval_request" {
			if req, ok := event.Payload.(map[string]any); ok {
				approvalReq := ApprovalRequest{
					ID:        fmt.Sprintf("%v", req["id"]),
					SessionID: sessionID,
					Type:      fmt.Sprintf("%v", req["type"]),
					Command:   fmt.Sprintf("%v", req["command"]),
					FilePath:  fmt.Sprintf("%v", req["file_path"]),
				}
				decision := p.approval.HandleRequest(context.Background(), approvalReq)
				client.notify("approval/decision", map[string]any{
					"id":     approvalReq.ID,
					"action": decision.Action,
				})
			}
			continue
		}

		p.emit(sessionID, event)
	}
}

func (p *CodexProvider) emit(sessionID string, event provider.ProviderEvent) {
	p.sessionsMu.RLock()
	ch, ok := p.sessions[sessionID]
	p.sessionsMu.RUnlock()
	if ok {
		select {
		case ch <- event:
		default:
		}
	}
}

func (p *CodexProvider) Subscribe(sessionID string) <-chan provider.ProviderEvent {
	p.sessionsMu.Lock()
	defer p.sessionsMu.Unlock()
	ch := make(chan provider.ProviderEvent, 256)
	p.sessions[sessionID] = ch
	return ch
}

func (p *CodexProvider) Unsubscribe(sessionID string) {
	p.sessionsMu.Lock()
	defer p.sessionsMu.Unlock()
	if ch, ok := p.sessions[sessionID]; ok {
		close(ch)
		delete(p.sessions, sessionID)
	}
}

func (p *CodexProvider) ResumeSession(ctx context.Context, sessionID, threadID string) error {
	p.clientsMu.RLock()
	_, ok := p.clients[sessionID]
	p.clientsMu.RUnlock()
	if ok {
		return nil
	}
	return fmt.Errorf("session %s not found", sessionID)
}

func (p *CodexProvider) ForkSession(ctx context.Context, sessionID, threadID string) (string, error) {
	return "", fmt.Errorf("fork not implemented")
}

func (p *CodexProvider) SendInput(ctx context.Context, sessionID, input string) error {
	p.clientsMu.RLock()
	client, ok := p.clients[sessionID]
	p.clientsMu.RUnlock()
	if !ok {
		return fmt.Errorf("session %s not found", sessionID)
	}

	p.clientsMu.RLock()
	threadID := client.threadIDs[sessionID]
	p.clientsMu.RUnlock()

	return client.SteerTurn(ctx, threadID, input)
}

func (p *CodexProvider) InterruptSession(ctx context.Context, sessionID string) error {
	p.clientsMu.RLock()
	client, ok := p.clients[sessionID]
	p.clientsMu.RUnlock()
	if !ok {
		return fmt.Errorf("session %s not found", sessionID)
	}

	p.clientsMu.RLock()
	threadID := client.threadIDs[sessionID]
	p.clientsMu.RUnlock()

	return client.InterruptTurn(ctx, threadID)
}

func (p *CodexProvider) StopSession(ctx context.Context, sessionID string) error {
	p.clientsMu.Lock()
	client, ok := p.clients[sessionID]
	if ok {
		delete(p.clients, sessionID)
	}
	p.clientsMu.Unlock()
	if !ok {
		return fmt.Errorf("session %s not found", sessionID)
	}
	return client.Close()
}

func (p *CodexProvider) CompactSession(ctx context.Context, sessionID string) error {
	return fmt.Errorf("compact not implemented")
}

func (p *CodexProvider) RollbackSession(ctx context.Context, sessionID string, turns int) error {
	return fmt.Errorf("rollback not implemented")
}

func (p *CodexProvider) Capabilities() provider.ProviderCapabilities {
	return provider.ProviderCapabilities{
		Protocol:           "app-server-stdio",
		SupportsResume:     false,
		SupportsFork:       false,
		SupportsSteer:      true,
		SupportsInterrupt:  true,
		SupportsCompact:    false,
		SupportsRollback:   false,
		SupportsApproval:   true,
		SupportsFileSystem: true,
		SupportsMCP:        true,
		SupportsCommand:    true,
		SupportsModelSwitch:    true,
		SupportsSandboxConfig:  true,
		SupportsApprovalPolicy: true,
		StructuredOutput:   true,
		StreamingOutput:    true,
		SupportsPTY:        false,
	}
}

func (p *CodexProvider) Config() provider.ProviderConfig {
	p.configMu.RLock()
	if p.cachedConfig != nil {
		cfg := *p.cachedConfig
		p.configMu.RUnlock()
		return cfg
	}
	p.configMu.RUnlock()

	// Try fetching models from codex app-server
	cfg := p.fetchConfig()
	if cfg != nil {
		p.configMu.Lock()
		p.cachedConfig = cfg
		p.configMu.Unlock()
		return *cfg
	}

	// Fallback to static defaults
	return provider.ProviderConfig{
		Models: []provider.ModelInfo{
			{ID: "o3", Name: "o3", Default: true, ReasoningEfforts: []string{"low", "medium", "high"}},
			{ID: "o4-mini", Name: "o4-mini", ReasoningEfforts: []string{"low", "medium", "high"}},
		},
		ApprovalPolicies: []string{"untrusted", "on-request", "never"},
		SandboxModes:     []string{"read-only", "workspace-write", "danger-full-access"},
	}
}

func (p *CodexProvider) fetchConfig() *provider.ProviderConfig {
	binary := p.cfg.Binary
	if binary == "" {
		var err error
		binary, err = exec.LookPath("codex")
		if err != nil {
			return nil
		}
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	client, err := NewAppServerClient(ctx, binary)
	if err != nil {
		log.Error("codex", "config: failed to start appserver: %v", err)
		return nil
	}
	defer client.Close()

	if err := client.Initialize(ctx); err != nil {
		log.Error("codex", "config: initialize failed: %v", err)
		return nil
	}

	models, err := client.ListModels(ctx)
	if err != nil {
		log.Error("codex", "config: list models failed: %v", err)
		return nil
	}

	var providerModels []provider.ModelInfo
	for i, m := range models {
		var efforts []string
		for _, e := range m.SupportedReasoningEfforts {
			efforts = append(efforts, e.ReasoningEffort)
		}
		if len(efforts) == 0 {
			efforts = []string{"low", "medium", "high"}
		}
		log.Debug("codex", "config: model=%s efforts=%v", m.ID, efforts)
		providerModels = append(providerModels, provider.ModelInfo{
			ID:               m.ID,
			Name:             m.DisplayName,
			Default:          i == 0,
			ReasoningEfforts: efforts,
		})
	}

	log.Info("codex", "config: fetched %d models from app-server", len(providerModels))

	return &provider.ProviderConfig{
		Models:           providerModels,
		ApprovalPolicies: []string{"untrusted", "on-request", "never"},
		SandboxModes:     []string{"read-only", "workspace-write", "danger-full-access"},
	}
}

func (p *CodexProvider) Close() error {
	p.clientsMu.Lock()
	defer p.clientsMu.Unlock()
	for _, client := range p.clients {
		client.Close()
	}
	return nil
}
