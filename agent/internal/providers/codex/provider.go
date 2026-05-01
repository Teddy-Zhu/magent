package codex

import (
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
	"sync"
	"time"

	"github.com/magent/agent/internal/log"
	"github.com/magent/agent/internal/protocol"
	"github.com/magent/agent/internal/provider"
	"github.com/magent/agent/internal/storage"
	"github.com/magent/agent/internal/ws"
)

type CodexConfig struct {
	Binary string
}

type sessionMeta struct {
	Model          string
	Workdir        string
	ApprovalPolicy string
	SandboxMode    string
	Effort         string
}

type CodexProvider struct {
	client       *AppServerClient
	clientMu     sync.Mutex
	threadIDs    map[string]string
	threadIDsMu  sync.RWMutex
	sessions     map[string]chan provider.ProviderEvent
	sessionsMu   sync.RWMutex
	meta         map[string]*sessionMeta
	metaMu       sync.RWMutex
	approval     *ApprovalProxy
	cfg          CodexConfig
	cachedConfig *provider.ProviderConfig
	configMu     sync.RWMutex
}

func New(cfg CodexConfig, hub *ws.Hub, store *storage.SQLite) *CodexProvider {
	return &CodexProvider{
		threadIDs: make(map[string]string),
		sessions:  make(map[string]chan provider.ProviderEvent),
		meta:      make(map[string]*sessionMeta),
		approval:  NewApprovalProxy(hub, store),
		cfg:       cfg,
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
		Workdir:        req.Workdir,
		Status:         string(provider.SessionStatusRunning),
		RunnerType:     "app-server",
		Model:          req.Model,
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
	}
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
		default:
			// Channel full, drop event
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
		"threadId": threadID,
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
	log.Info("codex", "ReadThreadItems: thread=%s turns=%d items=%d cursor=%s next=%s", threadID, len(turnsPage.Turns), len(items), cursor, nextCursor)
	return &provider.ItemPage{
		SessionID: threadID,
		Cursor:    nextCursor,
		HasMore:   hasMore,
		Items:     items,
	}, nil
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
	for _, turn := range turns {
		ts := codexTurnTime(turn)
		for _, item := range turn.Items {
			events = append(events, codexItemToEvent(threadID, turn.ID, item, ts))
		}
	}
	return events
}

func codexItemToEvent(threadID, turnID string, item TurnItem, ts time.Time) provider.ProviderEvent {
	itemType := normalizeCodexItemType(item.Type)
	payload := codexItemPayload(item)
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
		if len(item.Changes) > 0 {
			payload["path"] = item.Changes[0].Path
			payload["kind"] = item.Changes[0].Kind
		}
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
	for _, turn := range turns {
		createdAt := codexTurnTime(turn)
		updatedAt := codexTurnUpdatedTime(turn)
		for _, item := range turn.Items {
			itemType := normalizeCodexItemType(item.Type)
			items = append(items, provider.SessionItem{
				Cursor:    codexItemCursor(turn.ID, item.ID),
				ItemID:    item.ID,
				TurnID:    turn.ID,
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

func codexTurnTime(turn ThreadTurn) time.Time {
	if turn.StartedAt > 0 {
		return time.Unix(turn.StartedAt, 0)
	}
	return time.Now()
}

func codexTurnUpdatedTime(turn ThreadTurn) time.Time {
	if turn.CompletedAt > 0 {
		return time.Unix(turn.CompletedAt, 0)
	}
	return codexTurnTime(turn)
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
	return content
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
		return payload
	}
	return map[string]any{
		"id":   item.ID,
		"type": item.Type,
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

	// Check if there's an active turn — steer if yes, start new turn if no
	client.activeTurnMu.Lock()
	activeTurnID := client.activeTurnIDs[threadID]
	client.activeTurnMu.Unlock()

	if activeTurnID != "" {
		log.Debug("codex", "SendInput: steering active turn=%s thread=%s", activeTurnID, threadID)
		return client.SteerTurn(ctx, threadID, codexTextInput(input.Input, input.Items))
	}

	// No active turn — start a new one
	log.Debug("codex", "SendInput: starting new turn thread=%s", threadID)
	p.metaMu.RLock()
	m := p.meta[sessionID]
	p.metaMu.RUnlock()

	model, workdir, effort := "", "", ""
	approvalPolicy, sandboxMode := string(provider.ApprovalPolicyOnRequest), string(provider.SandboxModeWorkspaceWrite)
	if m != nil {
		model = m.Model
		workdir = m.Workdir
		effort = m.Effort
		if m.ApprovalPolicy != "" {
			approvalPolicy = m.ApprovalPolicy
		}
		if m.SandboxMode != "" {
			sandboxMode = m.SandboxMode
		}
	}
	if model == "" {
		model = p.defaultModel()
		p.metaMu.Lock()
		if current := p.meta[sessionID]; current != nil {
			current.Model = model
		} else {
			p.meta[sessionID] = &sessionMeta{
				Model:          model,
				Workdir:        workdir,
				ApprovalPolicy: approvalPolicy,
				SandboxMode:    sandboxMode,
				Effort:         effort,
			}
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

	// Clean up meta
	p.metaMu.Lock()
	delete(p.meta, sessionID)
	p.metaMu.Unlock()

	if err := client.UnsubscribeThread(ctx, threadID); err != nil {
		log.Warn("codex", "unsubscribe thread %s failed: %v", threadID, err)
	}

	p.threadIDsMu.Lock()
	delete(p.threadIDs, sessionID)
	p.threadIDsMu.Unlock()

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
	client, err := p.appServerClient(ctx)
	if err != nil {
		return nil, err
	}

	return client.ListThreads(ctx, cwd, limit)
}

// ListThreads queries codex for threads and converts them to provider.Session.
// This makes codex the source of truth for session listing.
func (p *CodexProvider) ListThreads(ctx context.Context, cwd string, limit int) ([]provider.Session, error) {
	threads, err := p.ListThreadInfos(ctx, cwd, limit)
	if err != nil {
		return nil, err
	}

	var sessions []provider.Session
	for _, t := range threads {
		// Map codex thread status to our status:
		// notLoaded → "stopped" (needs resume)
		// idle → "running" (loaded, ready for turns)
		// active → "running" (has active turn)
		// systemError → "failed"
		status := provider.NormalizeSessionStatus(t.Status.Type)
		if status == "" {
			status = string(provider.SessionStatusStopped)
		}

		// Check if we have an active client for this thread
		if p.HasSession(t.ID) {
			status = string(provider.SessionStatusRunning)
		}

		title := t.Name
		if title == "" {
			title = t.Preview
		}

		createdAt := time.Unix(t.CreatedAt, 0)
		updatedAt := time.Unix(t.UpdatedAt, 0)

		sessions = append(sessions, provider.Session{
			ID:         t.ID,
			ProviderID: "codex",
			ThreadID:   t.ID,
			Title:      title,
			Status:     status,
			RunnerType: "app-server",
			CreatedAt:  createdAt,
			UpdatedAt:  updatedAt,
		})
	}

	return sessions, nil
}

func (p *CodexProvider) Close() error {
	p.clientMu.Lock()
	defer p.clientMu.Unlock()
	if p.client != nil {
		err := p.client.Close()
		p.client = nil
		return err
	}
	return nil
}
