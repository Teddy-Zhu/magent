package session

import (
	"context"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/magent/agent/internal/log"
	"github.com/magent/agent/internal/provider"
	"github.com/magent/agent/internal/ws"
)

type Manager struct {
	store      *SessionStore
	registry   *provider.Registry
	wsHub      *ws.Hub
	eventSeq   map[string]int64
	eventSeqMu sync.RWMutex
}

func NewManager(store *SessionStore, registry *provider.Registry, hub *ws.Hub) *Manager {
	return &Manager{
		store:    store,
		registry: registry,
		wsHub:    hub,
		eventSeq: make(map[string]int64),
	}
}

func (m *Manager) CreateSession(ctx context.Context, req CreateSessionRequest) (*provider.Session, error) {
	p, err := m.registry.Get(req.Provider)
	if err != nil {
		return nil, err
	}

	session, err := p.CreateSession(ctx, provider.CreateSessionRequest{
		ProjectID:      req.ProjectID,
		Workdir:        req.Workdir,
		Model:          req.Model,
		Effort:         req.Effort,
		ApprovalPolicy: req.ApprovalPolicy,
		SandboxMode:    req.SandboxMode,
		Prompt:         req.Prompt,
	})
	if err != nil {
		return nil, err
	}

	if err := m.store.Save(session); err != nil {
		return nil, err
	}

	go m.collectEvents(session.ID, p)

	m.wsHub.Broadcast(map[string]any{
		"type":       "session.created",
		"session_id": session.ID,
		"data":       session,
	})

	return session, nil
}

type CreateSessionRequest struct {
	Provider       string `json:"provider"`
	ProjectID      string `json:"project_id"`
	Workdir        string `json:"workdir"`
	Model          string `json:"model"`
	Effort         string `json:"effort"`
	ApprovalPolicy string `json:"approval_policy"`
	SandboxMode    string `json:"sandbox_mode"`
	Prompt         string `json:"prompt"`
}

func (m *Manager) collectEvents(sessionID string, p provider.Provider) {
	events := p.Subscribe(sessionID)
	defer p.Unsubscribe(sessionID)

	log.Debug("session", "collectEvents started id=%s provider=%s", sessionID, p.Name())
	for event := range events {
		m.eventSeqMu.Lock()
		m.eventSeq[sessionID]++
		seq := m.eventSeq[sessionID]
		m.eventSeqMu.Unlock()

		log.Debug("session", "event id=%s seq=%d type=%s", sessionID, seq, event.Type)
		m.store.SaveEvent(SessionEvent{
			SessionID: sessionID,
			Seq:       seq,
			Type:      event.Type,
			Payload:   event.Payload,
			CreatedAt: event.Timestamp,
		})

		m.wsHub.Broadcast(map[string]any{
			"type":       event.Type,
			"seq":        seq,
			"session_id": sessionID,
			"time":       event.Timestamp.Unix(),
			"data":       event.Payload,
		})
	}
}

func (m *Manager) GetEventsAfterSeq(sessionID string, afterSeq int64, limit int) ([]SessionEvent, error) {
	return m.store.GetEventsAfterSeq(sessionID, afterSeq, limit)
}

func (m *Manager) ListSessions(projectID string) ([]provider.Session, error) {
	return m.store.ListByProject(projectID)
}

func (m *Manager) GetSession(id string) (*provider.Session, error) {
	return m.store.Get(id)
}

func (m *Manager) StopSession(ctx context.Context, id string) error {
	session, err := m.store.Get(id)
	if err != nil {
		return err
	}

	p, err := m.registry.Get(session.ProviderID)
	if err != nil {
		return err
	}

	if err := p.StopSession(ctx, id); err != nil {
		return err
	}

	session.Status = "stopped"
	now := time.Now()
	session.ExitedAt = &now
	return m.store.Update(session)
}

func (m *Manager) SendInput(ctx context.Context, sessionID, input string) error {
	session, err := m.store.Get(sessionID)
	if err != nil {
		return err
	}

	p, err := m.registry.Get(session.ProviderID)
	if err != nil {
		return err
	}

	return p.SendInput(ctx, sessionID, input)
}

func (m *Manager) InterruptSession(ctx context.Context, sessionID string) error {
	session, err := m.store.Get(sessionID)
	if err != nil {
		return err
	}

	p, err := m.registry.Get(session.ProviderID)
	if err != nil {
		return err
	}

	return p.InterruptSession(ctx, sessionID)
}

func (m *Manager) ForkSession(ctx context.Context, id string) (*provider.Session, error) {
	session, err := m.store.Get(id)
	if err != nil {
		return nil, err
	}

	p, err := m.registry.Get(session.ProviderID)
	if err != nil {
		return nil, err
	}

	newThreadID, err := p.ForkSession(ctx, id, session.ThreadID)
	if err != nil {
		return nil, err
	}

	newSession := &provider.Session{
		ID:         uuid.New().String(),
		ProviderID: session.ProviderID,
		ThreadID:   newThreadID,
		ProjectID:  session.ProjectID,
		Title:      session.Title + " (fork)",
		Workdir:    session.Workdir,
		Status:     "running",
		RunnerType: session.RunnerType,
		Model:      session.Model,
	}

	if err := m.store.Save(newSession); err != nil {
		return nil, err
	}

	return newSession, nil
}

func (m *Manager) CompactSession(ctx context.Context, sessionID string) error {
	session, err := m.store.Get(sessionID)
	if err != nil {
		return err
	}

	p, err := m.registry.Get(session.ProviderID)
	if err != nil {
		return err
	}

	return p.CompactSession(ctx, sessionID)
}

func (m *Manager) RollbackSession(ctx context.Context, sessionID string, turns int) error {
	session, err := m.store.Get(sessionID)
	if err != nil {
		return err
	}

	p, err := m.registry.Get(session.ProviderID)
	if err != nil {
		return err
	}

	return p.RollbackSession(ctx, sessionID, turns)
}

func (m *Manager) Recover(ctx context.Context) error {
	sessions, err := m.store.GetActiveSessions()
	if err != nil {
		return err
	}

	log.Info("session", "recovering %d active sessions", len(sessions))
	for _, s := range sessions {
		p, err := m.registry.Get(s.ProviderID)
		if err != nil {
			log.Warn("session", "recover skip id=%s provider=%s not found", s.ID, s.ProviderID)
			m.store.UpdateStatus(s.ID, "lost")
			continue
		}

		if err := p.ResumeSession(ctx, s.ID, s.ThreadID); err != nil {
			log.Warn("session", "recover failed id=%s: %v", s.ID, err)
			m.store.UpdateStatus(s.ID, "lost")
			continue
		}

		log.Info("session", "recovered id=%s provider=%s", s.ID, s.ProviderID)
		s.Status = "running"
		m.store.Update(&s)
	}

	return nil
}
