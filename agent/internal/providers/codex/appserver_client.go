package codex

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"sync"

	"github.com/magent/agent/internal/log"
	"github.com/magent/agent/internal/protocol"
	"github.com/magent/agent/internal/provider"
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

	events chan provider.ProviderEvent
	done   chan struct{}
	closeOnce sync.Once

	mu        sync.Mutex
	threadIDs map[string]string
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
func (c *stdioConn) Write(p []byte) (int, error)  { return c.stdin.Write(p) }
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
	cmd.Stderr = os.Stderr

	if err := cmd.Start(); err != nil {
		return nil, err
	}

	c := &AppServerClient{
		transport: TransportStdio,
		conn:      &stdioConn{stdin: stdin, stdout: stdout},
		process:   cmd.Process,
		reqIDGen:  &protocol.RequestIDGenerator{},
		pending:   make(map[int64]*pendingRequest),
		events:    make(chan provider.ProviderEvent, 256),
		done:      make(chan struct{}),
		threadIDs: make(map[string]string),
	}

	go c.readLoop()
	go c.waitProcess()

	return c, nil
}

func (c *AppServerClient) readLoop() {
	decoder := json.NewDecoder(c.conn)
	for {
		var msg protocol.JSONRPCResponse
		if err := decoder.Decode(&msg); err != nil {
			c.closeOnce.Do(func() { close(c.done) })
			return
		}

		if msg.ID != nil {
			c.pendingMu.RLock()
			if ch, ok := c.pending[*msg.ID]; ok {
				ch.resp <- &msg
			}
			c.pendingMu.RUnlock()
		} else if msg.Method != "" {
			c.handleNotification(&msg)
		}
	}
}

func (c *AppServerClient) waitProcess() {
	if c.process != nil {
		c.process.Wait()
	}
	c.closeOnce.Do(func() { close(c.done) })
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

func (c *AppServerClient) Initialize(ctx context.Context) error {
	_, err := c.call(ctx, "initialize", map[string]any{
		"clientInfo": map[string]any{
			"name":    "magent",
			"title":   "Magent Agent",
			"version": "0.1.0",
		},
		"capabilities": map[string]any{
			"experimentalApi":          true,
			"optOutNotificationMethods": []string{},
		},
	})
	if err != nil {
		return err
	}
	return c.notify("initialized", nil)
}

func (c *AppServerClient) StartThread(ctx context.Context, model, cwd, approvalPolicy, sandbox string) (string, error) {
	result, err := c.call(ctx, "thread/start", map[string]any{
		"model":          model,
		"cwd":            cwd,
		"approvalPolicy": approvalPolicy,
		"sandbox":        sandbox,
	})
	if err != nil {
		return "", err
	}
	var resp struct {
		Thread struct {
			ID string `json:"id"`
		} `json:"thread"`
	}
	json.Unmarshal(result, &resp)
	c.mu.Lock()
	c.threadIDs[resp.Thread.ID] = resp.Thread.ID
	c.mu.Unlock()
	return resp.Thread.ID, nil
}

func sandboxPolicyObject(mode, cwd string) map[string]any {
	switch mode {
	case "read-only":
		return map[string]any{"type": "readOnly"}
	case "danger-full-access":
		return map[string]any{"type": "dangerFullAccess"}
	default: // "workspace-write"
		return map[string]any{"type": "workspaceWrite", "writableRoots": []string{cwd}}
	}
}

func (c *AppServerClient) StartTurn(ctx context.Context, threadID, input, cwd, approvalPolicy, sandboxPolicy, model, effort string) error {
	params := map[string]any{
		"threadId":       threadID,
		"input":          []map[string]any{{"type": "text", "text": input}},
		"cwd":            cwd,
		"approvalPolicy": approvalPolicy,
		"sandboxPolicy":  sandboxPolicyObject(sandboxPolicy, cwd),
		"model":          model,
	}
	if effort != "" {
		params["effort"] = effort
	}
	_, err := c.call(ctx, "turn/start", params)
	return err
}

func (c *AppServerClient) SteerTurn(ctx context.Context, threadID, input string) error {
	_, err := c.call(ctx, "turn/steer", map[string]any{
		"threadId": threadID,
		"input":    []map[string]any{{"type": "text", "text": input}},
	})
	return err
}

func (c *AppServerClient) InterruptTurn(ctx context.Context, threadID string) error {
	_, err := c.call(ctx, "turn/interrupt", map[string]any{
		"threadId": threadID,
	})
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

func (c *AppServerClient) ReadConfig(ctx context.Context) (json.RawMessage, error) {
	return c.call(ctx, "config/read", nil)
}

func (c *AppServerClient) ReadConfigRequirements(ctx context.Context) (json.RawMessage, error) {
	return c.call(ctx, "configRequirements/read", nil)
}

func (c *AppServerClient) ListMCPServers(ctx context.Context) (json.RawMessage, error) {
	return c.call(ctx, "mcpServerStatus/list", nil)
}

func (c *AppServerClient) ListSkills(ctx context.Context) (json.RawMessage, error) {
	return c.call(ctx, "skills/list", nil)
}

func (c *AppServerClient) Events() <-chan provider.ProviderEvent {
	return c.events
}

func (c *AppServerClient) Close() error {
	c.closeOnce.Do(func() { close(c.done) })
	if c.process != nil {
		c.process.Kill()
	}
	return c.conn.Close()
}

type ReasoningEffortInfo struct {
	ReasoningEffort string `json:"reasoningEffort"`
	Description     string `json:"description"`
}

type ModelInfo struct {
	ID                      string               `json:"id"`
	DisplayName             string               `json:"displayName"`
	SupportedReasoningEfforts []ReasoningEffortInfo `json:"supportedReasoningEfforts"`
	InputModalities         []string             `json:"inputModalities"`
}
