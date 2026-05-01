package session

import (
	"context"
	"fmt"

	"github.com/magent/agent/internal/log"
	"github.com/magent/agent/internal/provider"
	"github.com/magent/agent/internal/ws"
)

type Manager struct {
	store    *SessionStore
	registry *provider.Registry
	wsHub    *ws.Hub
}

func NewManager(store *SessionStore, registry *provider.Registry, hub *ws.Hub) *Manager {
	return &Manager{
		store:    store,
		registry: registry,
		wsHub:    hub,
	}
}

type CreateSessionRequest struct {
	ProviderID     string `json:"provider_id"`
	Provider       string `json:"provider,omitempty"`
	ProjectID      string `json:"project_id"`
	Purpose        string `json:"purpose,omitempty"`
	Workdir        string `json:"workdir"`
	Model          string `json:"model"`
	Effort         string `json:"effort"`
	ApprovalPolicy string `json:"approval_policy"`
	SandboxMode    string `json:"sandbox_mode"`
	Prompt         string `json:"prompt"`
}

func (r CreateSessionRequest) Validate() error {
	if r.ProviderName() == "" {
		return fmt.Errorf("provider_id is required")
	}
	if r.ProjectID == "" {
		return fmt.Errorf("project_id is required")
	}
	return nil
}

func (r CreateSessionRequest) ProviderName() string {
	if r.ProviderID != "" {
		return r.ProviderID
	}
	return r.Provider
}

// CreateSession creates a session via provider and saves minimal metadata to DB.
func (m *Manager) CreateSession(ctx context.Context, req CreateSessionRequest) (*provider.Session, error) {
	if err := req.Validate(); err != nil {
		return nil, err
	}

	providerName := req.ProviderName()
	p, err := m.registry.Get(providerName)
	if err != nil {
		return nil, err
	}

	providerReq := provider.CreateSessionRequest{
		ProjectID:      req.ProjectID,
		Purpose:        req.Purpose,
		Workdir:        req.Workdir,
		Model:          req.Model,
		Effort:         req.Effort,
		ApprovalPolicy: req.ApprovalPolicy,
		SandboxMode:    req.SandboxMode,
		Prompt:         req.Prompt,
	}
	providerReq.ApplyDefaults(p.Config())
	if err := providerReq.Validate(); err != nil {
		return nil, err
	}

	session, err := p.CreateSession(ctx, providerReq)
	if err != nil {
		return nil, err
	}

	// Save minimal metadata to DB (project_id mapping)
	if err := m.store.Save(session); err != nil {
		log.Error("session", "CreateSession: store.Save(%s) error: %v", session.ID, err)
	}
	log.Info("session", "CreateSession: id=%s provider=%s thread=%s", session.ID, session.ProviderID, session.ThreadID)

	// Start live event forwarding to WebSocket
	go m.forwardEvents(session.ID, p)

	m.wsHub.Broadcast(map[string]any{
		"type":       "session.created",
		"session_id": session.ID,
		"data":       session,
	})

	return session, nil
}

// forwardEvents subscribes to provider events and broadcasts to WebSocket.
// Does NOT save to DB — provider is source of truth.
func (m *Manager) forwardEvents(sessionID string, p provider.Provider) {
	events := p.Subscribe(sessionID)
	defer p.Unsubscribe(sessionID)

	log.Debug("session", "forwardEvents started id=%s", sessionID)
	index := 0
	for event := range events {
		m.wsHub.Broadcast(map[string]any{
			"type":       "session.event",
			"session_id": sessionID,
			"cursor":     event.Cursor,
			"event_type": event.Type,
			"item_id":    event.ItemID,
			"turn_id":    event.TurnID,
			"index":      index,
			"created_at": event.Timestamp.Unix(),
			"data":       event.Payload,
		})
		index++
	}
	log.Debug("session", "forwardEvents ended id=%s", sessionID)
}

// GetSession returns session info. Provider is source of truth for status.
func (m *Manager) GetSession(ctx context.Context, sessionID string) (*provider.Session, error) {
	// Check if provider has it active
	for _, p := range m.registry.ListProviders() {
		if p.HasSession(sessionID) {
			// Active in provider — get metadata from DB if available
			sess, _ := m.store.Get(sessionID)
			if sess != nil {
				sess.Status = string(provider.SessionStatusRunning)
				return sess, nil
			}
			// Not in DB but active — return minimal info
			return &provider.Session{
				ID:         sessionID,
				ProviderID: p.Name(),
				ThreadID:   sessionID,
				Status:     string(provider.SessionStatusRunning),
			}, nil
		}
	}

	// Not active in any provider — check DB for metadata
	sess, err := m.store.Get(sessionID)
	if err != nil {
		return nil, err
	}
	if sess != nil {
		sess.Status = string(provider.SessionStatusStopped)
		return sess, nil
	}

	return nil, nil
}

// ListSessions returns sessions for a project. Provider is source of truth.
func (m *Manager) ListSessions(ctx context.Context, projectID, providerName, workdir string) ([]provider.Session, error) {
	// Get threads from provider (source of truth)
	var providerSessions []provider.Session
	if providerName != "" {
		p, err := m.registry.Get(providerName)
		if err == nil {
			providerSessions, err = p.ListThreads(ctx, workdir, 100)
			if err != nil {
				log.Warn("session", "ListSessions: provider query failed: %v", err)
			}
		}
	}

	// Get DB metadata for project_id association
	dbSessions, _ := m.store.ListByProject(projectID)
	dbMap := make(map[string]provider.Session)
	for _, s := range dbSessions {
		dbMap[s.ID] = s
	}

	// Merge: provider threads + DB metadata
	var result []provider.Session
	seen := make(map[string]bool)

	for _, ps := range providerSessions {
		seen[ps.ID] = true
		if db, ok := dbMap[ps.ID]; ok {
			// Provider thread has DB metadata — merge model etc.
			ps.Model = firstNonEmpty(db.Model, ps.Model)
			ps.ProjectID = db.ProjectID
			ps.Purpose = db.Purpose
			ps.Workdir = firstNonEmpty(ps.Workdir, db.Workdir)
			ps.ApprovalPolicy = firstNonEmpty(ps.ApprovalPolicy, db.ApprovalPolicy)
			ps.SandboxMode = firstNonEmpty(ps.SandboxMode, db.SandboxMode)
			ps.Config = db.Config
		} else {
			ps.ProjectID = projectID
		}
		result = append(result, ps)
	}

	// Add DB sessions not in provider (stopped, not loaded)
	for _, db := range dbSessions {
		if !seen[db.ID] {
			db.Status = string(provider.SessionStatusStopped)
			result = append(result, db)
		}
	}

	return result, nil
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if value != "" {
			return value
		}
	}
	return ""
}

// GetEvents reads thread events from provider-backed history. Agent does not
// persist the content history; cursor is provider/adapter-owned.
func (m *Manager) GetEvents(ctx context.Context, sessionID, cursor string, limit int) (*provider.EventPage, error) {
	p, threadID, err := m.getProviderAndThreadForSession(sessionID)
	if err != nil {
		return nil, err
	}
	return p.ReadThreadEvents(ctx, threadID, cursor, limit)
}

// GetItems reads the provider-backed item projection for a session.
func (m *Manager) GetItems(ctx context.Context, sessionID, cursor string, limit int) (*provider.ItemPage, error) {
	p, threadID, err := m.getProviderAndThreadForSession(sessionID)
	if err != nil {
		return nil, err
	}
	return p.ReadThreadItems(ctx, threadID, cursor, limit)
}

// ResumeSession activates a session in its provider.
func (m *Manager) ResumeSession(ctx context.Context, sessionID string) error {
	// Already active?
	for _, p := range m.registry.ListProviders() {
		if p.HasSession(sessionID) {
			return nil
		}
	}

	// Look up metadata
	sess, _ := m.store.Get(sessionID)
	providerName, threadID := "codex", sessionID
	if sess != nil {
		providerName = sess.ProviderID
		threadID = sess.ThreadID
	}

	p, err := m.registry.Get(providerName)
	if err != nil {
		return err
	}

	if err := p.ResumeSession(ctx, sessionID, threadID); err != nil {
		return fmt.Errorf("resume failed: %w", err)
	}

	// Save to DB if not already there
	if sess == nil {
		m.store.Save(&provider.Session{
			ID:         sessionID,
			ProviderID: providerName,
			ThreadID:   threadID,
			ProjectID:  "",
		})
	}

	// Start forwarding live events
	go m.forwardEvents(sessionID, p)

	log.Info("session", "ResumeSession: id=%s provider=%s", sessionID, providerName)
	return nil
}

// SendInput sends input to a session. Auto-resumes if needed.
func (m *Manager) SendInput(ctx context.Context, sessionID string, input provider.SendInputRequest) error {
	// Try active provider first
	for _, p := range m.registry.ListProviders() {
		if p.HasSession(sessionID) {
			return p.SendInput(ctx, sessionID, input)
		}
	}

	// Not active — try to resume
	if err := m.ResumeSession(ctx, sessionID); err != nil {
		return fmt.Errorf("session %s is not active and could not be resumed: %w", sessionID, err)
	}

	// Retry after resume
	for _, p := range m.registry.ListProviders() {
		if p.HasSession(sessionID) {
			return p.SendInput(ctx, sessionID, input)
		}
	}

	return fmt.Errorf("session %s not found after resume", sessionID)
}

// InterruptSession interrupts a running session.
func (m *Manager) InterruptSession(ctx context.Context, sessionID string) error {
	for _, p := range m.registry.ListProviders() {
		if p.HasSession(sessionID) {
			return p.InterruptSession(ctx, sessionID)
		}
	}
	return fmt.Errorf("session %s not active", sessionID)
}

// StopSession stops a session.
func (m *Manager) StopSession(ctx context.Context, sessionID string) error {
	for _, p := range m.registry.ListProviders() {
		if p.HasSession(sessionID) {
			if err := p.StopSession(ctx, sessionID); err != nil {
				return err
			}
			m.markSessionStopped(sessionID)
			return nil
		}
	}
	// Not in provider — nothing to stop
	m.markSessionStopped(sessionID)
	return nil
}

func (m *Manager) markSessionStopped(sessionID string) {
	sess, err := m.store.Get(sessionID)
	if err == nil && sess != nil {
		sess.Status = string(provider.SessionStatusStopped)
		if updateErr := m.store.Update(sess); updateErr != nil {
			log.Warn("session", "mark stopped failed id=%s: %v", sessionID, updateErr)
		}
	}
	m.wsHub.Broadcast(map[string]any{
		"type":       "session.status_changed",
		"session_id": sessionID,
		"data": map[string]any{
			"id":     sessionID,
			"status": string(provider.SessionStatusStopped),
		},
	})
}

// ForkSession forks a session.
func (m *Manager) ForkSession(ctx context.Context, sessionID string) (*provider.Session, error) {
	sess, err := m.store.Get(sessionID)
	if err != nil {
		return nil, err
	}
	if sess == nil {
		return nil, fmt.Errorf("session %s not found", sessionID)
	}

	p, err := m.registry.Get(sess.ProviderID)
	if err != nil {
		return nil, err
	}

	newThreadID, err := p.ForkSession(ctx, sessionID, sess.ThreadID)
	if err != nil {
		return nil, err
	}

	newSession := &provider.Session{
		ID:             newThreadID,
		ProviderID:     sess.ProviderID,
		ThreadID:       newThreadID,
		ProjectID:      sess.ProjectID,
		Purpose:        sess.Purpose,
		Workdir:        sess.Workdir,
		Status:         string(provider.SessionStatusRunning),
		RunnerType:     sess.RunnerType,
		Model:          sess.Model,
		ApprovalPolicy: sess.ApprovalPolicy,
		SandboxMode:    sess.SandboxMode,
		Config:         sess.Config,
	}
	if newSession.RunnerType == "" {
		newSession.RunnerType = "app-server"
	}

	if err := m.store.Save(newSession); err != nil {
		return nil, err
	}

	go m.forwardEvents(newSession.ID, p)

	m.wsHub.Broadcast(map[string]any{
		"type":       "session.created",
		"session_id": newSession.ID,
		"data":       newSession,
	})

	return newSession, nil
}

// CompactSession compacts a session.
func (m *Manager) CompactSession(ctx context.Context, sessionID string) error {
	p, err := m.getProviderForSession(sessionID)
	if err != nil {
		return err
	}
	return p.CompactSession(ctx, sessionID)
}

// RollbackSession rolls back a session.
func (m *Manager) RollbackSession(ctx context.Context, sessionID string, turns int) error {
	p, err := m.getProviderForSession(sessionID)
	if err != nil {
		return err
	}
	return p.RollbackSession(ctx, sessionID, turns)
}

func (m *Manager) ResolveApproval(ctx context.Context, sessionID, approvalID string, decision provider.ApprovalDecision) error {
	p, err := m.getProviderForSession(sessionID)
	if err != nil {
		return err
	}
	return p.ResolveApproval(ctx, sessionID, approvalID, decision)
}

func (m *Manager) getProviderAndThreadForSession(sessionID string) (provider.Provider, string, error) {
	for _, p := range m.registry.ListProviders() {
		if p.HasSession(sessionID) {
			threadID := sessionID
			if sess, _ := m.store.Get(sessionID); sess != nil && sess.ThreadID != "" {
				threadID = sess.ThreadID
			}
			return p, threadID, nil
		}
	}

	sess, _ := m.store.Get(sessionID)
	if sess == nil {
		p, err := m.registry.Get("codex")
		if err != nil {
			return nil, "", fmt.Errorf("session %s not found", sessionID)
		}
		return p, sessionID, nil
	}
	p, err := m.registry.Get(sess.ProviderID)
	if err != nil {
		return nil, "", err
	}
	threadID := sess.ThreadID
	if threadID == "" {
		threadID = sessionID
	}
	return p, threadID, nil
}

// getProviderForSession finds the provider for a session by checking active sessions and DB.
func (m *Manager) getProviderForSession(sessionID string) (provider.Provider, error) {
	for _, p := range m.registry.ListProviders() {
		if p.HasSession(sessionID) {
			return p, nil
		}
	}

	sess, _ := m.store.Get(sessionID)
	if sess == nil {
		return nil, fmt.Errorf("session %s not found", sessionID)
	}

	p, err := m.registry.Get(sess.ProviderID)
	if err != nil {
		return nil, err
	}
	return p, nil
}
