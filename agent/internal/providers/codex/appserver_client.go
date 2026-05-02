package codex

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"
	"sync"
	"time"

	"github.com/Teddy-Zhu/magent/agent/internal/log"
	"github.com/Teddy-Zhu/magent/agent/internal/protocol"
	"github.com/Teddy-Zhu/magent/agent/internal/provider"
)

type TransportType string

const (
	TransportStdio TransportType = "stdio"
	TransportWS    TransportType = "ws"
)

type AppServerClient struct {
	transport TransportType
	conn      io.ReadWriteCloser
	process   *os.Process

	reqIDGen  *protocol.RequestIDGenerator
	pending   map[int64]*pendingRequest
	pendingMu sync.RWMutex

	events         chan provider.ProviderEvent
	serverRequests chan *protocol.JSONRPCResponse // server-initiated requests (have both id and method)
	done           chan struct{}
	closeOnce      sync.Once
	readDone       chan struct{}
	processDone    chan struct{}

	mu sync.Mutex

	activeTurnMu  sync.Mutex
	activeTurnIDs map[string]string // threadID -> turnID
}

type pendingRequest struct {
	method string
	resp   chan *protocol.JSONRPCResponse
	err    chan error
}

type stdioConn struct {
	stdin  io.WriteCloser
	stdout io.ReadCloser
}

func (c *stdioConn) Read(p []byte) (int, error)  { return c.stdout.Read(p) }
func (c *stdioConn) Write(p []byte) (int, error) { return c.stdin.Write(p) }
func (c *stdioConn) Close() error {
	c.stdin.Close()
	return c.stdout.Close()
}

func NewAppServerClient(ctx context.Context, binary string) (*AppServerClient, error) {
	return newStdioClient(ctx, binary)
}

func newStdioClient(ctx context.Context, binary string) (*AppServerClient, error) {
	cmd := exec.CommandContext(ctx, binary, "app-server")
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return nil, err
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return nil, err
	}

	if err := cmd.Start(); err != nil {
		return nil, err
	}

	// Forward codex_core stderr through our logger
	go func() {
		scanner := bufio.NewScanner(stderr)
		for scanner.Scan() {
			line := scanner.Text()
			if strings.Contains(line, "ERROR") {
				log.Error("codex_core", "%s", line)
			} else {
				log.Debug("codex_core", "%s", line)
			}
		}
	}()

	c := &AppServerClient{
		transport:      TransportStdio,
		conn:           &stdioConn{stdin: stdin, stdout: stdout},
		process:        cmd.Process,
		reqIDGen:       &protocol.RequestIDGenerator{},
		pending:        make(map[int64]*pendingRequest),
		events:         make(chan provider.ProviderEvent, 256),
		serverRequests: make(chan *protocol.JSONRPCResponse, 32),
		done:           make(chan struct{}),
		readDone:       make(chan struct{}),
		processDone:    make(chan struct{}),
		activeTurnIDs:  make(map[string]string),
	}

	go c.readLoop()
	go c.waitProcess()

	return c, nil
}

func (c *AppServerClient) readLoop() {
	defer func() {
		c.finish(fmt.Errorf("app-server connection closed"))
		close(c.readDone)
	}()

	decoder := json.NewDecoder(c.conn)
	for {
		var msg protocol.JSONRPCResponse
		if err := decoder.Decode(&msg); err != nil {
			return
		}

		if msg.ID != nil && msg.Method != "" {
			// Server-initiated request (has both id and method) — e.g. approval requests
			select {
			case c.serverRequests <- &msg:
			default:
				log.Warn("codex", "serverRequests channel full, dropping %s", msg.Method)
			}
		} else if msg.ID != nil {
			// Response to a client-initiated request
			c.pendingMu.RLock()
			if ch, ok := c.pending[*msg.ID]; ok {
				ch.resp <- &msg
			}
			c.pendingMu.RUnlock()
		} else if msg.Method != "" {
			// Notification (no id)
			c.handleNotification(&msg)
		}
	}
}

func (c *AppServerClient) Done() <-chan struct{} {
	return c.done
}

func (c *AppServerClient) waitProcess() {
	if c.process != nil {
		c.process.Wait()
	}
	close(c.processDone)
}

func (c *AppServerClient) finish(err error) {
	c.closeOnce.Do(func() {
		close(c.done)
		close(c.serverRequests)
		close(c.events)

		c.pendingMu.Lock()
		for id, pending := range c.pending {
			select {
			case pending.err <- err:
			default:
			}
			delete(c.pending, id)
		}
		c.pendingMu.Unlock()
	})
}

func (c *AppServerClient) call(ctx context.Context, method string, params any) (json.RawMessage, error) {
	id := c.reqIDGen.Next()
	req := protocol.JSONRPCRequest{
		JSONRPC: "2.0",
		Method:  method,
		ID:      &id,
		Params:  params,
	}

	ch := &pendingRequest{
		method: method,
		resp:   make(chan *protocol.JSONRPCResponse, 1),
		err:    make(chan error, 1),
	}

	c.pendingMu.Lock()
	c.pending[id] = ch
	c.pendingMu.Unlock()

	defer func() {
		c.pendingMu.Lock()
		delete(c.pending, id)
		c.pendingMu.Unlock()
	}()

	data, _ := json.Marshal(req)
	c.mu.Lock()
	_, err := fmt.Fprintf(c.conn, "%s\n", data)
	c.mu.Unlock()
	if err != nil {
		return nil, err
	}

	select {
	case resp := <-ch.resp:
		if resp.Error != nil {
			return nil, fmt.Errorf("jsonrpc error %d: %s", resp.Error.Code, resp.Error.Message)
		}
		return resp.Result, nil
	case err := <-ch.err:
		return nil, err
	case <-c.done:
		return nil, fmt.Errorf("app-server closed")
	case <-ctx.Done():
		return nil, ctx.Err()
	}
}

func (c *AppServerClient) notify(method string, params any) error {
	req := protocol.JSONRPCRequest{
		JSONRPC: "2.0",
		Method:  method,
		Params:  params,
	}
	data, _ := json.Marshal(req)
	c.mu.Lock()
	defer c.mu.Unlock()
	_, err := fmt.Fprintf(c.conn, "%s\n", data)
	return err
}

// respond sends a JSON-RPC response to a server-initiated request.
func (c *AppServerClient) respond(id int64, result any) error {
	resp := map[string]any{
		"jsonrpc": "2.0",
		"id":      id,
		"result":  result,
	}
	data, _ := json.Marshal(resp)
	c.mu.Lock()
	defer c.mu.Unlock()
	_, err := fmt.Fprintf(c.conn, "%s\n", data)
	return err
}

func (c *AppServerClient) Initialize(ctx context.Context) error {
	_, err := c.call(ctx, "initialize", map[string]any{
		"clientInfo": map[string]any{
			"name":    "magent",
			"title":   "Magent Agent",
			"version": "0.1.0",
		},
		"capabilities": map[string]any{
			"experimentalApi":           true,
			"optOutNotificationMethods": []string{},
		},
	})
	if err != nil {
		return err
	}
	return c.notify("initialized", map[string]any{})
}

func (c *AppServerClient) StartThread(ctx context.Context, model, cwd, approvalPolicy, sandbox string) (string, error) {
	wireApprovalPolicy := codexApprovalPolicy(approvalPolicy)
	wireSandbox := codexThreadSandboxMode(sandbox)
	log.Debug("codex", "thread/start model=%s cwd=%s approval=%s sandbox=%s", model, cwd, wireApprovalPolicy, wireSandbox)
	result, err := c.call(ctx, "thread/start", map[string]any{
		"model":                  model,
		"cwd":                    cwd,
		"approvalPolicy":         wireApprovalPolicy,
		"sandbox":                wireSandbox,
		"persistExtendedHistory": true,
	})
	if err != nil {
		return "", err
	}
	log.Debug("codex", "thread/start raw response: %s", string(result))
	var resp struct {
		Thread struct {
			ID string `json:"id"`
		} `json:"thread"`
	}
	if err := json.Unmarshal(result, &resp); err != nil {
		log.Error("codex", "thread/start unmarshal error: %v raw=%s", err, string(result))
		return "", fmt.Errorf("thread/start unmarshal: %w", err)
	}
	if resp.Thread.ID == "" {
		log.Error("codex", "thread/start returned empty thread ID raw=%s", string(result))
		return "", fmt.Errorf("thread/start: empty thread ID")
	}
	log.Info("codex", "thread started id=%s", resp.Thread.ID)
	return resp.Thread.ID, nil
}

func (c *AppServerClient) ForkThread(ctx context.Context, threadID string) (string, error) {
	if threadID == "" {
		return "", fmt.Errorf("thread/fork: threadID is required")
	}
	log.Debug("codex", "thread/fork thread=%s", threadID)
	result, err := c.call(ctx, "thread/fork", map[string]any{
		"threadId":               threadID,
		"persistExtendedHistory": true,
	})
	if err != nil {
		return "", err
	}
	log.Debug("codex", "thread/fork raw response: %s", string(result))
	var resp struct {
		Thread struct {
			ID string `json:"id"`
		} `json:"thread"`
	}
	if err := json.Unmarshal(result, &resp); err != nil {
		log.Error("codex", "thread/fork unmarshal error: %v raw=%s", err, string(result))
		return "", fmt.Errorf("thread/fork unmarshal: %w", err)
	}
	if resp.Thread.ID == "" {
		log.Error("codex", "thread/fork returned empty thread ID raw=%s", string(result))
		return "", fmt.Errorf("thread/fork: empty thread ID")
	}
	log.Info("codex", "thread forked source=%s new=%s", threadID, resp.Thread.ID)
	return resp.Thread.ID, nil
}

func (c *AppServerClient) CompactThread(ctx context.Context, threadID string) error {
	if threadID == "" {
		return fmt.Errorf("thread/compact/start: threadID is required")
	}
	log.Debug("codex", "thread/compact/start thread=%s", threadID)
	result, err := c.call(ctx, "thread/compact/start", map[string]any{
		"threadId": threadID,
	})
	if err != nil {
		return err
	}
	log.Debug("codex", "thread/compact/start response: %s", string(result))
	return nil
}

func (c *AppServerClient) RollbackThread(ctx context.Context, threadID string, numTurns int) error {
	if threadID == "" {
		return fmt.Errorf("thread/rollback: threadID is required")
	}
	if numTurns <= 0 {
		numTurns = 1
	}
	log.Debug("codex", "thread/rollback thread=%s turns=%d", threadID, numTurns)
	result, err := c.call(ctx, "thread/rollback", map[string]any{
		"threadId": threadID,
		"numTurns": numTurns,
	})
	if err != nil {
		return err
	}
	log.Debug("codex", "thread/rollback response: %s", string(result))
	return nil
}

func (c *AppServerClient) StartTurn(ctx context.Context, threadID string, input []provider.InputItem, cwd, approvalPolicy, sandboxPolicy, model, effort string) (string, error) {
	params := map[string]any{
		"threadId":       threadID,
		"input":          codexInputItems(input),
		"cwd":            cwd,
		"approvalPolicy": codexApprovalPolicy(approvalPolicy),
		"sandboxPolicy":  sandboxPolicyObject(sandboxPolicy, cwd),
		"model":          model,
	}
	if effort != "" {
		params["effort"] = effort
	}
	log.Debug("codex", "turn/start thread=%s model=%s effort=%s sandbox=%v", threadID, model, effort, params["sandboxPolicy"])
	result, err := c.call(ctx, "turn/start", params)
	if err != nil {
		log.Error("codex", "turn/start error: %v", err)
		return "", err
	}
	log.Debug("codex", "turn/start response: %s", string(result))

	// Parse turnId from response: { "turn": { "id": "turn_456", ... } }
	var resp struct {
		Turn struct {
			ID string `json:"id"`
		} `json:"turn"`
	}
	if err := json.Unmarshal(result, &resp); err == nil && resp.Turn.ID != "" {
		c.activeTurnMu.Lock()
		c.activeTurnIDs[threadID] = resp.Turn.ID
		c.activeTurnMu.Unlock()
		log.Debug("codex", "active turn thread=%s turn=%s", threadID, resp.Turn.ID)
		return resp.Turn.ID, nil
	}
	return "", nil
}

func (c *AppServerClient) SteerTurn(ctx context.Context, threadID string, input []provider.InputItem) error {
	c.activeTurnMu.Lock()
	turnID := c.activeTurnIDs[threadID]
	c.activeTurnMu.Unlock()

	params := map[string]any{
		"threadId": threadID,
		"input":    codexInputItems(input),
	}
	if turnID != "" {
		params["expectedTurnId"] = turnID
	}
	log.Debug("codex", "turn/steer thread=%s turn=%s", threadID, turnID)
	_, err := c.call(ctx, "turn/steer", params)
	return err
}

func (c *AppServerClient) InterruptTurn(ctx context.Context, threadID string) error {
	c.activeTurnMu.Lock()
	turnID := c.activeTurnIDs[threadID]
	c.activeTurnMu.Unlock()

	params := map[string]any{
		"threadId": threadID,
	}
	if turnID != "" {
		params["turnId"] = turnID
	}
	log.Debug("codex", "turn/interrupt thread=%s turn=%s", threadID, turnID)
	_, err := c.call(ctx, "turn/interrupt", params)
	return err
}

func (c *AppServerClient) ListModels(ctx context.Context) ([]ModelInfo, error) {
	result, err := c.call(ctx, "model/list", map[string]any{})
	if err != nil {
		return nil, err
	}
	log.Debug("codex", "model/list raw: %s", string(result))
	var resp struct {
		Data []ModelInfo `json:"data"`
	}
	if err := json.Unmarshal(result, &resp); err != nil {
		log.Error("codex", "model/list unmarshal error: %v", err)
	}
	return resp.Data, nil
}

type ThreadStatus struct {
	Type        string   `json:"type"`
	ActiveFlags []string `json:"activeFlags,omitempty"`
}

func (s *ThreadStatus) UnmarshalJSON(data []byte) error {
	if strings.TrimSpace(string(data)) == "null" {
		s.Type = ""
		s.ActiveFlags = nil
		return nil
	}

	var status string
	if err := json.Unmarshal(data, &status); err == nil {
		s.Type = status
		return nil
	}

	var decoded struct {
		Type        string   `json:"type"`
		ActiveFlags []string `json:"activeFlags"`
	}
	if err := json.Unmarshal(data, &decoded); err != nil {
		return err
	}
	s.Type = decoded.Type
	s.ActiveFlags = decoded.ActiveFlags
	return nil
}

type ThreadInfo struct {
	ID            string       `json:"id"`
	Preview       string       `json:"preview"`
	Name          string       `json:"name"`
	Ephemeral     bool         `json:"ephemeral"`
	ModelProvider string       `json:"modelProvider"`
	CWD           string       `json:"cwd"`
	Status        ThreadStatus `json:"status"`
	CreatedAt     int64        `json:"createdAt"`
	UpdatedAt     int64        `json:"updatedAt"`
}

type ListThreadsOptions struct {
	CWD      string
	Limit    int
	Archived bool
}

var codexThreadListSourceKinds = []string{"cli", "vscode", "appServer"}

func (c *AppServerClient) ListThreads(ctx context.Context, cwd string, limit int) ([]ThreadInfo, error) {
	return c.ListThreadsWithOptions(ctx, ListThreadsOptions{
		CWD:   cwd,
		Limit: limit,
	})
}

func (c *AppServerClient) ListThreadsWithOptions(ctx context.Context, opts ListThreadsOptions) ([]ThreadInfo, error) {
	limit := opts.Limit
	if limit <= 0 {
		limit = 100
	}
	params := map[string]any{
		"limit":       limit,
		"sortKey":     "updated_at",
		"archived":    opts.Archived,
		"sourceKinds": codexThreadListSourceKinds,
	}
	if opts.CWD != "" {
		params["cwd"] = opts.CWD
	}
	result, err := c.call(ctx, "thread/list", params)
	if err != nil {
		return nil, err
	}
	log.Debug("codex", "thread/list raw: %s", string(result))
	var resp struct {
		Data []ThreadInfo `json:"data"`
	}
	if err := json.Unmarshal(result, &resp); err != nil {
		log.Error("codex", "thread/list unmarshal error: %v", err)
	}
	return resp.Data, nil
}

func (c *AppServerClient) ArchiveThread(ctx context.Context, threadID string) error {
	_, err := c.call(ctx, "thread/archive", map[string]any{"threadId": threadID})
	return err
}

func (c *AppServerClient) UnarchiveThread(ctx context.Context, threadID string) (*ThreadInfo, error) {
	result, err := c.call(ctx, "thread/unarchive", map[string]any{"threadId": threadID})
	if err != nil {
		return nil, err
	}
	var resp struct {
		Thread ThreadInfo `json:"thread"`
	}
	if err := json.Unmarshal(result, &resp); err != nil {
		return nil, err
	}
	if resp.Thread.ID == "" {
		return nil, nil
	}
	return &resp.Thread, nil
}

type ThreadTurn struct {
	ID          string     `json:"id"`
	Items       []TurnItem `json:"items"`
	Status      string     `json:"status"`
	Error       any        `json:"error"`
	StartedAt   int64      `json:"startedAt"`
	CompletedAt int64      `json:"completedAt"`
}

type TurnItem struct {
	Type             string `json:"type"`
	ID               string `json:"id"`
	Text             string `json:"text,omitempty"`
	Phase            string `json:"phase,omitempty"`
	Status           string `json:"status,omitempty"`
	Summary          any    `json:"summary,omitempty"`
	Command          any    `json:"command,omitempty"`
	CWD              string `json:"cwd,omitempty"`
	AggregatedOutput string `json:"aggregatedOutput,omitempty"`
	ExitCode         *int   `json:"exitCode,omitempty"`
	Path             string `json:"path,omitempty"`
	Tool             string `json:"tool,omitempty"`
	Result           any    `json:"result,omitempty"`
	Error            any    `json:"error,omitempty"`
	Content          []struct {
		Type string `json:"type"`
		Text string `json:"text"`
	} `json:"content,omitempty"`
	Changes []TurnItemChange `json:"changes,omitempty"`
	Raw     map[string]any   `json:"-"`
}

type TurnItemChange struct {
	Path string     `json:"path"`
	Kind ChangeKind `json:"kind"`
	Diff string     `json:"diff"`
}

type ChangeKind struct {
	Type     string  `json:"type,omitempty"`
	MovePath *string `json:"move_path,omitempty"`
	Raw      any     `json:"-"`
}

func (k *ChangeKind) UnmarshalJSON(data []byte) error {
	var asString string
	if err := json.Unmarshal(data, &asString); err == nil {
		k.Type = asString
		k.Raw = asString
		return nil
	}
	var asObject struct {
		Type     string  `json:"type"`
		MovePath *string `json:"move_path"`
	}
	if err := json.Unmarshal(data, &asObject); err != nil {
		return err
	}
	k.Type = asObject.Type
	k.MovePath = asObject.MovePath
	var raw map[string]any
	if err := json.Unmarshal(data, &raw); err == nil {
		k.Raw = raw
	}
	return nil
}

func (i *TurnItem) UnmarshalJSON(data []byte) error {
	type alias TurnItem
	var decoded alias
	if err := json.Unmarshal(data, &decoded); err != nil {
		return err
	}
	var raw map[string]any
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	*i = TurnItem(decoded)
	i.Raw = raw
	return nil
}

type ThreadTurnsPage struct {
	Turns           []ThreadTurn
	NextCursor      string
	BackwardsCursor string
}

// ListThreadTurns pages through stored thread history without resuming the thread.
func (c *AppServerClient) ListThreadTurns(ctx context.Context, threadID, cursor string, limit int, sortDirection string) (*ThreadTurnsPage, error) {
	if limit <= 0 {
		limit = 200
	}
	if sortDirection == "" {
		sortDirection = "asc"
	}
	params := map[string]any{
		"threadId":      threadID,
		"limit":         limit,
		"sortDirection": sortDirection,
	}
	if cursor != "" {
		params["cursor"] = cursor
	}
	result, err := c.call(ctx, "thread/turns/list", params)
	if err != nil {
		return nil, err
	}
	log.Debug("codex", "thread/turns/list raw: %s", string(result))
	var resp struct {
		Data            []ThreadTurn `json:"data"`
		NextCursor      *string      `json:"nextCursor"`
		BackwardsCursor *string      `json:"backwardsCursor"`
	}
	if err := json.Unmarshal(result, &resp); err != nil {
		log.Error("codex", "thread/turns/list unmarshal error: %v", err)
		return nil, err
	}
	page := &ThreadTurnsPage{Turns: resp.Data}
	if resp.NextCursor != nil {
		page.NextCursor = *resp.NextCursor
	}
	if resp.BackwardsCursor != nil {
		page.BackwardsCursor = *resp.BackwardsCursor
	}
	return page, nil
}

func (c *AppServerClient) ReadConfig(ctx context.Context) (json.RawMessage, error) {
	return c.call(ctx, "config/read", map[string]any{})
}

func (c *AppServerClient) ReadConfigRequirements(ctx context.Context) (json.RawMessage, error) {
	return c.call(ctx, "configRequirements/read", map[string]any{})
}

func (c *AppServerClient) ListMCPServers(ctx context.Context) (json.RawMessage, error) {
	return c.call(ctx, "mcpServerStatus/list", map[string]any{})
}

func (c *AppServerClient) ListSkills(ctx context.Context) (json.RawMessage, error) {
	return c.call(ctx, "skills/list", map[string]any{})
}

func (c *AppServerClient) Events() <-chan provider.ProviderEvent {
	return c.events
}

// ServerRequests returns the channel for server-initiated JSON-RPC requests (e.g. approval requests).
func (c *AppServerClient) ServerRequests() <-chan *protocol.JSONRPCResponse {
	return c.serverRequests
}

// UnsubscribeThread tells codex_core we're done with a thread.
// Per the app-server protocol, this must be called before closing the connection
// to allow codex_core to properly persist rollout data.
func (c *AppServerClient) UnsubscribeThread(ctx context.Context, threadID string) error {
	log.Debug("codex", "unsubscribing thread %s", threadID)
	result, err := c.call(ctx, "thread/unsubscribe", map[string]any{
		"threadId": threadID,
	})
	if err != nil {
		log.Warn("codex", "thread/unsubscribe error: %v", err)
		return err
	}
	log.Debug("codex", "thread/unsubscribe response: %s", string(result))
	return nil
}

func (c *AppServerClient) Close() error {
	log.Debug("codex", "closing appserver client")
	// Close stdin first to signal EOF, giving codex_core time to save state
	c.conn.Close()
	select {
	case <-c.readDone:
	case <-time.After(2 * time.Second):
		log.Warn("codex", "read loop did not exit in time")
	}
	if c.process != nil {
		// Wait briefly for graceful exit, then force kill
		select {
		case <-c.processDone:
			log.Debug("codex", "process exited gracefully")
		case <-time.After(2 * time.Second):
			log.Warn("codex", "process did not exit in time, force killing")
			c.process.Kill()
			<-c.processDone
		}
	}
	return nil
}

type ReasoningEffortInfo struct {
	ReasoningEffort string `json:"reasoningEffort"`
	Description     string `json:"description"`
}

type ModelInfo struct {
	ID                        string                `json:"id"`
	DisplayName               string                `json:"displayName"`
	SupportedReasoningEfforts []ReasoningEffortInfo `json:"supportedReasoningEfforts"`
	InputModalities           []string              `json:"inputModalities"`
}
