package session

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/Teddy-Zhu/magent/agent/internal/log"
	"github.com/Teddy-Zhu/magent/agent/internal/provider"
	"github.com/Teddy-Zhu/magent/agent/internal/ws"
)

const (
	defaultSessionItemPageLimit = 80
	maxSessionItemPageLimit     = 200
)

type Manager struct {
	store          *SessionStore
	registry       *provider.Registry
	wsHub          *ws.Hub
	itemProjection *itemProjectionStore
}

func NewManager(store *SessionStore, registry *provider.Registry, hub *ws.Hub) *Manager {
	manager := &Manager{
		store:          store,
		registry:       registry,
		wsHub:          hub,
		itemProjection: newItemProjectionStore(store),
	}
	return manager
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

// CreateSession creates a session via provider. Provider is the source of truth.
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
		m.applyProviderEventProjection(sessionID, event)
		index++
	}
	log.Debug("session", "forwardEvents ended id=%s", sessionID)
}

// GetSession returns session info. Provider is source of truth for status.
func (m *Manager) GetSession(ctx context.Context, sessionID string) (*provider.Session, error) {
	if p := m.activeProviderForSession(sessionID, ""); p != nil {
		if ps, ok, listErr := m.providerListedSession(ctx, sessionID, p.Name(), ""); listErr != nil {
			return nil, listErr
		} else if ok {
			ps.Status = string(provider.SessionStatusRunning)
			return &ps, nil
		}
		return &provider.Session{
			ID:         sessionID,
			ProviderID: p.Name(),
			ThreadID:   sessionID,
			Status:     string(provider.SessionStatusRunning),
		}, nil
	}

	for _, p := range m.registry.ListProviders() {
		ps, ok, listErr := m.providerListedSession(ctx, sessionID, p.Name(), "")
		if listErr != nil {
			return nil, listErr
		}
		if ok {
			ps.Status = m.sessionListStatus(ps)
			return &ps, nil
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

	var result []provider.Session

	for _, ps := range providerSessions {
		ps.ProjectID = projectID
		if archived {
			ps.Status = string(provider.SessionStatusStopped)
		} else {
			ps.Status = m.sessionListStatus(ps)
		}
		result = append(result, ps)
	}

	return result, nil
}

func (m *Manager) ArchiveSession(ctx context.Context, sessionID string) error {
	p, _, err := m.providerForArchivedOperation(sessionID)
	if err != nil {
		return err
	}
	archiver, ok := p.(provider.ThreadArchiver)
	if !ok {
		return fmt.Errorf("%s does not support archive", p.Name())
	}
	if err := archiver.ArchiveSession(ctx, sessionID); err != nil {
		return err
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
	return nil
}

func (m *Manager) providerForArchivedOperation(sessionID string) (provider.Provider, string, error) {
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

// GetItems reads a provider-backed window of items for a session. The cursor is
// provider-owned; an empty cursor returns the latest window, and the returned
// cursor can be used to request older items.
func (m *Manager) GetItems(ctx context.Context, sessionID, cursor string, limit int) (*provider.ItemPage, error) {
	if limit <= 0 {
		limit = defaultSessionItemPageLimit
	}
	if limit > maxSessionItemPageLimit {
		limit = maxSessionItemPageLimit
	}
	p, threadID, err := m.getProviderAndThreadForSession(sessionID)
	if err != nil {
		return nil, err
	}
	return p.ReadThreadItems(ctx, threadID, cursor, limit)
}

func (m *Manager) GetItemChanges(ctx context.Context, sessionID string, afterRevision int64, limit int) (*ItemChangesPage, error) {
	page, err := m.itemProjection.Changes(ctx, sessionID, afterRevision, limit)
	if err != nil {
		return nil, err
	}
	log.Debug("session", "GetItemChanges: session=%s after=%d to=%d changes=%d reset=%t", sessionID, afterRevision, page.ToRevision, len(page.Changes), page.ResetRequired)
	return page, nil
}

func (m *Manager) applyProviderEventProjection(sessionID string, event provider.ProviderEvent) {
	if !isItemProjectionProviderEvent(event.Type) {
		return
	}
	if isRealtimeOnlyProjectionEvent(event.Type) {
		return
	}
	item, ok := m.sessionItemFromProviderEvent(context.Background(), sessionID, event)
	if !ok {
		return
	}
	changes, err := m.itemProjection.Upsert(context.Background(), sessionID, item)
	if err != nil {
		log.Warn("session", "upsert runtime item failed session=%s item=%s type=%s: %v", sessionID, item.ItemID, event.Type, err)
		return
	}
	m.broadcastItemChanges(sessionID, changes)
}

func (m *Manager) broadcastItemChanges(sessionID string, changes *ItemChangesPage) {
	if changes == nil || len(changes.Changes) == 0 {
		return
	}
	m.wsHub.Broadcast(map[string]any{
		"type":          "session.items.changed",
		"session_id":    sessionID,
		"from_revision": changes.FromRevision,
		"to_revision":   changes.ToRevision,
		"changes":       changes.Changes,
	})
}

func isItemProjectionProviderEvent(eventType string) bool {
	switch eventType {
	case string(provider.EventUserMessage),
		string(provider.EventMessage),
		string(provider.EventMessageDelta),
		string(provider.EventOutput),
		string(provider.EventPlan),
		string(provider.EventPlanDelta),
		string(provider.EventPlanUpdated),
		string(provider.EventReasoning),
		string(provider.EventReasoningSummaryDelta),
		string(provider.EventReasoningTextDelta),
		string(provider.EventReasoningSummaryPart),
		string(provider.EventDiffUpdated),
		string(provider.EventCommandCompleted),
		string(provider.EventCommandOutputDelta),
		string(provider.EventFileWrite),
		string(provider.EventFileRead),
		string(provider.EventFileChangeOutputDelta),
		string(provider.EventMCPToolCompleted),
		string(provider.EventItemStarted),
		string(provider.EventItemCompleted),
		string(provider.EventTurnStarted),
		string(provider.EventTurnCompleted),
		string(provider.EventTurnFailed):
		return true
	default:
		return false
	}
}

func isRealtimeOnlyProjectionEvent(eventType string) bool {
	switch eventType {
	case string(provider.EventMessageDelta),
		string(provider.EventPlanDelta),
		string(provider.EventReasoningSummaryDelta),
		string(provider.EventReasoningTextDelta),
		string(provider.EventCommandOutputDelta),
		string(provider.EventFileChangeOutputDelta),
		string(provider.EventItemStarted),
		string(provider.EventTurnStarted),
		string(provider.EventTurnCompleted):
		return true
	default:
		return false
	}
}

func (m *Manager) sessionItemFromProviderEvent(ctx context.Context, sessionID string, event provider.ProviderEvent) (provider.SessionItem, bool) {
	data, ok := event.Payload.(map[string]any)
	if !ok {
		return provider.SessionItem{}, false
	}
	itemID := firstPayloadString(data, "id", "item_id", "itemId")
	if itemID == "" {
		itemID = event.ItemID
	}
	turnID := firstPayloadString(data, "turnId", "turn_id")
	if turnID == "" {
		turnID = event.TurnID
	}
	itemType := provider.NormalizeItemType(firstPayloadString(data, "type", "item_type", "itemType"))
	if itemType == "" {
		itemType = itemTypeFromProviderEvent(event.Type)
	}
	if itemType == "" {
		return provider.SessionItem{}, false
	}
	if itemID == "" {
		itemID = syntheticRuntimeItemID(event.Type, turnID)
	}
	if itemID == "" {
		return provider.SessionItem{}, false
	}
	index, ok := intFromPayload(data, "index")
	if !ok {
		if existingOrderKey, exists, err := m.itemProjection.ItemOrderKey(ctx, sessionID, itemID); err != nil {
			log.Warn("session", "read runtime item order failed session=%s item=%s: %v", sessionID, itemID, err)
			return provider.SessionItem{}, false
		} else if exists {
			index = existingOrderKey
			ok = true
		}
	}
	if !ok {
		nextIndex, err := m.itemProjection.NextOrderKey(ctx, sessionID)
		if err != nil {
			log.Warn("session", "next runtime item order failed session=%s item=%s: %v", sessionID, itemID, err)
			return provider.SessionItem{}, false
		}
		index = nextIndex
	}
	createdAt := event.Timestamp
	if createdAt.IsZero() {
		createdAt = time.Now()
	}
	if value := firstPayloadTime(data, "created_at", "createdAt", "timestamp"); !value.IsZero() {
		createdAt = value
	}
	updatedAt := createdAt
	if value := firstPayloadTime(data, "updated_at", "updatedAt"); !value.IsZero() {
		updatedAt = value
	}
	content := clonePayload(data)
	content["type"] = itemType
	content["id"] = itemID
	if _, exists := content["status"]; !exists {
		content["status"] = provider.SessionStatusCompleted
	}
	normalizeRuntimeContentAliases(content)
	status := firstPayloadString(content, "status")
	if status == "" {
		status = string(provider.SessionStatusCompleted)
	}
	return provider.SessionItem{
		Cursor:    firstNonEmpty(event.Cursor, firstPayloadString(data, "cursor", "provider_cursor")),
		ItemID:    itemID,
		TurnID:    turnID,
		Index:     index,
		Type:      itemType,
		Status:    status,
		Role:      itemRole(itemType),
		Summary:   itemSummary(itemType, content),
		Content:   content,
		CreatedAt: createdAt,
		UpdatedAt: updatedAt,
	}, true
}

func syntheticRuntimeItemID(eventType, turnID string) string {
	if turnID == "" {
		return ""
	}
	switch eventType {
	case string(provider.EventPlan), string(provider.EventPlanUpdated):
		return turnID + ":plan"
	case string(provider.EventDiffUpdated):
		return turnID + ":diff"
	case string(provider.EventReasoning), string(provider.EventReasoningSummaryPart):
		return turnID + ":reasoning"
	default:
		return ""
	}
}

func itemTypeFromProviderEvent(eventType string) string {
	switch eventType {
	case string(provider.EventUserMessage):
		return string(provider.ItemTypeUserMessage)
	case string(provider.EventMessage), string(provider.EventOutput):
		return string(provider.ItemTypeAgentMessage)
	case string(provider.EventPlan), string(provider.EventPlanUpdated):
		return string(provider.ItemTypePlan)
	case string(provider.EventReasoning), string(provider.EventReasoningSummaryPart):
		return string(provider.ItemTypeReasoning)
	case string(provider.EventDiffUpdated):
		return string(provider.ItemTypeDiff)
	case string(provider.EventCommandCompleted):
		return string(provider.ItemTypeCommandExecution)
	case string(provider.EventFileWrite):
		return string(provider.ItemTypeFileChange)
	case string(provider.EventFileRead):
		return string(provider.ItemTypeFileRead)
	case string(provider.EventMCPToolCompleted):
		return string(provider.ItemTypeMCPToolCall)
	default:
		return ""
	}
}

func itemRole(itemType string) string {
	switch itemType {
	case string(provider.ItemTypeUserMessage):
		return "user"
	case string(provider.ItemTypeAgentMessage):
		return "assistant"
	default:
		return ""
	}
}

func itemSummary(itemType string, content map[string]any) string {
	if itemType == string(provider.ItemTypeReasoning) {
		if text := firstPayloadString(content, "text", "summary", "content", "delta"); text != "" {
			return truncateSummary(text)
		}
		return ""
	}
	if text := firstPayloadString(content, "text", "content", "delta"); text != "" {
		return truncateSummary(text)
	}
	if output := firstPayloadString(content, "output", "aggregatedOutput", "stdout", "stderr", "result", "error"); output != "" {
		return truncateSummary(output)
	}
	if command := payloadValueString(content["command"]); command != "" {
		return truncateSummary(command)
	}
	if path := firstPayloadString(content, "path"); path != "" {
		return path
	}
	if changes, ok := content["changes"].([]any); ok && len(changes) > 0 {
		if first, ok := changes[0].(map[string]any); ok {
			if path := firstPayloadString(first, "path"); path != "" {
				return path
			}
		}
	}
	return itemType
}

func truncateSummary(value string) string {
	runes := []rune(strings.TrimSpace(value))
	if len(runes) <= 160 {
		return string(runes)
	}
	return string(runes[:160])
}

func normalizeRuntimeContentAliases(content map[string]any) {
	if content["output"] == nil {
		for _, key := range []string{"aggregatedOutput", "stdout", "stderr"} {
			if content[key] != nil {
				content["output"] = content[key]
				break
			}
		}
	}
	if content["exit_code"] == nil && content["exitCode"] != nil {
		content["exit_code"] = content["exitCode"]
	}
}

func clonePayload(data map[string]any) map[string]any {
	clone := make(map[string]any, len(data)+2)
	for key, value := range data {
		clone[key] = value
	}
	return clone
}

func firstPayloadString(data map[string]any, keys ...string) string {
	for _, key := range keys {
		if value := payloadValueString(data[key]); value != "" {
			return value
		}
	}
	return ""
}

func payloadValueString(value any) string {
	switch v := value.(type) {
	case nil:
		return ""
	case string:
		return v
	case fmt.Stringer:
		return v.String()
	default:
		return fmt.Sprint(v)
	}
}

func intFromPayload(data map[string]any, key string) (int, bool) {
	switch value := data[key].(type) {
	case int:
		return value, true
	case int64:
		return int(value), true
	case float64:
		return int(value), true
	case json.Number:
		parsed, err := value.Int64()
		return int(parsed), err == nil
	case string:
		var parsed int
		if _, err := fmt.Sscanf(value, "%d", &parsed); err == nil {
			return parsed, true
		}
	}
	return 0, false
}

func firstPayloadTime(data map[string]any, keys ...string) time.Time {
	for _, key := range keys {
		if value := payloadTime(data[key]); !value.IsZero() {
			return value
		}
	}
	return time.Time{}
}

func payloadTime(value any) time.Time {
	switch v := value.(type) {
	case time.Time:
		return v
	case int64:
		return time.Unix(v, 0)
	case int:
		return time.Unix(int64(v), 0)
	case float64:
		return time.Unix(int64(v), 0)
	case json.Number:
		parsed, err := v.Int64()
		if err == nil {
			return time.Unix(parsed, 0)
		}
	case string:
		if parsed, err := time.Parse(time.RFC3339Nano, v); err == nil {
			return parsed
		}
	}
	return time.Time{}
}

// ResumeSession activates a session in its provider.
func (m *Manager) ResumeSession(ctx context.Context, sessionID string) error {
	for _, p := range m.registry.ListProviders() {
		if p.HasSession(sessionID) {
			return nil
		}
	}

	providerName, threadID := "codex", sessionID
	p, err := m.registry.Get(providerName)
	if err != nil {
		return err
	}
	providerSession, hasProviderSession, err := m.providerListedSession(ctx, sessionID, providerName, "")
	if err != nil {
		return err
	}
	var sessionMeta *provider.Session
	if hasProviderSession {
		if providerSession.ProviderID == "" {
			providerSession.ProviderID = providerName
		}
		if providerSession.ThreadID != "" {
			threadID = providerSession.ThreadID
		}
		sessionMeta = &providerSession
	}

	if err := p.ResumeSession(ctx, sessionID, threadID); err != nil {
		if providerSessionMissing(err) {
			return fmt.Errorf("session %s not found in provider: %w", sessionID, err)
		}
		return fmt.Errorf("resume failed: %w", err)
	}
	if sessionMeta == nil {
		sessionMeta = &provider.Session{
			ID:         sessionID,
			ProviderID: providerName,
			ThreadID:   threadID,
		}
	}
	if updater, ok := p.(provider.SessionMetadataUpdater); ok {
		updater.UpdateSessionMetadata(*sessionMeta)
	}

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
	for _, p := range m.registry.ListProviders() {
		if p.HasSession(sessionID) {
			return p.SendInput(ctx, sessionID, input)
		}
	}

	if err := m.ResumeSession(ctx, sessionID); err != nil {
		return fmt.Errorf("session %s is not active and could not be resumed: %w", sessionID, err)
	}

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
	p, threadID, err := m.getProviderAndThreadForSession(sessionID)
	if err != nil {
		return nil, err
	}

	newThreadID, err := p.ForkSession(ctx, sessionID, threadID)
	if err != nil {
		return nil, err
	}

	newSession := &provider.Session{
		ID:         newThreadID,
		ProviderID: p.Name(),
		ThreadID:   newThreadID,
		Status:     string(provider.SessionStatusRunning),
		RunnerType: "app-server",
	}
	if updater, ok := p.(provider.SessionMetadataUpdater); ok {
		updater.UpdateSessionMetadata(*newSession)
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
			return p, sessionID, nil
		}
	}

	p, err := m.registry.Get("codex")
	if err != nil {
		return nil, "", fmt.Errorf("session %s not found", sessionID)
	}
	return p, sessionID, nil
}

// getProviderForSession finds the provider for a session by checking active
// sessions first, then falling back to the provider-backed thread id.
func (m *Manager) getProviderForSession(sessionID string) (provider.Provider, error) {
	for _, p := range m.registry.ListProviders() {
		if p.HasSession(sessionID) {
			return p, nil
		}
	}

	p, err := m.registry.Get("codex")
	if err != nil {
		return nil, fmt.Errorf("session %s not found", sessionID)
	}
	return p, nil
}
