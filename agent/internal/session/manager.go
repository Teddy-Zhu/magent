package session

import (
	"context"
	"fmt"
	"strings"

	"github.com/Teddy-Zhu/magent/agent/internal/log"
	"github.com/Teddy-Zhu/magent/agent/internal/provider"
	"github.com/Teddy-Zhu/magent/agent/internal/ws"
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
	sess, err := m.store.Get(sessionID)
	if err != nil {
		return nil, err
	}

	providerName := ""
	if sess != nil {
		providerName = sess.ProviderID
	}

	if p := m.activeProviderForSession(sessionID, providerName); p != nil {
		if sess != nil {
			sess.Status = string(provider.SessionStatusRunning)
			return sess, nil
		}
		return &provider.Session{
			ID:         sessionID,
			ProviderID: p.Name(),
			ThreadID:   sessionID,
			Status:     string(provider.SessionStatusRunning),
		}, nil
	}

	if sess != nil {
		if ps, ok, listErr := m.providerListedSession(ctx, sessionID, sess.ProviderID, ""); listErr != nil {
			return nil, listErr
		} else if ok {
			merged := mergeProviderSessionMetadata(ps, *sess)
			merged.Status = m.sessionListStatus(merged)
			return &merged, nil
		}
		if deleteErr := m.store.Delete(sessionID); deleteErr != nil {
			log.Warn("session", "delete stale session failed id=%s: %v", sessionID, deleteErr)
		}
	}

	return nil, nil
}

// ListSessions returns sessions for a project. Provider is source of truth.
func (m *Manager) ListSessions(ctx context.Context, projectID, providerName, workdir string, archived bool) ([]provider.Session, error) {
	// Get threads from provider (source of truth)
	var providerSessions []provider.Session
	if providerName != "" {
		p, err := m.registry.Get(providerName)
		if err != nil {
			return nil, err
		}
		if lister, ok := p.(provider.ThreadListerWithOptions); ok {
			providerSessions, err = lister.ListThreadsWithOptions(ctx, provider.ThreadListOptions{
				CWD:      workdir,
				Limit:    100,
				Archived: archived,
			})
		} else if archived {
			providerSessions = nil
		} else {
			providerSessions, err = p.ListThreads(ctx, workdir, 100)
		}
		if err != nil {
			return nil, fmt.Errorf("list provider sessions: %w", err)
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
			ps = mergeProviderSessionMetadata(ps, db)
		} else {
			ps.ProjectID = projectID
		}
		if archived {
			ps.Status = string(provider.SessionStatusStopped)
		} else {
			ps.Status = m.sessionListStatus(ps)
		}
		result = append(result, ps)
	}

	// Add only DB sessions that the provider still holds active in memory. DB
	// rows not returned by provider history and not active are stale metadata.
	if !archived {
		for _, db := range dbSessions {
			if !seen[db.ID] && m.activeProviderForSession(db.ID, db.ProviderID) != nil {
				db.Status = m.sessionListStatus(db)
				result = append(result, db)
			}
		}
	}

	return result, nil
}

func (m *Manager) ArchiveSession(ctx context.Context, sessionID string) error {
	sess, err := m.store.Get(sessionID)
	if err != nil {
		return err
	}
	providerName := ""
	if sess != nil {
		providerName = sess.ProviderID
	}
	p := m.activeProviderForSession(sessionID, providerName)
	if p == nil && providerName != "" {
		p, err = m.registry.Get(providerName)
		if err != nil {
			return err
		}
	}
	if p == nil {
		return fmt.Errorf("session %s not found", sessionID)
	}
	archiver, ok := p.(provider.ThreadArchiver)
	if !ok {
		return fmt.Errorf("%s does not support archive", p.Name())
	}
	if err := archiver.ArchiveSession(ctx, sessionID); err != nil {
		return err
	}
	if deleteErr := m.store.Delete(sessionID); deleteErr != nil {
		log.Warn("session", "delete archived session metadata failed id=%s: %v", sessionID, deleteErr)
	}
	return nil
}

func (m *Manager) UnarchiveSession(ctx context.Context, sessionID string) (*provider.Session, error) {
	p, providerName, err := m.providerForArchivedOperation(sessionID)
	if err != nil {
		return nil, err
	}
	archiver, ok := p.(provider.ThreadArchiver)
	if !ok {
		return nil, fmt.Errorf("%s does not support unarchive", p.Name())
	}
	session, err := archiver.UnarchiveSession(ctx, sessionID)
	if err != nil {
		return nil, err
	}
	if session == nil {
		session = &provider.Session{ID: sessionID, ProviderID: providerName, ThreadID: sessionID}
	}
	if session.ProviderID == "" {
		session.ProviderID = providerName
	}
	if session.ID == "" {
		session.ID = sessionID
	}
	if session.ThreadID == "" {
		session.ThreadID = session.ID
	}
	session.ArchivedAt = nil
	if err := m.store.Save(session); err != nil {
		log.Error("session", "save unarchived session failed id=%s: %v", session.ID, err)
	}
	return session, nil
}

func (m *Manager) DeleteSession(ctx context.Context, sessionID string) error {
	p, _, err := m.providerForArchivedOperation(sessionID)
	if err != nil {
		return err
	}
	deleter, ok := p.(provider.ThreadDeleter)
	if !ok {
		return fmt.Errorf("%s does not support delete", p.Name())
	}
	if err := deleter.DeleteSession(ctx, sessionID); err != nil {
		return err
	}
	if deleteErr := m.store.Delete(sessionID); deleteErr != nil {
		log.Warn("session", "delete session metadata failed id=%s: %v", sessionID, deleteErr)
	}
	return nil
}

func (m *Manager) providerForArchivedOperation(sessionID string) (provider.Provider, string, error) {
	if sess, err := m.store.Get(sessionID); err != nil {
		return nil, "", err
	} else if sess != nil && sess.ProviderID != "" {
		p, err := m.registry.Get(sess.ProviderID)
		return p, sess.ProviderID, err
	}
	if p := m.activeProviderForSession(sessionID, ""); p != nil {
		return p, p.Name(), nil
	}
	for _, name := range []string{"codex"} {
		p, err := m.registry.Get(name)
		if err == nil {
			return p, name, nil
		}
	}
	return nil, "", fmt.Errorf("session %s not found", sessionID)
}

func (m *Manager) providerListedSession(ctx context.Context, sessionID, providerName, workdir string) (provider.Session, bool, error) {
	if providerName == "" {
		return provider.Session{}, false, nil
	}
	p, err := m.registry.Get(providerName)
	if err != nil {
		return provider.Session{}, false, err
	}
	sessions, err := p.ListThreads(ctx, workdir, 100)
	if err != nil {
		return provider.Session{}, false, fmt.Errorf("list provider sessions: %w", err)
	}
	for _, session := range sessions {
		if session.ID == sessionID {
			return session, true, nil
		}
	}
	return provider.Session{}, false, nil
}

func mergeProviderSessionMetadata(ps, db provider.Session) provider.Session {
	ps.Model = firstNonEmpty(db.Model, ps.Model)
	ps.ProjectID = db.ProjectID
	ps.Purpose = db.Purpose
	ps.Workdir = firstNonEmpty(ps.Workdir, db.Workdir)
	ps.ApprovalPolicy = firstNonEmpty(ps.ApprovalPolicy, db.ApprovalPolicy)
	ps.SandboxMode = firstNonEmpty(ps.SandboxMode, db.SandboxMode)
	ps.Config = db.Config
	return ps
}

func (m *Manager) sessionListStatus(session provider.Session) string {
	if m.activeProviderForSession(session.ID, session.ProviderID) != nil {
		return string(provider.SessionStatusRunning)
	}
	return string(provider.SessionStatusStopped)
}

func (m *Manager) activeProviderForSession(sessionID, providerName string) provider.Provider {
	if providerName != "" {
		p, err := m.registry.Get(providerName)
		if err == nil {
			if p.HasSession(sessionID) {
				return p
			}
			return nil
		}
	}

	for _, p := range m.registry.ListProviders() {
		if p.HasSession(sessionID) {
			return p
		}
	}
	return nil
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
	log.Info("session", "GetItems: session=%s provider=%s thread=%s cursor=%q limit=%d", sessionID, p.Name(), threadID, cursor, limit)
	page, err := p.ReadThreadItems(ctx, threadID, cursor, limit)
	if err != nil {
		log.Error("session", "GetItems: session=%s provider=%s thread=%s error=%v", sessionID, p.Name(), threadID, err)
		return nil, err
	}
	log.Info("session", "GetItems: session=%s items=%d next=%q has_more=%t tail=%s", sessionID, len(page.Items), page.Cursor, page.HasMore, sessionItemTailSummary(page.Items, 8))
	return page, nil
}

func sessionItemTailSummary(items []provider.SessionItem, limit int) string {
	if len(items) == 0 {
		return "[]"
	}
	if limit <= 0 || limit > len(items) {
		limit = len(items)
	}
	start := len(items) - limit
	parts := make([]string, 0, limit)
	for _, item := range items[start:] {
		parts = append(parts, fmt.Sprintf("%s:%s:%s:%d", item.ItemID, item.Type, item.Status, item.Index))
	}
	return "[" + strings.Join(parts, ", ") + "]"
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
		if sess.ThreadID != "" {
			threadID = sess.ThreadID
		}
	}

	p, err := m.registry.Get(providerName)
	if err != nil {
		return err
	}
	providerSession, hasProviderSession, err := m.providerListedSession(ctx, sessionID, providerName, "")
	if err != nil {
		return err
	}
	if hasProviderSession {
		if sess != nil {
			merged := mergeProviderSessionMetadata(providerSession, *sess)
			sess = &merged
		} else {
			providerSession.ProjectID = ""
			sess = &providerSession
		}
		if sess.ProviderID == "" {
			sess.ProviderID = providerName
		}
		if sess.ThreadID == "" {
			sess.ThreadID = threadID
		}
	}

	if err := p.ResumeSession(ctx, sessionID, threadID); err != nil {
		if providerSessionMissing(err) {
			if deleteErr := m.store.Delete(sessionID); deleteErr != nil {
				log.Warn("session", "delete stale session failed id=%s: %v", sessionID, deleteErr)
			}
			return fmt.Errorf("session %s not found in provider: %w", sessionID, err)
		}
		return fmt.Errorf("resume failed: %w", err)
	}
	if updater, ok := p.(provider.SessionMetadataUpdater); ok && sess != nil {
		updater.UpdateSessionMetadata(*sess)
	}

	// Save to DB if not already there
	if sess == nil {
		sess = &provider.Session{
			ID:         sessionID,
			ProviderID: providerName,
			ThreadID:   threadID,
			ProjectID:  "",
		}
	}
	if err := m.store.Save(sess); err != nil {
		log.Warn("session", "ResumeSession: store.Save(%s) error: %v", sessionID, err)
	}

	// Start forwarding live events
	go m.forwardEvents(sessionID, p)

	log.Info("session", "ResumeSession: id=%s provider=%s", sessionID, providerName)
	return nil
}

func providerSessionMissing(err error) bool {
	if err == nil {
		return false
	}
	msg := strings.ToLower(err.Error())
	return strings.Contains(msg, "not found") ||
		strings.Contains(msg, "no rollout found")
}

// SendInput sends input to a session. Auto-resumes if needed.
func (m *Manager) SendInput(ctx context.Context, sessionID string, input provider.SendInputRequest) error {
	// Try active provider first
	for _, p := range m.registry.ListProviders() {
		if p.HasSession(sessionID) {
			if err := m.updateProviderSessionMetadata(ctx, p, sessionID); err != nil {
				return err
			}
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

func (m *Manager) updateProviderSessionMetadata(ctx context.Context, p provider.Provider, sessionID string) error {
	updater, ok := p.(provider.SessionMetadataUpdater)
	if !ok {
		return nil
	}
	sess, _ := m.store.Get(sessionID)
	if sess == nil {
		return nil
	}
	providerSession, ok, err := m.providerListedSession(ctx, sessionID, sess.ProviderID, "")
	if err != nil {
		return err
	}
	if ok {
		merged := mergeProviderSessionMetadata(providerSession, *sess)
		sess = &merged
		if saveErr := m.store.Save(sess); saveErr != nil {
			log.Warn("session", "update provider metadata: store.Save(%s) error: %v", sessionID, saveErr)
		}
	}
	updater.UpdateSessionMetadata(*sess)
	return nil
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
	if updater, ok := p.(provider.SessionMetadataUpdater); ok {
		updater.UpdateSessionMetadata(*newSession)
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
