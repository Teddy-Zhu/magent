package codex

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/Teddy-Zhu/magent/agent/internal/log"
	"github.com/Teddy-Zhu/magent/agent/internal/protocol"
	"github.com/Teddy-Zhu/magent/agent/internal/provider"
	"github.com/Teddy-Zhu/magent/agent/internal/storage"
	"github.com/Teddy-Zhu/magent/agent/internal/ws"
)

type CodexConfig struct {
	Binary string
}

type sessionMeta struct {
	Model          string
	Workdir        string
	Purpose        string
	ApprovalPolicy string
	SandboxMode    string
	Effort         string
}

type queuedInput struct {
	sessionID string
	threadID  string
	input     provider.SendInputRequest
}

type CodexProvider struct {
	client        *AppServerClient
	clientMu      sync.Mutex
	threadIDs     map[string]string
	threadIDsMu   sync.RWMutex
	sessions      map[string]chan provider.ProviderEvent
	sessionsMu    sync.RWMutex
	meta          map[string]*sessionMeta
	metaMu        sync.RWMutex
	approval      *ApprovalProxy
	cfg           CodexConfig
	cachedConfig  *provider.ProviderConfig
	configMu      sync.RWMutex
	queuedInputs  map[string][]queuedInput
	queueDraining map[string]bool
	queueMu       sync.Mutex
	// localStore 直接读 codex 的 ~/.codex/state_5.sqlite，包含 source / model /
	// reasoning_effort 等 thread/list API 不返回的字段。可能为 nil（未配置 HOME 等）。
	localStore *LocalThreadStore
}

func New(cfg CodexConfig, hub *ws.Hub, store *storage.SQLite) *CodexProvider {
	return &CodexProvider{
		threadIDs:     make(map[string]string),
		sessions:      make(map[string]chan provider.ProviderEvent),
		meta:          make(map[string]*sessionMeta),
		queuedInputs:  make(map[string][]queuedInput),
		queueDraining: make(map[string]bool),
		approval:      NewApprovalProxy(hub, store),
		cfg:           cfg,
		localStore:    newLocalThreadStore(),
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
		Name:         "codex",
		Binary:       binary,
		Status:       "available",
		RunMode:      "app-server-stdio",
		Capabilities: p.Capabilities(),
	}, nil
}

func (p *CodexProvider) appServerClient(ctx context.Context) (*AppServerClient, error) {
	p.clientMu.Lock()
	defer p.clientMu.Unlock()
	if p.client != nil {
		select {
		case <-p.client.Done():
			p.client = nil
		default:
			return p.client, nil
		}
	}

	binary := p.cfg.Binary
	if binary == "" {
		var err error
		binary, err = exec.LookPath("codex")
		if err != nil {
			return nil, fmt.Errorf("codex not found: %w", err)
		}
	}

	client, err := NewAppServerClient(ctx, binary)
	if err != nil {
		return nil, err
	}
	if err := client.Initialize(ctx); err != nil {
		client.Close()
		return nil, err
	}

	p.client = client
	go p.forwardClientEvents(client)
	go p.handleServerRequests(client)
	return client, nil
}

func (p *CodexProvider) CreateSession(ctx context.Context, req provider.CreateSessionRequest) (*provider.Session, error) {
	p.applyDefaults(&req)
	log.Debug("codex", "creating session model=%s workdir=%s", req.Model, req.Workdir)
	client, err := p.appServerClient(ctx)
	if err != nil {
		log.Error("codex", "appserver client failed: %v", err)
		return nil, err
	}

	threadID, err := client.StartThread(ctx, req.Model, req.Workdir, req.ApprovalPolicy, req.SandboxMode)
	if err != nil {
		log.Error("codex", "start thread failed: %v", err)
		return nil, err
	}

	// Use threadID as the session ID — codex is the source of truth
	sessionID := threadID
	log.Info("codex", "session created id=%s thread=%s", sessionID, threadID)
	p.threadIDsMu.Lock()
	p.threadIDs[sessionID] = threadID
	p.threadIDsMu.Unlock()

	// Store session metadata for later use (e.g. turn/start when no active turn)
	p.metaMu.Lock()
	p.meta[sessionID] = &sessionMeta{
		Model:          req.Model,
		Workdir:        req.Workdir,
		Purpose:        req.Purpose,
		ApprovalPolicy: req.ApprovalPolicy,
		SandboxMode:    req.SandboxMode,
		Effort:         req.Effort,
	}
	p.metaMu.Unlock()

	// Create event channel before starting forwardEvents to avoid losing early events
	p.sessionsMu.Lock()
	p.sessions[sessionID] = make(chan provider.ProviderEvent, 256)
	p.sessionsMu.Unlock()

	if req.Prompt != "" {
		log.Debug("codex", "sending initial prompt len=%d", len(req.Prompt))
		if _, err := client.StartTurn(ctx, threadID, codexTextInput(req.Prompt, nil), req.Workdir, req.ApprovalPolicy, req.SandboxMode, req.Model, req.Effort); err != nil {
			log.Error("codex", "start turn failed: %v", err)
			p.StopSession(ctx, sessionID)
			return nil, err
		}
	}

	return &provider.Session{
		ID:             sessionID,
		ProviderID:     "codex",
		ThreadID:       threadID,
		ProjectID:      req.ProjectID,
		Purpose:        req.Purpose,
		Workdir:        req.Workdir,
		Status:         string(provider.SessionStatusRunning),
		RunnerType:     "app-server",
		// magent 通过 codex app-server 创建的会话在 codex 那边记成 sourceKind=appServer.
		Source:         "appServer",
		Model:          req.Model,
		Effort:         req.Effort,
		ApprovalPolicy: req.ApprovalPolicy,
		SandboxMode:    req.SandboxMode,
	}, nil
}

func (p *CodexProvider) forwardClientEvents(client *AppServerClient) {
	defer func() {
		p.clientMu.Lock()
		if p.client == client {
			p.client = nil
		}
		p.clientMu.Unlock()
	}()

	for event := range client.Events() {
		sessionID := event.SessionID
		if sessionID == "" {
			sessionID = sessionIDFromPayload(event.Payload)
		}
		if sessionID == "" {
			log.Warn("codex", "dropping event without session id type=%s", event.Type)
			continue
		}
		event.SessionID = sessionID
		p.emit(sessionID, event)
		if eventClosesSession(event) {
			p.markSessionInactive(sessionID)
		}
		switch event.Type {
		case string(provider.EventTurnCompleted), string(provider.EventTurnFailed):
			go p.drainQueuedInput(context.Background(), sessionID)
		}
	}
}

func eventClosesSession(event provider.ProviderEvent) bool {
	if event.Type != string(provider.EventSessionStatusChanged) {
		return false
	}
	status := statusTypeFromPayload(event.Payload)
	switch provider.NormalizeSessionStatus(status) {
	case string(provider.SessionStatusStopped), string(provider.SessionStatusLost):
		return true
	default:
		return false
	}
}

func statusTypeFromPayload(payload any) string {
	m, ok := payload.(map[string]any)
	if !ok {
		return ""
	}
	status := m["status"]
	switch value := status.(type) {
	case string:
		return value
	case map[string]any:
		if t, ok := value["type"].(string); ok {
			return t
		}
		if s, ok := value["status"].(string); ok {
			return s
		}
	case map[string]string:
		if t := value["type"]; t != "" {
			return t
		}
		return value["status"]
	}
	return ""
}

func (p *CodexProvider) markSessionInactive(sessionID string) {
	p.dropSessionRuntime(sessionID)
}

// handleServerRequests processes server-initiated JSON-RPC requests (e.g. approval requests).
// These have both an id (for response matching) and a method.
func (p *CodexProvider) handleServerRequests(client *AppServerClient) {
	for msg := range client.ServerRequests() {
		if msg.ID == nil {
			continue
		}
		requestID := *msg.ID

		switch msg.Method {
		case "item/commandExecution/requestApproval",
			"item/fileChange/requestApproval",
			"item/mcpToolCall/requestApproval":
			p.handleApprovalRequest(client, requestID, msg)

		default:
			log.Warn("codex", "unknown server request method=%s id=%d", msg.Method, requestID)
			// Respond with empty result to avoid blocking
			client.respond(requestID, map[string]any{})
		}
	}
}

func (p *CodexProvider) handleApprovalRequest(client *AppServerClient, requestID int64, msg *protocol.JSONRPCResponse) {
	var params map[string]any
	if err := json.Unmarshal(msg.Params, &params); err != nil {
		log.Error("codex", "approval params parse error: %v", err)
		client.respond(requestID, map[string]any{"action": "decline"})
		return
	}

	// Extract item info — the params may have an "item" sub-object or flat fields
	item, _ := params["item"].(map[string]any)
	if item == nil {
		item = params
	}

	command, _ := item["command"].(string)
	filePath, _ := item["file_path"].(string)
	sessionID, _ := params["threadId"].(string)
	if sessionID == "" {
		sessionID = sessionIDFromPayload(params)
	}
	itemID, _ := params["itemId"].(string)
	if itemID == "" {
		itemID, _ = item["id"].(string)
	}
	approvalID := itemID
	if approvalID == "" {
		approvalID = fmt.Sprintf("codex-%d", requestID)
	}
	turnID, _ := params["turnId"].(string)
	if turnID == "" {
		turnID, _ = item["turnId"].(string)
	}
	cwd, _ := params["cwd"].(string)
	if cwd == "" {
		cwd, _ = item["cwd"].(string)
	}
	filePath = firstNonEmptyString(filePath, stringFromMap(item, "path"), stringFromMap(item, "grantRoot"))

	approvalReq := ApprovalRequest{
		ID:        approvalID,
		SessionID: sessionID,
		ThreadID:  sessionID,
		TurnID:    turnID,
		ItemID:    itemID,
		Type:      msg.Method,
		Command:   command,
		FilePath:  filePath,
		CWD:       cwd,
		RequestID: requestID,
	}

	log.Debug("codex", "approval request rpc=%d approval=%s item=%s method=%s command=%s", requestID, approvalID, itemID, msg.Method, command)

	decision := p.approval.HandleRequest(context.Background(), approvalReq)

	// Send proper JSON-RPC response with the original request ID
	result := approvalDecisionResult(decision)
	if err := client.respond(requestID, result); err != nil {
		log.Error("codex", "approval respond error: %v", err)
	}
}

func (p *CodexProvider) emit(sessionID string, event provider.ProviderEvent) {
	p.sessionsMu.RLock()
	ch, ok := p.sessions[sessionID]
	p.sessionsMu.RUnlock()
	if ok {
		select {
		case ch <- event:
		case <-time.After(30 * time.Second):
			log.Warn("codex", "session event channel blocked session=%s type=%s", sessionID, event.Type)
		}
	}
}

func sessionIDFromPayload(payload any) string {
	m, ok := payload.(map[string]any)
	if !ok {
		return ""
	}
	for _, key := range []string{"threadId", "thread_id", "session_id"} {
		if id, ok := m[key].(string); ok && id != "" {
			return id
		}
	}
	if item, ok := m["item"].(map[string]any); ok {
		for _, key := range []string{"threadId", "thread_id"} {
			if id, ok := item[key].(string); ok && id != "" {
				return id
			}
		}
	}
	if thread, ok := m["thread"].(map[string]any); ok {
		for _, key := range []string{"id", "threadId", "thread_id"} {
			if id, ok := thread[key].(string); ok && id != "" {
				return id
			}
		}
	}
	return ""
}

func stringFromMap(m map[string]any, key string) string {
	value, _ := m[key].(string)
	return value
}

func firstNonEmptyString(values ...string) string {
	for _, value := range values {
		if value != "" {
			return value
		}
	}
	return ""
}

func approvalDecisionResult(decision provider.ApprovalDecision) any {
	if decision.Raw != nil {
		return decision.Raw
	}
	if decision.Action == "" {
		return "decline"
	}
	return decision.Action
}

func (p *CodexProvider) threadIDForSession(sessionID string) string {
	p.threadIDsMu.RLock()
	threadID := p.threadIDs[sessionID]
	p.threadIDsMu.RUnlock()
	if threadID != "" {
		return threadID
	}
	return sessionID
}

// Subscribe returns the event channel for a session.
// Multiple readers on the same channel is safe in Go.
func (p *CodexProvider) Subscribe(sessionID string) <-chan provider.ProviderEvent {
	p.sessionsMu.Lock()
	defer p.sessionsMu.Unlock()
	ch, ok := p.sessions[sessionID]
	if !ok {
		ch = make(chan provider.ProviderEvent, 256)
		p.sessions[sessionID] = ch
	}
	return ch
}

// Unsubscribe is a no-op. The channel is cleaned up when the session is stopped.
func (p *CodexProvider) Unsubscribe(sessionID string) {
	// Don't close or delete - other readers may still need the channel
}

// HasSession returns true if the session has an active client in memory.
func (p *CodexProvider) HasSession(sessionID string) bool {
	p.threadIDsMu.RLock()
	_, ok := p.threadIDs[sessionID]
	p.threadIDsMu.RUnlock()
	return ok
}

// ResumeSession reconnects to an existing codex thread by creating a new client
// and calling thread/resume.
func (p *CodexProvider) ResumeSession(ctx context.Context, sessionID, threadID string) error {
	p.threadIDsMu.RLock()
	_, ok := p.threadIDs[sessionID]
	p.threadIDsMu.RUnlock()
	if ok {
		return nil // already active
	}

	log.Info("codex", "resuming session=%s thread=%s", sessionID, threadID)
	client, err := p.appServerClient(ctx)
	if err != nil {
		return fmt.Errorf("resume: appserver: %w", err)
	}

	// Resume the existing thread
	result, err := client.call(ctx, "thread/resume", map[string]any{
		"threadId":               threadID,
		"persistExtendedHistory": true,
	})
	if err != nil {
		return fmt.Errorf("resume: thread/resume: %w", err)
	}
	log.Debug("codex", "thread/resume response: %s", string(result))

	p.threadIDsMu.Lock()
	p.threadIDs[sessionID] = threadID
	p.threadIDsMu.Unlock()

	// Initialize meta with defaults if not already present
	p.metaMu.Lock()
	if _, ok := p.meta[sessionID]; !ok {
		p.meta[sessionID] = &sessionMeta{
			ApprovalPolicy: string(provider.ApprovalPolicyOnRequest),
			SandboxMode:    string(provider.SandboxModeWorkspaceWrite),
			Model:          p.defaultModel(),
		}
	}
	p.metaMu.Unlock()

	p.sessionsMu.Lock()
	if _, ok := p.sessions[sessionID]; !ok {
		p.sessions[sessionID] = make(chan provider.ProviderEvent, 256)
	}
	p.sessionsMu.Unlock()

	log.Info("codex", "session resumed id=%s thread=%s", sessionID, threadID)
	return nil
}

func (p *CodexProvider) UpdateSessionMetadata(session provider.Session) {
	if session.ID == "" {
		return
	}
	p.metaMu.Lock()
	defer p.metaMu.Unlock()
	current := p.meta[session.ID]
	if current == nil {
		current = &sessionMeta{}
		p.meta[session.ID] = current
	}
	if session.Model != "" {
		current.Model = session.Model
	}
	if session.Workdir != "" {
		current.Workdir = session.Workdir
	}
	if session.ApprovalPolicy != "" {
		current.ApprovalPolicy = provider.NormalizeApprovalPolicy(session.ApprovalPolicy)
	}
	if session.SandboxMode != "" {
		current.SandboxMode = provider.NormalizeSandboxMode(session.SandboxMode)
	}
}

func (p *CodexProvider) ReadThreadEvents(ctx context.Context, threadID, cursor string, limit int) (*provider.EventPage, error) {
	client, err := p.appServerClient(ctx)
	if err != nil {
		return nil, err
	}

	turnsPage, nextCursor, hasMore, err := p.listThreadTurnsForSync(ctx, client, threadID, cursor, limit)
	if err != nil {
		return nil, err
	}

	events := codexTurnsToEvents(threadID, turnsPage.Turns)
	log.Info("codex", "ReadThreadEvents: thread=%s turns=%d events=%d cursor=%s next=%s", threadID, len(turnsPage.Turns), len(events), cursor, nextCursor)
	return &provider.EventPage{
		SessionID: threadID,
		Cursor:    nextCursor,
		HasMore:   hasMore,
		Events:    events,
	}, nil
}

func (p *CodexProvider) ReadThreadItems(ctx context.Context, threadID, cursor string, limit int) (*provider.ItemPage, error) {
	client, err := p.appServerClient(ctx)
	if err != nil {
		return nil, err
	}

	turnsPage, nextCursor, hasMore, err := p.listThreadTurnsForSync(ctx, client, threadID, cursor, limit)
	if err != nil {
		return nil, err
	}

	items := codexTurnsToItems(turnsPage.Turns)
	log.Info("codex", "ReadThreadItems: thread=%s turns=%d items=%d cursor=%q next=%q has_more=%t tail=%s", threadID, len(turnsPage.Turns), len(items), cursor, nextCursor, hasMore, codexSessionItemTailSummary(items, 8))
	return &provider.ItemPage{
		SessionID: threadID,
		Cursor:    nextCursor,
		HasMore:   hasMore,
		Items:     items,
	}, nil
}

func codexSessionItemTailSummary(items []provider.SessionItem, limit int) string {
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

func (p *CodexProvider) listThreadTurnsForSync(ctx context.Context, client *AppServerClient, threadID, cursor string, limit int) (*ThreadTurnsPage, string, bool, error) {
	wireCursor, sortDirection := decodeCodexSyncCursor(cursor)
	page, err := client.ListThreadTurns(ctx, threadID, wireCursor, limit, sortDirection)
	if err != nil {
		return nil, "", false, err
	}
	if sortDirection == "desc" {
		reverseThreadTurns(page.Turns)
	}
	nextCursor := encodeCodexSyncCursor(page, cursor)
	hasMore := page.NextCursor != ""
	if sortDirection == "asc" {
		hasMore = page.NextCursor != ""
	}
	return page, nextCursor, hasMore, nil
}

func decodeCodexSyncCursor(cursor string) (string, string) {
	if strings.HasPrefix(cursor, "newer:") {
		return strings.TrimPrefix(cursor, "newer:"), "asc"
	}
	if cursor != "" {
		return cursor, "asc"
	}
	return "", "desc"
}

func encodeCodexSyncCursor(page *ThreadTurnsPage, previous string) string {
	if page.BackwardsCursor != "" {
		return "newer:" + page.BackwardsCursor
	}
	if strings.HasPrefix(previous, "newer:") {
		return previous
	}
	return ""
}

func reverseThreadTurns(turns []ThreadTurn) {
	for i, j := 0, len(turns)-1; i < j; i, j = i+1, j-1 {
		turns[i], turns[j] = turns[j], turns[i]
	}
}

func codexTurnsToEvents(threadID string, turns []ThreadTurn) []provider.ProviderEvent {
	var events []provider.ProviderEvent
	for turnIndex, turn := range turns {
		ts := codexTurnTime(turn, turnIndex)
		for itemIndex, item := range turn.Items {
			events = append(events, codexItemToEvent(threadID, turn.ID, item, ts, codexStableItemIndex(turn, turnIndex, itemIndex)))
		}
	}
	return events
}

func codexItemToEvent(threadID, turnID string, item TurnItem, ts time.Time, index int) provider.ProviderEvent {
	itemType := normalizeCodexItemType(item.Type)
	payload := codexItemPayload(item)
	payload["index"] = index
	eventType := string(provider.EventItemCompleted)
	switch itemType {
	case string(provider.ItemTypeUserMessage):
		eventType = string(provider.EventUserMessage)
		if text := codexItemText(item); text != "" {
			payload["content"] = text
		}
	case string(provider.ItemTypeAgentMessage):
		eventType = string(provider.EventMessage)
		if item.Text != "" {
			payload["text"] = item.Text
		}
	case string(provider.ItemTypeCommandExecution):
		eventType = string(provider.EventCommandCompleted)
		if item.AggregatedOutput != "" {
			payload["output"] = item.AggregatedOutput
		}
		if item.ExitCode != nil {
			payload["exit_code"] = *item.ExitCode
		}
	case string(provider.ItemTypeFileChange):
		eventType = string(provider.EventFileWrite)
		applyCodexFileChangeDetails(payload, item.Changes)
	case string(provider.ItemTypeFileRead):
		eventType = string(provider.EventFileRead)
	case string(provider.ItemTypeMCPToolCall):
		eventType = string(provider.EventMCPToolCompleted)
	}
	return provider.ProviderEvent{
		SessionID: threadID,
		Cursor:    codexItemCursor(turnID, item.ID),
		Type:      eventType,
		ItemID:    item.ID,
		TurnID:    turnID,
		Payload:   payload,
		Timestamp: ts,
	}
}

func codexTurnsToItems(turns []ThreadTurn) []provider.SessionItem {
	var items []provider.SessionItem
	for turnIndex, turn := range turns {
		createdAt := codexTurnTime(turn, turnIndex)
		updatedAt := codexTurnUpdatedTime(turn, createdAt)
		for itemIndex, item := range turn.Items {
			itemType := normalizeCodexItemType(item.Type)
			items = append(items, provider.SessionItem{
				Cursor:    codexItemCursor(turn.ID, item.ID),
				ItemID:    item.ID,
				TurnID:    turn.ID,
				Index:     codexStableItemIndex(turn, turnIndex, itemIndex),
				Type:      itemType,
				Status:    codexItemStatus(item, turn),
				Role:      codexItemRole(itemType),
				Summary:   codexItemSummary(item),
				Content:   codexItemContent(item),
				CreatedAt: createdAt,
				UpdatedAt: updatedAt,
			})
		}
	}
	return items
}

func codexItemIndex(turnIndex, itemIndex int) int {
	return turnIndex*100000 + itemIndex
}

func codexStableItemIndex(turn ThreadTurn, fallbackTurnIndex, itemIndex int) int {
	if turn.StartedAt > 0 {
		return int(turn.StartedAt)*100000 + itemIndex
	}
	if turn.CompletedAt > 0 {
		return int(turn.CompletedAt)*100000 + itemIndex
	}
	if millis, ok := codexUUIDv7Millis(turn.ID); ok {
		return int(millis)*100 + itemIndex
	}
	return codexItemIndex(fallbackTurnIndex, itemIndex)
}

func codexTurnTime(turn ThreadTurn, fallbackTurnIndex int) time.Time {
	if turn.StartedAt > 0 {
		return time.Unix(turn.StartedAt, 0)
	}
	if turn.CompletedAt > 0 {
		return time.Unix(turn.CompletedAt, 0)
	}
	if millis, ok := codexUUIDv7Millis(turn.ID); ok {
		return time.UnixMilli(int64(millis))
	}
	return time.Unix(int64(fallbackTurnIndex), 0)
}

func codexTurnUpdatedTime(turn ThreadTurn, createdAt time.Time) time.Time {
	if turn.CompletedAt > 0 {
		return time.Unix(turn.CompletedAt, 0)
	}
	return createdAt
}

func codexUUIDv7Millis(id string) (uint64, bool) {
	cleaned := strings.ReplaceAll(id, "-", "")
	if len(cleaned) < 12 {
		return 0, false
	}
	millis, err := strconv.ParseUint(cleaned[:12], 16, 64)
	if err != nil || millis == 0 {
		return 0, false
	}
	return millis, true
}

func codexItemCursor(turnID, itemID string) string {
	if itemID == "" {
		return turnID
	}
	return turnID + ":" + itemID
}

func normalizeCodexItemType(itemType string) string {
	normalized := provider.NormalizeItemType(itemType)
	if normalized != itemType {
		return normalized
	}
	switch itemType {
	case "dynamicToolCall", "dynamic_tool_call":
		return "dynamic_tool_call"
	case "collabToolCall", "collab_tool_call":
		return "collab_tool_call"
	case "webSearch", "web_search":
		return "web_search"
	case "imageView", "image_view":
		return "image_view"
	case "enteredReviewMode", "entered_review_mode":
		return "entered_review_mode"
	case "exitedReviewMode", "exited_review_mode":
		return "exited_review_mode"
	case "contextCompaction", "context_compaction":
		return "context_compaction"
	default:
		return itemType
	}
}

func codexItemRole(itemType string) string {
	switch itemType {
	case string(provider.ItemTypeUserMessage):
		return "user"
	case string(provider.ItemTypeAgentMessage):
		return "assistant"
	default:
		return ""
	}
}

func codexItemStatus(item TurnItem, turn ThreadTurn) string {
	if item.Status != "" {
		return item.Status
	}
	if turn.Status != "" {
		return turn.Status
	}
	return string(provider.SessionStatusCompleted)
}

func codexItemSummary(item TurnItem) string {
	if item.Text != "" {
		return truncateString(item.Text, 160)
	}
	if text := codexItemText(item); text != "" {
		return truncateString(text, 160)
	}
	if command, ok := item.Command.(string); ok && command != "" {
		return truncateString(command, 160)
	}
	if item.Path != "" {
		return item.Path
	}
	if len(item.Changes) > 0 {
		return item.Changes[0].Path
	}
	return normalizeCodexItemType(item.Type)
}

func codexItemContent(item TurnItem) any {
	content := codexItemPayload(item)
	content["type"] = normalizeCodexItemType(item.Type)
	if text := codexItemText(item); text != "" {
		content["text"] = text
	}
	if item.Text != "" {
		content["text"] = item.Text
	}
	if item.AggregatedOutput != "" {
		content["output"] = item.AggregatedOutput
	}
	if item.ExitCode != nil {
		content["exit_code"] = *item.ExitCode
	}
	if normalizeCodexItemType(item.Type) == string(provider.ItemTypeFileChange) {
		applyCodexFileChangeDetails(content, item.Changes)
	}
	return content
}

func applyCodexFileChangeDetails(payload map[string]any, changes []TurnItemChange) {
	if len(changes) == 0 {
		return
	}
	if payload["path"] == nil && changes[0].Path != "" {
		payload["path"] = changes[0].Path
	}
	if payload["kind"] == nil {
		if kind := changes[0].Kind.Type; kind != "" {
			payload["kind"] = kind
		} else if changes[0].Kind.Raw != nil {
			payload["kind"] = changes[0].Kind.Raw
		}
	}
	additions, deletions, hasStats := countCodexFileChanges(changes)
	if hasStats {
		payload["additions"] = additions
		payload["deletions"] = deletions
	}
	payload["change_count"] = len(changes)
	if payload["diff"] == nil {
		if diff := combinedCodexDiff(changes); diff != "" {
			payload["diff"] = diff
		}
	}
}

func applyCodexFileChangePayloadDetails(payload map[string]any) {
	applyCodexFileChangeDetails(payload, codexPayloadChanges(payload["changes"]))
}

func codexPayloadChanges(value any) []TurnItemChange {
	rawChanges, ok := value.([]any)
	if !ok {
		return nil
	}
	changes := make([]TurnItemChange, 0, len(rawChanges))
	for _, rawChange := range rawChanges {
		changeMap, ok := rawChange.(map[string]any)
		if !ok {
			continue
		}
		changes = append(changes, TurnItemChange{
			Path: stringFromAny(changeMap["path"]),
			Kind: changeKindFromAny(changeMap["kind"]),
			Diff: stringFromAny(changeMap["diff"]),
		})
	}
	return changes
}

func changeKindFromAny(value any) ChangeKind {
	switch kind := value.(type) {
	case string:
		return ChangeKind{Type: kind, Raw: kind}
	case map[string]any:
		result := ChangeKind{
			Type: stringFromAny(kind["type"]),
			Raw:  kind,
		}
		if movePath := stringFromAny(kind["move_path"]); movePath != "" {
			result.MovePath = &movePath
		}
		return result
	default:
		return ChangeKind{}
	}
}

func countCodexFileChanges(changes []TurnItemChange) (int, int, bool) {
	var additions, deletions int
	hasDiff := false
	for _, change := range changes {
		if change.Diff == "" {
			continue
		}
		hasDiff = true
		add, del := countUnifiedDiffLines(change.Diff)
		additions += add
		deletions += del
	}
	return additions, deletions, hasDiff && (additions > 0 || deletions > 0)
}

func countUnifiedDiffLines(diff string) (int, int) {
	var additions, deletions int
	for _, line := range strings.Split(diff, "\n") {
		switch {
		case strings.HasPrefix(line, "+++") || strings.HasPrefix(line, "---"):
			continue
		case strings.HasPrefix(line, "+"):
			additions++
		case strings.HasPrefix(line, "-"):
			deletions++
		}
	}
	return additions, deletions
}

func combinedCodexDiff(changes []TurnItemChange) string {
	var parts []string
	for _, change := range changes {
		if change.Diff != "" {
			parts = append(parts, change.Diff)
		}
	}
	return strings.Join(parts, "\n")
}

func stringFromAny(value any) string {
	switch v := value.(type) {
	case nil:
		return ""
	case string:
		return v
	default:
		return fmt.Sprint(v)
	}
}

func codexItemPayload(item TurnItem) map[string]any {
	if item.Raw != nil {
		payload := make(map[string]any, len(item.Raw))
		for k, v := range item.Raw {
			payload[k] = v
		}
		if item.ID != "" && payload["id"] == nil {
			payload["id"] = item.ID
		}
		applyCodexTypedItemFields(payload, item)
		return payload
	}
	payload := map[string]any{
		"id":   item.ID,
		"type": item.Type,
	}
	applyCodexTypedItemFields(payload, item)
	return payload
}

func applyCodexTypedItemFields(payload map[string]any, item TurnItem) {
	if item.Type != "" && payload["type"] == nil {
		payload["type"] = item.Type
	}
	if item.Text != "" && payload["text"] == nil {
		payload["text"] = item.Text
	}
	if item.Phase != "" && payload["phase"] == nil {
		payload["phase"] = item.Phase
	}
	if item.Status != "" && payload["status"] == nil {
		payload["status"] = item.Status
	}
	if item.Summary != nil && payload["summary"] == nil {
		payload["summary"] = item.Summary
	}
	if item.Command != nil && payload["command"] == nil {
		payload["command"] = item.Command
	}
	if item.CWD != "" && payload["cwd"] == nil {
		payload["cwd"] = item.CWD
	}
	if item.AggregatedOutput != "" && payload["aggregatedOutput"] == nil {
		payload["aggregatedOutput"] = item.AggregatedOutput
	}
	if item.ExitCode != nil && payload["exitCode"] == nil {
		payload["exitCode"] = *item.ExitCode
	}
	if item.Path != "" && payload["path"] == nil {
		payload["path"] = item.Path
	}
	if item.Tool != "" && payload["tool"] == nil {
		payload["tool"] = item.Tool
	}
	if item.Result != nil && payload["result"] == nil {
		payload["result"] = item.Result
	}
	if item.Error != nil && payload["error"] == nil {
		payload["error"] = item.Error
	}
	if len(item.Changes) > 0 && payload["changes"] == nil {
		payload["changes"] = item.Changes
	}
}

func codexItemText(item TurnItem) string {
	var b strings.Builder
	for _, c := range item.Content {
		if c.Text != "" {
			b.WriteString(c.Text)
		}
	}
	return b.String()
}

func truncateString(value string, max int) string {
	if max <= 0 || len(value) <= max {
		return value
	}
	return value[:max]
}

func (p *CodexProvider) ForkSession(ctx context.Context, sessionID, threadID string) (string, error) {
	client, err := p.appServerClient(ctx)
	if err != nil {
		return "", err
	}
	sourceThreadID := threadID
	if sourceThreadID == "" {
		sourceThreadID = p.threadIDForSession(sessionID)
	}
	if sourceThreadID == "" {
		return "", fmt.Errorf("session %s not found", sessionID)
	}

	newThreadID, err := client.ForkThread(ctx, sourceThreadID)
	if err != nil {
		return "", err
	}

	p.threadIDsMu.Lock()
	p.threadIDs[newThreadID] = newThreadID
	p.threadIDsMu.Unlock()

	p.metaMu.RLock()
	sourceMeta := p.meta[sessionID]
	p.metaMu.RUnlock()
	if sourceMeta != nil {
		metaCopy := *sourceMeta
		p.metaMu.Lock()
		p.meta[newThreadID] = &metaCopy
		p.metaMu.Unlock()
	}

	p.sessionsMu.Lock()
	if _, ok := p.sessions[newThreadID]; !ok {
		p.sessions[newThreadID] = make(chan provider.ProviderEvent, 256)
	}
	p.sessionsMu.Unlock()

	return newThreadID, nil
}

func (p *CodexProvider) SendInput(ctx context.Context, sessionID string, input provider.SendInputRequest) error {
	client, err := p.appServerClient(ctx)
	if err != nil {
		return err
	}
	threadID := p.threadIDForSession(sessionID)
	if threadID == "" {
		return fmt.Errorf("session %s not found", sessionID)
	}
	input.Mode = provider.NormalizeSendInputMode(input.Mode)

	client.activeTurnMu.Lock()
	activeTurnID := client.activeTurnIDs[threadID]
	client.activeTurnMu.Unlock()

	switch input.Mode {
	case string(provider.SendInputModeQueue):
		if activeTurnID != "" || p.hasQueuedInput(sessionID) {
			log.Debug("codex", "SendInput: queueing input thread=%s active_turn=%s", threadID, activeTurnID)
			p.enqueueInput(sessionID, threadID, input)
			if activeTurnID == "" {
				go p.drainQueuedInput(context.Background(), sessionID)
			}
			return nil
		}
	case string(provider.SendInputModeInterruptThenSend):
		if activeTurnID != "" {
			log.Debug("codex", "SendInput: interrupting and queueing input thread=%s active_turn=%s", threadID, activeTurnID)
			p.enqueueInput(sessionID, threadID, input)
			if err := client.InterruptTurn(ctx, threadID); err != nil {
				p.dropLastQueuedInput(sessionID)
				return err
			}
			return nil
		}
		if p.hasQueuedInput(sessionID) {
			p.enqueueInput(sessionID, threadID, input)
			go p.drainQueuedInput(context.Background(), sessionID)
			return nil
		}
	case string(provider.SendInputModeAuto), string(provider.SendInputModeSteer):
		if activeTurnID != "" {
			log.Debug("codex", "SendInput: steering active turn=%s thread=%s", activeTurnID, threadID)
			return client.SteerTurn(ctx, threadID, codexTextInput(input.Input, input.Items))
		}
	default:
		return fmt.Errorf("unsupported send input mode %q", input.Mode)
	}

	return p.startInputTurn(ctx, client, sessionID, threadID, input)
}

func (p *CodexProvider) hasQueuedInput(sessionID string) bool {
	p.queueMu.Lock()
	defer p.queueMu.Unlock()
	return len(p.queuedInputs[sessionID]) > 0
}

func (p *CodexProvider) enqueueInput(sessionID, threadID string, input provider.SendInputRequest) {
	p.queueMu.Lock()
	defer p.queueMu.Unlock()
	if p.queuedInputs == nil {
		p.queuedInputs = make(map[string][]queuedInput)
	}
	p.queuedInputs[sessionID] = append(p.queuedInputs[sessionID], queuedInput{
		sessionID: sessionID,
		threadID:  threadID,
		input:     input,
	})
}

func (p *CodexProvider) dropLastQueuedInput(sessionID string) {
	p.queueMu.Lock()
	defer p.queueMu.Unlock()
	queue := p.queuedInputs[sessionID]
	if len(queue) == 0 {
		return
	}
	if len(queue) == 1 {
		delete(p.queuedInputs, sessionID)
		return
	}
	p.queuedInputs[sessionID] = queue[:len(queue)-1]
}

func (p *CodexProvider) prependQueuedInput(item queuedInput) {
	p.queueMu.Lock()
	defer p.queueMu.Unlock()
	if p.queuedInputs == nil {
		p.queuedInputs = make(map[string][]queuedInput)
	}
	p.queuedInputs[item.sessionID] = append([]queuedInput{item}, p.queuedInputs[item.sessionID]...)
}

func (p *CodexProvider) drainQueuedInput(ctx context.Context, sessionID string) {
	if !p.beginQueueDrain(sessionID) {
		return
	}
	defer p.endQueueDrain(sessionID)

	p.queueMu.Lock()
	queue := p.queuedInputs[sessionID]
	if len(queue) == 0 {
		p.queueMu.Unlock()
		return
	}
	next := queue[0]
	p.queuedInputs[sessionID] = queue[1:]
	p.queueMu.Unlock()

	client, err := p.appServerClient(ctx)
	if err != nil {
		log.Error("codex", "drain queued input: appserver client failed session=%s: %v", sessionID, err)
		return
	}

	threadID := next.threadID
	if threadID == "" {
		threadID = p.threadIDForSession(sessionID)
	}
	if threadID == "" {
		log.Warn("codex", "drain queued input: session %s not found", sessionID)
		return
	}

	client.activeTurnMu.Lock()
	activeTurnID := client.activeTurnIDs[threadID]
	client.activeTurnMu.Unlock()
	if activeTurnID != "" {
		next.threadID = threadID
		p.prependQueuedInput(next)
		return
	}

	if err := p.startInputTurn(ctx, client, next.sessionID, threadID, next.input); err != nil {
		log.Error("codex", "drain queued input: start turn failed session=%s: %v", sessionID, err)
	}
}

func (p *CodexProvider) beginQueueDrain(sessionID string) bool {
	p.queueMu.Lock()
	defer p.queueMu.Unlock()
	if p.queueDraining == nil {
		p.queueDraining = make(map[string]bool)
	}
	if p.queueDraining[sessionID] {
		return false
	}
	p.queueDraining[sessionID] = true
	return true
}

func (p *CodexProvider) endQueueDrain(sessionID string) {
	p.queueMu.Lock()
	defer p.queueMu.Unlock()
	delete(p.queueDraining, sessionID)
}

func (p *CodexProvider) startInputTurn(ctx context.Context, client *AppServerClient, sessionID, threadID string, input provider.SendInputRequest) error {
	if threadID == "" {
		return fmt.Errorf("session %s not found", sessionID)
	}
	client.activeTurnMu.Lock()
	activeTurnID := client.activeTurnIDs[threadID]
	client.activeTurnMu.Unlock()
	if activeTurnID != "" {
		log.Debug("codex", "SendInput: active turn appeared while starting; queueing thread=%s active_turn=%s", threadID, activeTurnID)
		p.enqueueInput(sessionID, threadID, input)
		return nil
	}

	// No active turn — start a new one.
	log.Debug("codex", "SendInput: starting new turn thread=%s", threadID)

	// 客户端可在每次发送时覆盖 model / effort / approval / sandbox。
	// 我们写回 in-memory sessionMeta 让 enqueue/重试路径继承同一组设置。
	p.metaMu.Lock()
	current := p.meta[sessionID]
	if current == nil {
		current = &sessionMeta{}
		p.meta[sessionID] = current
	}
	if input.Model != "" {
		current.Model = input.Model
	}
	if input.Effort != "" {
		current.Effort = input.Effort
	}
	if input.ApprovalPolicy != "" {
		current.ApprovalPolicy = provider.NormalizeApprovalPolicy(input.ApprovalPolicy)
	}
	if input.SandboxMode != "" {
		current.SandboxMode = provider.NormalizeSandboxMode(input.SandboxMode)
	}
	model, workdir, effort := current.Model, current.Workdir, current.Effort
	approvalPolicy := current.ApprovalPolicy
	sandboxMode := current.SandboxMode
	p.metaMu.Unlock()

	if approvalPolicy == "" {
		approvalPolicy = string(provider.ApprovalPolicyOnRequest)
	}
	if sandboxMode == "" {
		sandboxMode = string(provider.SandboxModeWorkspaceWrite)
	}
	if model == "" {
		model = p.defaultModel()
		p.metaMu.Lock()
		if cur := p.meta[sessionID]; cur != nil {
			cur.Model = model
		}
		p.metaMu.Unlock()
	}

	if _, err := client.StartTurn(ctx, threadID, codexTextInput(input.Input, input.Items), workdir, approvalPolicy, sandboxMode, model, effort); err != nil {
		return err
	}
	return nil
}

func (p *CodexProvider) applyDefaults(req *provider.CreateSessionRequest) {
	if req.Model == "" {
		req.Model = p.defaultModel()
	}
	req.ApprovalPolicy = provider.NormalizeApprovalPolicy(req.ApprovalPolicy)
	req.SandboxMode = provider.NormalizeSandboxMode(req.SandboxMode)
}

func (p *CodexProvider) defaultModel() string {
	cfg := p.Config()
	for _, model := range cfg.Models {
		if model.Default && model.ID != "" {
			return model.ID
		}
	}
	for _, model := range cfg.Models {
		if model.ID != "" {
			return model.ID
		}
	}
	return "gpt-5.5"
}


func (p *CodexProvider) InterruptSession(ctx context.Context, sessionID string) error {
	client, err := p.appServerClient(ctx)
	if err != nil {
		return err
	}
	threadID := p.threadIDForSession(sessionID)
	if threadID == "" {
		return fmt.Errorf("session %s not found", sessionID)
	}

	return client.InterruptTurn(ctx, threadID)
}

func (p *CodexProvider) StopSession(ctx context.Context, sessionID string) error {
	client, err := p.appServerClient(ctx)
	if err != nil {
		return err
	}
	threadID := p.threadIDForSession(sessionID)
	if threadID == "" {
		return fmt.Errorf("session %s not found", sessionID)
	}

	if err := client.UnsubscribeThread(ctx, threadID); err != nil {
		log.Warn("codex", "unsubscribe thread %s failed: %v", threadID, err)
	}

	p.dropSessionRuntime(sessionID)

	return nil
}

func (p *CodexProvider) ResolveApproval(ctx context.Context, sessionID, approvalID string, decision provider.ApprovalDecision) error {
	if ok := p.approval.Resolve(approvalID, decision); !ok {
		return fmt.Errorf("approval %s not found", approvalID)
	}
	return nil
}

func (p *CodexProvider) CompactSession(ctx context.Context, sessionID string) error {
	client, err := p.appServerClient(ctx)
	if err != nil {
		return err
	}
	threadID := p.threadIDForSession(sessionID)
	if threadID == "" {
		return fmt.Errorf("session %s not found", sessionID)
	}
	return client.CompactThread(ctx, threadID)
}

func (p *CodexProvider) RollbackSession(ctx context.Context, sessionID string, turns int) error {
	client, err := p.appServerClient(ctx)
	if err != nil {
		return err
	}
	threadID := p.threadIDForSession(sessionID)
	if threadID == "" {
		return fmt.Errorf("session %s not found", sessionID)
	}
	return client.RollbackThread(ctx, threadID, turns)
}

func (p *CodexProvider) Capabilities() provider.ProviderCapabilities {
	return provider.ProviderCapabilities{
		Protocol:               "app-server-stdio",
		SupportsResume:         true,
		SupportsFork:           true,
		SupportsSteer:          true,
		SupportsInterrupt:      true,
		SupportsCompact:        true,
		SupportsRollback:       true,
		SupportsApproval:       true,
		SupportsFileSystem:     true,
		SupportsMCP:            true,
		SupportsCommand:        true,
		SupportsModelSwitch:    true,
		SupportsSandboxConfig:  true,
		SupportsApprovalPolicy: true,
		StructuredOutput:       true,
		StreamingOutput:        true,
		SupportsPTY:            false,
	}
}

func (p *CodexProvider) ListThreadInfos(ctx context.Context, cwd string, limit int) ([]ThreadInfo, error) {
	return p.ListThreadInfosWithOptions(ctx, provider.ThreadListOptions{
		CWD:   cwd,
		Limit: limit,
	})
}

func (p *CodexProvider) ListThreadInfosWithOptions(ctx context.Context, opts provider.ThreadListOptions) ([]ThreadInfo, error) {
	listOpts := ListThreadsOptions{
		CWD:      opts.CWD,
		Limit:    opts.Limit,
		Archived: opts.Archived,
	}
	// 优先 codex 本地 sqlite — 它能提供 source / model / reasoning_effort
	// 等 app-server thread/list 不返回的字段。
	if p.localStore != nil && p.localStore.Available() {
		threads, err := p.localStore.ListThreads(ctx, listOpts)
		if err == nil {
			return threads, nil
		}
		log.Warn("codex", "local thread store unavailable, falling back to appserver: %v", err)
	}

	client, err := p.appServerClient(ctx)
	if err != nil {
		return nil, err
	}
	return client.ListThreadsWithOptions(ctx, listOpts)
}

// ListThreads queries codex for threads and converts them to provider.Session.
// This makes codex the source of truth for session listing.
func (p *CodexProvider) ListThreads(ctx context.Context, cwd string, limit int) ([]provider.Session, error) {
	return p.ListThreadsWithOptions(ctx, provider.ThreadListOptions{
		CWD:   cwd,
		Limit: limit,
	})
}

func (p *CodexProvider) ListThreadsWithOptions(ctx context.Context, opts provider.ThreadListOptions) ([]provider.Session, error) {
	threads, err := p.ListThreadInfosWithOptions(ctx, opts)
	if err != nil {
		return nil, err
	}

	var sessions []provider.Session
	for _, t := range threads {
		s := p.threadInfoToSession(t, opts.Archived)
		// 列表里 model/effort 如果 ThreadInfo 没带（fallback appserver 路径），
		// 用进程内 sessionMeta（活跃会话）兜底；如果连这也没有就保持空，让
		// 前端自己决定如何展示——避免显示假的默认值。
		if s.Model == "" || s.Effort == "" {
			p.metaMu.RLock()
			meta := p.meta[s.ID]
			p.metaMu.RUnlock()
			if meta != nil {
				if s.Model == "" {
					s.Model = meta.Model
				}
				if s.Effort == "" {
					s.Effort = meta.Effort
				}
			}
		}
		sessions = append(sessions, s)
	}

	return sessions, nil
}

func (p *CodexProvider) ArchiveSession(ctx context.Context, sessionID string) error {
	client, err := p.appServerClient(ctx)
	if err != nil {
		return err
	}
	threadID := p.threadIDForSession(sessionID)
	if threadID == "" {
		threadID = sessionID
	}
	if err := client.ArchiveThread(ctx, threadID); err != nil {
		return err
	}
	p.dropSessionRuntime(sessionID)
	return nil
}

func (p *CodexProvider) UnarchiveSession(ctx context.Context, sessionID string) (*provider.Session, error) {
	client, err := p.appServerClient(ctx)
	if err != nil {
		return nil, err
	}
	threadID := p.threadIDForSession(sessionID)
	if threadID == "" {
		threadID = sessionID
	}
	thread, err := client.UnarchiveThread(ctx, threadID)
	if err != nil {
		return nil, err
	}
	if thread == nil {
		return &provider.Session{
			ID:         sessionID,
			ProviderID: "codex",
			ThreadID:   threadID,
			Status:     string(provider.SessionStatusStopped),
			RunnerType: "app-server",
			UpdatedAt:  time.Now(),
		}, nil
	}
	session := p.threadInfoToSession(*thread, false)
	return &session, nil
}

func (p *CodexProvider) DeleteSession(ctx context.Context, sessionID string) error {
	threadID := p.threadIDForSession(sessionID)
	if threadID == "" {
		threadID = sessionID
	}
	files, err := codexSessionRolloutFiles(threadID)
	if err != nil {
		return err
	}
	if len(files) == 0 {
		return fmt.Errorf("codex session jsonl not found for thread %s", threadID)
	}
	for _, file := range files {
		if err := os.Remove(file); err != nil && !os.IsNotExist(err) {
			return fmt.Errorf("remove %s: %w", file, err)
		}
	}
	p.dropSessionRuntime(sessionID)
	return nil
}

func (p *CodexProvider) threadInfoToSession(t ThreadInfo, archived bool) provider.Session {
	status := codexListedThreadStatus(t.Status, p.HasSession(t.ID))
	title := t.Name
	if title == "" {
		title = t.Preview
	}
	createdAt := time.Unix(t.CreatedAt, 0)
	updatedAt := time.Unix(t.UpdatedAt, 0)
	var archivedAt *time.Time
	if archived {
		// Local store records the actual archived_at timestamp; prefer that
		// when present, otherwise fall back to updated_at.
		ts := updatedAt
		if t.ArchivedAt > 0 {
			ts = time.Unix(t.ArchivedAt, 0)
		}
		archivedAt = &ts
	}
	return provider.Session{
		ID:             t.ID,
		ProviderID:     "codex",
		ThreadID:       t.ID,
		Title:          title,
		Workdir:        t.CWD,
		Status:         status,
		RunnerType:     "app-server",
		Source:         t.Source,
		Model:          t.Model,
		Effort:         t.Effort,
		ApprovalPolicy: provider.NormalizeApprovalPolicy(t.ApprovalMode),
		SandboxMode:    provider.NormalizeSandboxMode(t.SandboxPolicy),
		CreatedAt:      createdAt,
		UpdatedAt:      updatedAt,
		ArchivedAt:     archivedAt,
	}
}

func (p *CodexProvider) dropSessionRuntime(sessionID string) {
	p.metaMu.Lock()
	delete(p.meta, sessionID)
	p.metaMu.Unlock()

	p.queueMu.Lock()
	delete(p.queuedInputs, sessionID)
	delete(p.queueDraining, sessionID)
	p.queueMu.Unlock()

	p.threadIDsMu.Lock()
	delete(p.threadIDs, sessionID)
	p.threadIDsMu.Unlock()
}

func codexSessionRolloutFiles(threadID string) ([]string, error) {
	if threadID == "" {
		return nil, fmt.Errorf("thread id is required")
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, err
	}
	roots := []string{
		filepath.Join(home, ".codex", "sessions"),
		filepath.Join(home, ".codex", "archived_sessions"),
	}
	var files []string
	for _, root := range roots {
		info, err := os.Stat(root)
		if err != nil {
			if os.IsNotExist(err) {
				continue
			}
			return nil, err
		}
		if !info.IsDir() {
			continue
		}
		err = filepath.WalkDir(root, func(path string, entry os.DirEntry, walkErr error) error {
			if walkErr != nil {
				return walkErr
			}
			if entry.IsDir() {
				return nil
			}
			name := entry.Name()
			if strings.HasPrefix(name, "rollout-") &&
				strings.HasSuffix(name, threadID+".jsonl") {
				files = append(files, path)
			}
			return nil
		})
		if err != nil {
			return nil, err
		}
	}
	return files, nil
}

func codexListedThreadStatus(status ThreadStatus, active bool) string {
	// Codex thread/list can report historical, unsubscribed threads as "idle".
	// In Magent, "running" means this agent process owns an active provider
	// session for the thread and can accept input. Otherwise list status should
	// match GetSession, which treats unloaded provider threads as stopped.
	if !active {
		return string(provider.SessionStatusStopped)
	}
	_ = status
	return string(provider.SessionStatusRunning)
}

func (p *CodexProvider) Close() error {
	p.clientMu.Lock()
	defer p.clientMu.Unlock()
	if p.client != nil {
		p.unsubscribeActiveThreads(context.Background(), p.client)
		err := p.client.Close()
		p.client = nil
		return err
	}
	return nil
}

func (p *CodexProvider) unsubscribeActiveThreads(ctx context.Context, client *AppServerClient) {
	p.threadIDsMu.RLock()
	threadIDs := make(map[string]struct{}, len(p.threadIDs))
	for _, threadID := range p.threadIDs {
		if threadID != "" {
			threadIDs[threadID] = struct{}{}
		}
	}
	p.threadIDsMu.RUnlock()

	for threadID := range threadIDs {
		unsubscribeCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
		if err := client.UnsubscribeThread(unsubscribeCtx, threadID); err != nil {
			log.Warn("codex", "unsubscribe active thread %s failed: %v", threadID, err)
		}
		cancel()
	}
}
