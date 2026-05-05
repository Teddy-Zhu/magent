package session

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/Teddy-Zhu/magent/agent/internal/log"
	"github.com/Teddy-Zhu/magent/agent/internal/provider"
	"github.com/Teddy-Zhu/magent/agent/internal/ws"
)

const (
	itemReconcileDebounce = 500 * time.Millisecond
)

type Manager struct {
	store          *SessionStore
	registry       *provider.Registry
	wsHub          *ws.Hub
	itemProjection *itemProjectionStore
	itemSyncMu     sync.Mutex
	itemSyncTimers map[string]*time.Timer
}

func NewManager(store *SessionStore, registry *provider.Registry, hub *ws.Hub) *Manager {
	manager := &Manager{
		store:          store,
		registry:       registry,
		wsHub:          hub,
		itemProjection: newItemProjectionStore(store),
		itemSyncTimers: make(map[string]*time.Timer),
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
	m.scheduleItemReconcile(session.ID)

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
	ps.Effort = firstNonEmpty(db.Effort, ps.Effort)
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
	snapshot, err := m.GetItemSnapshot(ctx, sessionID)
	if err != nil {
		return nil, err
	}
	return &provider.ItemPage{
		SessionID: sessionID,
		Cursor:    fmt.Sprintf("%d", snapshot.Revision),
		HasMore:   false,
		Items:     snapshot.Items,
	}, nil
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

func (m *Manager) GetItemSnapshot(ctx context.Context, sessionID string) (*ItemSnapshot, error) {
	if _, err := m.ReconcileSessionItems(ctx, sessionID); err != nil {
		return nil, err
	}
	snapshot, err := m.itemProjection.Snapshot(ctx, sessionID)
	if err != nil {
		return nil, err
	}
	log.Debug("session", "GetItemSnapshot: session=%s revision=%d items=%d tail=%s", sessionID, snapshot.Revision, len(snapshot.Items), sessionItemTailSummary(snapshot.Items, 8))
	return snapshot, nil
}

func (m *Manager) GetItemChanges(ctx context.Context, sessionID string, afterRevision int64, limit int, reconcile bool) (*ItemChangesPage, error) {
	if reconcile {
		if _, err := m.ReconcileSessionItems(ctx, sessionID); err != nil {
			return nil, err
		}
	}
	page, err := m.itemProjection.Changes(ctx, sessionID, afterRevision, limit)
	if err != nil {
		return nil, err
	}
	log.Debug("session", "GetItemChanges: session=%s after=%d to=%d changes=%d reset=%t reconcile=%t", sessionID, afterRevision, page.ToRevision, len(page.Changes), page.ResetRequired, reconcile)
	return page, nil
}

func (m *Manager) ReconcileSessionItems(ctx context.Context, sessionID string) (*ItemChangesPage, error) {
	p, threadID, err := m.getProviderAndThreadForSession(sessionID)
	if err != nil {
		return nil, err
	}
	var page *provider.ItemPage
	if reader, ok := p.(provider.ThreadItemSnapshotReader); ok {
		page, err = reader.ReadThreadItemsSnapshot(ctx, threadID, 500)
	} else {
		page, err = p.ReadThreadItems(ctx, threadID, "", 500)
	}
	if err != nil {
		log.Error("session", "ReconcileSessionItems: session=%s provider=%s thread=%s error=%v", sessionID, p.Name(), threadID, err)
		return nil, err
	}
	changes, err := m.itemProjection.Reconcile(ctx, sessionID, page.Items)
	if err != nil {
		return nil, err
	}
	if len(changes.Changes) > 0 {
		log.Info("session", "ReconcileSessionItems: session=%s provider=%s items=%d changes=%d revision=%d tail=%s", sessionID, p.Name(), len(page.Items), len(changes.Changes), changes.ToRevision, sessionItemTailSummary(page.Items, 8))
	}
	return changes, nil
}

func (m *Manager) scheduleItemReconcile(sessionID string) {
	if sessionID == "" {
		return
	}
	m.itemSyncMu.Lock()
	if timer := m.itemSyncTimers[sessionID]; timer != nil {
		timer.Reset(itemReconcileDebounce)
		m.itemSyncMu.Unlock()
		return
	}
	m.itemSyncTimers[sessionID] = time.AfterFunc(itemReconcileDebounce, func() {
		m.itemSyncMu.Lock()
		delete(m.itemSyncTimers, sessionID)
		m.itemSyncMu.Unlock()
		m.reconcileSessionItemsAndBroadcast(context.Background(), sessionID)
	})
	m.itemSyncMu.Unlock()
}

func (m *Manager) reconcileSessionItemsAndBroadcast(ctx context.Context, sessionID string) {
	changes, err := m.ReconcileSessionItems(ctx, sessionID)
	if err != nil {
		log.Warn("session", "reconcile scheduled items failed session=%s: %v", sessionID, err)
		return
	}
	m.broadcastItemChanges(sessionID, changes)
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
		if requiresProjectionReconcile(event.Type) {
			m.scheduleItemReconcile(sessionID)
		}
		return
	}
	changes, err := m.itemProjection.Upsert(context.Background(), sessionID, item)
	if err != nil {
		log.Warn("session", "upsert runtime item failed session=%s item=%s type=%s: %v", sessionID, item.ItemID, event.Type, err)
		if requiresProjectionReconcile(event.Type) {
			m.scheduleItemReconcile(sessionID)
		}
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

func requiresProjectionReconcile(eventType string) bool {
	switch eventType {
	case string(provider.EventTurnFailed):
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
