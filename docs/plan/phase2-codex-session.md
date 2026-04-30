# Phase 2：Codex Provider + 会话系统（3 周）

## 目标

实现 Codex Provider（App Server 协议优先）、完整的会话生命周期、实时输出、审批代理、断线恢复。

## 前置条件

Phase 1 完成（HTTP/WS Server、SQLite、Project CRUD）。

## Day 0：协议验证（编码前）

Day 0 不做编码，先验证 Codex App Server 实际协议。协议细节见 `docs/plan/codex-appserver.md`。

验证清单：
- [ ] 安装最新版 Codex CLI，运行 `codex app-server --help` 确认 stdio 模式参数
- [ ] stdio 模式发送 `initialize`（含 `clientInfo` + `capabilities`），确认响应含 `userAgent`, `platformFamily`, `platformOs`
- [ ] 发送 `initialized` 通知，确认后续请求不再返回 `"Not initialized"`
- [ ] `thread/start` 创建线程，确认响应含 `thread.id`, `preview`, `ephemeral`, `modelProvider`, `createdAt`
- [ ] `turn/start` 发送 `{ "type": "text", "text": "hello" }` 输入，确认 `turn/started` + `item/started` + `item/agentMessage/delta` + `item/completed` + `turn/completed` 通知链
- [ ] `model/list` 确认返回 `data` 数组，每项含 `id`, `displayName`, `supportedReasoningEfforts`, `inputModalities`
- [ ] `config/read` + `configRequirements/read` 确认配置和约束返回格式
- [ ] 触发需审批的操作（如写文件），确认 `item/commandExecution/requestApproval` 或 `item/fileChange/requestApproval` 通知格式，以及决策值（`accept`, `acceptForSession`, `decline`, `cancel`）
- [ ] `mcpServerStatus/list` 确认 MCP 服务器列表和工具可用性
- [ ] `skills/list` 确认技能列表返回格式

如果发现协议差异，更新 `docs/plan/codex-appserver.md` 后再开始编码。

## 产出

- 可通过 App Server 协议驱动 Codex
- 手机可创建/查看/控制 AI 会话
- 实时 AI 输出流
- 审批请求转发到手机
- 断线后可恢复会话

---

## 一、Provider 接口定义

### 1.1 核心接口

```go
// internal/provider/provider.go

type Provider interface {
    Name() string
    Detect(ctx context.Context) (*ProviderInfo, error)
    CreateSession(ctx context.Context, req CreateSessionRequest) (*Session, error)
    ResumeSession(ctx context.Context, sessionID, threadID string) error
    ForkSession(ctx context.Context, sessionID, threadID string) (string, error)
    SendInput(ctx context.Context, sessionID, input string) error
    InterruptSession(ctx context.Context, sessionID string) error
    StopSession(ctx context.Context, sessionID string) error
    CompactSession(ctx context.Context, sessionID string) error
    RollbackSession(ctx context.Context, sessionID string, turns int) error
    Subscribe(sessionID string) <-chan ProviderEvent // per-session 事件订阅
    Unsubscribe(sessionID string)                    // 取消订阅
    Capabilities() ProviderCapabilities
    Close() error
}

type CreateSessionRequest struct {
    ProjectID      string            `json:"project_id"`
    Workdir        string            `json:"workdir"`
    Model          string            `json:"model"`
    ApprovalPolicy string            `json:"approval_policy"`
    SandboxMode    string            `json:"sandbox_mode"`
    Prompt         string            `json:"prompt"`
    Config         map[string]any    `json:"config,omitempty"`
}

type ProviderEvent struct {
    SessionID string    `json:"session_id"`
    Type      string    `json:"type"`
    Payload   any       `json:"payload"`
    Timestamp time.Time `json:"timestamp"`
}

type ProviderInfo struct {
    Name         string               `json:"name"`
    Version      string               `json:"version"`
    Binary       string               `json:"binary"`
    Status       string               `json:"status"` // "available" | "unavailable"
    RunMode      string               `json:"run_mode"` // "app-server-stdio" | "app-server-ws" | "pty"
    Error        string               `json:"error,omitempty"`
    Capabilities ProviderCapabilities `json:"capabilities"`
}

type ProviderCapabilities struct {
    Protocol           string `json:"protocol"`
    SupportsResume     bool   `json:"supports_resume"`
    SupportsFork       bool   `json:"supports_fork"`
    SupportsSteer      bool   `json:"supports_steer"`
    SupportsInterrupt  bool   `json:"supports_interrupt"`
    SupportsCompact    bool   `json:"supports_compact"`
    SupportsRollback   bool   `json:"supports_rollback"`
    SupportsApproval   bool   `json:"supports_approval"`
    SupportsFileSystem bool   `json:"supports_file_system"`
    SupportsMCP        bool   `json:"supports_mcp"`
    SupportsCommand    bool   `json:"supports_command"`
    SupportsModelSwitch    bool `json:"supports_model_switch"`
    SupportsSandboxConfig  bool `json:"supports_sandbox_config"`
    SupportsApprovalPolicy bool `json:"supports_approval_policy"`
    StructuredOutput   bool   `json:"structured_output"`
    StreamingOutput    bool   `json:"streaming_output"`
    SupportsPTY        bool   `json:"supports_pty"`
}
```

### 1.2 Provider Registry

```go
// internal/provider/registry.go

type Registry struct {
    providers map[string]Provider
    mu        sync.RWMutex
}

func NewRegistry() *Registry {
    return &Registry{
        providers: make(map[string]Provider),
    }
}

func (r *Registry) Register(name string, p Provider) {
    r.mu.Lock()
    defer r.mu.Unlock()
    r.providers[name] = p
}

func (r *Registry) Get(name string) (Provider, error) {
    r.mu.RLock()
    defer r.mu.RUnlock()
    p, ok := r.providers[name]
    if !ok {
        return nil, fmt.Errorf("provider %q not found", name)
    }
    return p, nil
}

func (r *Registry) List() []ProviderInfo {
    r.mu.RLock()
    defer r.mu.RUnlock()
    var infos []ProviderInfo
    for _, p := range r.providers {
        info, err := p.Detect(context.Background())
        if err != nil {
            infos = append(infos, ProviderInfo{
                Name:   p.Name(),
                Status: "unavailable",
                Error:  err.Error(),
            })
        } else {
            infos = append(infos, *info)
        }
    }
    return infos
}
```

---

## 二、Codex App Server 客户端

### 2.1 JSON-RPC 2.0 协议实现

```go
// internal/protocol/jsonrpc.go

type JSONRPCRequest struct {
    JSONRPC string `json:"jsonrpc"`
    Method  string `json:"method"`
    ID      *int64 `json:"id,omitempty"`
    Params  any    `json:"params,omitempty"`
}

type JSONRPCResponse struct {
    JSONRPC string          `json:"jsonrpc"`
    ID      *int64          `json:"id,omitempty"`
    Result  json.RawMessage `json:"result,omitempty"`
    Error   *JSONRPCError   `json:"error,omitempty"`
    Method  string          `json:"method,omitempty"` // 通知时使用
    Params  json.RawMessage `json:"params,omitempty"` // 通知时使用
}

type JSONRPCError struct {
    Code    int    `json:"code"`
    Message string `json:"message"`
    Data    any    `json:"data,omitempty"`
}

// 请求/响应 ID 管理
type RequestIDGenerator struct {
    counter int64
    mu      sync.Mutex
}

func (g *RequestIDGenerator) Next() int64 {
    g.mu.Lock()
    defer g.mu.Unlock()
    g.counter++
    return g.counter
}
```

### 2.2 App Server 客户端

```go
// internal/codex/appserver_client.go

type AppServerClient struct {
    transport  TransportType // "stdio" | "ws"
    conn       io.ReadWriteCloser  // stdio: stdin/stdout pipe
    wsConn     *websocket.Conn     // ws: websocket connection
    process    *os.Process

    reqIDGen   *RequestIDGenerator
    pending    map[int64]*pendingRequest
    pendingMu  sync.RWMutex

    events     chan ProviderEvent
    done       chan struct{}

    mu         sync.Mutex
    threadIDs  map[string]string // sessionID → threadID

    secret     []byte  // ws auth secret
}

type pendingRequest struct {
    method string
    resp   chan *JSONRPCResponse
    err    chan error
}

// 创建客户端（自动选择传输方式）
func NewAppServerClient(ctx context.Context, cfg CodexConfig) (*AppServerClient, error) {
    // 检测 Codex 版本，决定传输方式
    // 优先 stdio（更安全）
    return newStdioClient(ctx, cfg)
}

// stdio 模式
func newStdioClient(ctx context.Context, cfg CodexConfig) (*AppServerClient, error) {
    args := []string{"app-server"}
    args = append(args, cfg.ToAppServerArgs()...)

    cmd := exec.CommandContext(ctx, cfg.Binary, args...)
    stdin, _ := cmd.StdinPipe()
    stdout, _ := cmd.StdoutPipe()
    cmd.Stderr = os.Stderr  // 或重定向到日志

    if err := cmd.Start(); err != nil {
        return nil, err
    }

    c := &AppServerClient{
        transport: "stdio",
        conn:      &stdioConn{stdin: stdin, stdout: stdout},
        process:   cmd.Process,
        reqIDGen:  &RequestIDGenerator{},
        pending:   make(map[int64]*pendingRequest),
        events:    make(chan ProviderEvent, 256),
        done:      make(chan struct{}),
        threadIDs: make(map[string]string),
    }

    go c.readLoop()
    go c.waitProcess()

    return c, nil
}

// WebSocket 模式
func newWSClient(ctx context.Context, cfg CodexConfig) (*AppServerClient, error) {
    // 启动 codex app-server --listen ws://127.0.0.1:{port}
    // 生成 shared secret
    // 连接 ws
    // ...
}

// 读取循环
func (c *AppServerClient) readLoop() {
    decoder := json.NewDecoder(c.conn)
    for {
        var msg JSONRPCResponse
        if err := decoder.Decode(&msg); err != nil {
            close(c.done)
            return
        }

        if msg.ID != nil {
            // 这是对某个请求的响应
            c.pendingMu.RLock()
            if ch, ok := c.pending[*msg.ID]; ok {
                ch.resp <- &msg
            }
            c.pendingMu.RUnlock()
        } else if msg.Method != "" {
            // 这是 Codex 推送的通知/事件
            c.handleNotification(&msg)
        }
    }
}

// 发送请求并等待响应
func (c *AppServerClient) call(ctx context.Context, method string, params any) (json.RawMessage, error) {
    id := c.reqIDGen.Next()
    req := JSONRPCRequest{
        JSONRPC: "2.0",
        Method:  method,
        ID:      &id,
        Params:  params,
    }

    ch := &pendingRequest{
        method: method,
        resp:   make(chan *JSONRPCResponse, 1),
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

    // 发送
    data, _ := json.Marshal(req)
    c.mu.Lock()
    _, err := fmt.Fprintf(c.conn, "%s\n", data)
    c.mu.Unlock()
    if err != nil {
        return nil, err
    }

    // 等待响应
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

// 发送通知（无 ID，不等待响应）
func (c *AppServerClient) notify(method string, params any) error {
    req := JSONRPCRequest{
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
```

### 2.3 核心 RPC 方法

```go
// internal/codex/appserver_client.go（续）

// 初始化握手
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

// 创建线程
func (c *AppServerClient) StartThread(ctx context.Context, opts ThreadOpts) (string, error) {
    result, err := c.call(ctx, "thread/start", map[string]any{
        "model":          opts.Model,
        "cwd":            opts.Cwd,
        "approvalPolicy": opts.ApprovalPolicy,
        "sandbox":        opts.Sandbox,
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
    return resp.Thread.ID, nil
}

// 恢复线程
func (c *AppServerClient) ResumeThread(ctx context.Context, threadID string) error {
    _, err := c.call(ctx, "thread/resume", map[string]any{
        "threadId": threadID,
    })
    return err
}

// 分叉线程
func (c *AppServerClient) ForkThread(ctx context.Context, threadID string) (string, error) {
    result, err := c.call(ctx, "thread/fork", map[string]any{
        "threadId": threadID,
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
    return resp.Thread.ID, nil
}

// 开始 Turn
func (c *AppServerClient) StartTurn(ctx context.Context, opts TurnOpts) error {
    _, err := c.call(ctx, "turn/start", map[string]any{
        "threadId":       opts.ThreadID,
        "input":          []map[string]any{{"type": "text", "text": opts.Input}},
        "cwd":            opts.Cwd,
        "approvalPolicy": opts.ApprovalPolicy,
        "sandboxPolicy":  opts.SandboxPolicy,
        "model":          opts.Model,
        "effort":         opts.Effort,
    })
    return err
}

// 追加输入（Turn 进行中时）
func (c *AppServerClient) SteerTurn(ctx context.Context, threadID, input string) error {
    _, err := c.call(ctx, "turn/steer", map[string]any{
        "threadId": threadID,
        "input":    []map[string]any{{"type": "text", "text": input}},
    })
    return err
}

// 中断 Turn
func (c *AppServerClient) InterruptTurn(ctx context.Context, threadID string) error {
    _, err := c.call(ctx, "turn/interrupt", map[string]any{
        "threadId": threadID,
    })
    return err
}

// 列出线程
func (c *AppServerClient) ListThreads(ctx context.Context) ([]ThreadInfo, error) {
    result, err := c.call(ctx, "thread/list", nil)
    // ...
}

// 列出模型
func (c *AppServerClient) ListModels(ctx context.Context) ([]ModelInfo, error) {
    result, err := c.call(ctx, "model/list", nil)
    // ...
}

// 压缩历史
func (c *AppServerClient) CompactThread(ctx context.Context, threadID string) error {
    _, err := c.call(ctx, "thread/compact/start", map[string]any{
        "threadId": threadID,
    })
    return err
}

// 回滚
func (c *AppServerClient) RollbackThread(ctx context.Context, threadID string, turns int) error {
    _, err := c.call(ctx, "thread/rollback", map[string]any{
        "threadId": threadID,
        "turns":    turns,
    })
    return err
}

// 读取配置
func (c *AppServerClient) ReadConfig(ctx context.Context) (json.RawMessage, error) {
    return c.call(ctx, "config/read", nil)
}

// 写入配置
func (c *AppServerClient) WriteConfigValue(ctx context.Context, key, value string) error {
    _, err := c.call(ctx, "config/value/write", map[string]any{
        "key":   key,
        "value": value,
    })
    return err
}

// 沙箱内执行命令
func (c *AppServerClient) ExecCommand(ctx context.Context, cmd string) (*CommandResult, error) {
    result, err := c.call(ctx, "command/exec", map[string]any{
        "command": cmd,
    })
    // ...
}

// 读取文件
func (c *AppServerClient) ReadFile(ctx context.Context, path string) ([]byte, error) {
    result, err := c.call(ctx, "fs/readFile", map[string]any{
        "path": path,
    })
    // ...
}

// 写入文件
func (c *AppServerClient) WriteFile(ctx context.Context, path string, content []byte) error {
    _, err := c.call(ctx, "fs/writeFile", map[string]any{
        "path":    path,
        "content": base64.StdEncoding.EncodeToString(content),
    })
    return err
}

// 返回通知事件通道
func (c *AppServerClient) Events() <-chan ProviderEvent {
    return c.events
}

// 关闭
func (c *AppServerClient) Close() error {
    close(c.done)
    if c.process != nil {
        c.process.Kill()
    }
    if c.wsConn != nil {
        c.wsConn.Close()
    }
    return nil
}
```

### 2.4 事件映射

```go
// internal/codex/event_mapper.go

// 将 Codex 通知映射为 ProviderEvent
func (c *AppServerClient) handleNotification(msg *JSONRPCResponse) {
    switch msg.Method {
    case "thread/started":
        c.events <- ProviderEvent{
            Type:    "session.started",
            Payload: parsePayload(msg.Params),
        }

    case "turn/started":
        c.events <- ProviderEvent{
            Type: "session.turn_started",
        }

    case "turn/completed":
        c.events <- ProviderEvent{
            Type:    "session.turn_completed",
            Payload: parsePayload(msg.Params),
        }

    case "turn/failed":
        c.events <- ProviderEvent{
            Type:    "session.turn_failed",
            Payload: parsePayload(msg.Params),
        }

    case "item/started":
        c.events <- ProviderEvent{
            Type:    "session.item_started",
            Payload: parsePayload(msg.Params),
        }

    case "item/completed":
        payload := parsePayload(msg.Params)
        // 根据 item 类型细分
        item := payload.(map[string]any)
        switch item["type"] {
        case "command_execution":
            c.events <- ProviderEvent{
                Type:    "session.command_completed",
                Payload: payload,
            }
        case "agent_message":
            c.events <- ProviderEvent{
                Type:    "session.message",
                Payload: payload,
            }
        case "file_change":
            c.events <- ProviderEvent{
                Type:    "session.file_write",
                Payload: payload,
            }
        case "file_read":
            c.events <- ProviderEvent{
                Type:    "session.file_read",
                Payload: payload,
            }
        case "mcp_tool_call":
            c.events <- ProviderEvent{
                Type:    "session.mcp_tool_completed",
                Payload: payload,
            }
        default:
            c.events <- ProviderEvent{
                Type:    "session.item_completed",
                Payload: payload,
            }
        }

    case "item/commandExecution/requestApproval":
        c.events <- ProviderEvent{
            Type:    "session.approval_request",
            Payload: parsePayload(msg.Params),
        }

    case "item/fileChange/requestApproval":
        c.events <- ProviderEvent{
            Type:    "session.approval_request",
            Payload: parsePayload(msg.Params),
        }

    case "item/mcpToolCall/requestApproval":
        c.events <- ProviderEvent{
            Type:    "session.approval_request",
            Payload: parsePayload(msg.Params),
        }

    case "error":
        c.events <- ProviderEvent{
            Type:    "session.error",
            Payload: parsePayload(msg.Params),
        }
    }
}
```

---

## 三、审批代理系统

### 3.1 审批代理

```go
// internal/codex/approval_proxy.go

type ApprovalProxy struct {
    rules        []ApprovalRule
    wsHub        *ws.Hub
    pending      map[string]chan ApprovalDecision
    pendingMu    sync.RWMutex
    sessionRules map[string]map[string]bool // sessionID → command → allowed
    mu           sync.RWMutex
}

type ApprovalRule struct {
    Pattern     string         `yaml:"pattern"` // 正则
    Action      string         `yaml:"action"`  // "allow" | "deny" | "ask"
    Description string         `yaml:"description"`
    re          *regexp.Regexp // 编译后的正则
}

type ApprovalRequest struct {
    ID        string `json:"id"`
    SessionID string `json:"session_id"`
    ThreadID  string `json:"thread_id"`
    Type      string `json:"type"` // "command_execution" | "file_change"
    Command   string `json:"command,omitempty"`
    FilePath  string `json:"file_path,omitempty"`
    CWD       string `json:"cwd,omitempty"`
}

type ApprovalDecision struct {
    Action  string `json:"action"` // "accept" | "acceptForSession" | "decline" | "cancel"
    Message string `json:"message,omitempty"`
}

func (p *ApprovalProxy) HandleRequest(ctx context.Context, req ApprovalRequest) ApprovalDecision {
    // 1. 检查 session 级缓存（acceptForSession）
    p.mu.RLock()
    if rules, ok := p.sessionRules[req.SessionID]; ok {
        if allowed, exists := rules[req.Command]; exists && allowed {
            p.mu.RUnlock()
            return ApprovalDecision{Action: "accept"}
        }
    }
    p.mu.RUnlock()

    // 2. 检查规则
    for _, rule := range p.rules {
        if rule.re.MatchString(req.Command) {
            switch rule.Action {
            case "allow":
                return ApprovalDecision{Action: "accept"}
            case "deny":
                return ApprovalDecision{Action: "decline"}
            }
        }
    }

    // 3. 转发到手机
    return p.forwardToMobile(ctx, req)
}

func (p *ApprovalProxy) forwardToMobile(ctx context.Context, req ApprovalRequest) ApprovalDecision {
    ch := make(chan ApprovalDecision, 1)
    p.pendingMu.Lock()
    p.pending[req.ID] = ch
    p.pendingMu.Unlock()

    defer func() {
        p.pendingMu.Lock()
        delete(p.pending, req.ID)
        p.pendingMu.Unlock()
    }()

    // 推送到手机
    p.wsHub.Broadcast(map[string]any{
        "type": "session.approval_request",
        "data": req,
    })

    // 等待手机响应（超时 120s）
    select {
    case decision := <-ch:
        // 如果是 acceptForSession，记录到 sessionRules
        if decision.Action == "acceptForSession" {
            p.mu.Lock()
            if p.sessionRules[req.SessionID] == nil {
                p.sessionRules[req.SessionID] = make(map[string]bool)
            }
            p.sessionRules[req.SessionID][req.Command] = true
            p.mu.Unlock()
            decision.Action = "accept"
        }
        return decision
    case <-time.After(120 * time.Second):
        return ApprovalDecision{Action: "decline", Message: "approval timeout"}
    case <-ctx.Done():
        return ApprovalDecision{Action: "cancel"}
    }
}

// 手机端调用此方法提交审批决策
func (p *ApprovalProxy) Resolve(approvalID string, decision ApprovalDecision) {
    p.pendingMu.RLock()
    ch, ok := p.pending[approvalID]
    p.pendingMu.RUnlock()
    if ok {
        ch <- decision
    }
}
```

---

## 四、Codex Provider 实现

### 4.1 Provider 主体

```go
// internal/codex/provider.go

type CodexProvider struct {
    clients     map[string]*AppServerClient // sessionID → client
    clientsMu   sync.RWMutex
    // per-session 事件通道（避免共享 channel 瓶颈）
    sessions    map[string]chan ProviderEvent // sessionID → event channel
    sessionsMu  sync.RWMutex
    approval    *ApprovalProxy
    cfg         CodexConfig
}

func New(cfg CodexConfig) *CodexProvider {
    return &CodexProvider{
        clients:  make(map[string]*AppServerClient),
        sessions: make(map[string]chan ProviderEvent),
        approval: NewApprovalProxy(cfg.ApprovalRules),
        cfg:      cfg,
    }
}

// Subscribe 订阅指定 session 的事件（Session Manager 调用）
func (p *CodexProvider) Subscribe(sessionID string) <-chan ProviderEvent {
    p.sessionsMu.Lock()
    defer p.sessionsMu.Unlock()
    ch := make(chan ProviderEvent, 256)
    p.sessions[sessionID] = ch
    return ch
}

// Unsubscribe 取消订阅
func (p *CodexProvider) Unsubscribe(sessionID string) {
    p.sessionsMu.Lock()
    defer p.sessionsMu.Unlock()
    if ch, ok := p.sessions[sessionID]; ok {
        close(ch)
        delete(p.sessions, sessionID)
    }
}

// emit 向指定 session 的通道发送事件
func (p *CodexProvider) emit(sessionID string, event ProviderEvent) {
    p.sessionsMu.RLock()
    ch, ok := p.sessions[sessionID]
    p.sessionsMu.RUnlock()
    if ok {
        select {
        case ch <- event:
        default:
            // channel 满，丢弃旧事件或日志告警
        }
    }
}

func (p *CodexProvider) Name() string { return "codex" }

func (p *CodexProvider) Detect(ctx context.Context) (*ProviderInfo, error) {
    bin, err := exec.LookPath("codex")
    if err != nil {
        return nil, ErrNotInstalled
    }

    // 检查版本
    version, err := getCodexVersion(bin)
    if err != nil {
        return nil, err
    }

    // 检查 App Server 支持
    supportsAppServer := checkAppServerSupport(version)

    mode := "pty"
    if supportsAppServer {
        mode = "app-server-stdio"
    }

    return &ProviderInfo{
        Name:    "codex",
        Version: version,
        Binary:  bin,
        Status:  "available",
        RunMode: mode,
        Capabilities: p.getCapabilities(mode),
    }, nil
}

func (p *CodexProvider) CreateSession(ctx context.Context, req CreateSessionRequest) (*Session, error) {
    // 1. 创建 App Server 客户端
    client, err := NewAppServerClient(ctx, p.cfg)
    if err != nil {
        return nil, err
    }

    // 2. 初始化握手
    if err := client.Initialize(ctx); err != nil {
        client.Close()
        return nil, err
    }

    // 3. 创建线程
    threadID, err := client.StartThread(ctx, ThreadOpts{
        Model:          req.Model,
        Cwd:            req.Workdir,
        ApprovalPolicy: req.ApprovalPolicy,
        Sandbox:        req.SandboxMode,
    })
    if err != nil {
        client.Close()
        return nil, err
    }

    // 4. 保存客户端
    sessionID := uuid.New().String()
    p.clientsMu.Lock()
    p.clients[sessionID] = client
    p.clientsMu.Unlock()

    // 5. 监听事件
    go p.forwardEvents(sessionID, client)

    // 6. 如果有 prompt，发送第一个 turn
    if req.Prompt != "" {
        if err := client.StartTurn(ctx, TurnOpts{
            ThreadID:       threadID,
            Input:          req.Prompt,
            Cwd:            req.Workdir,
            ApprovalPolicy: req.ApprovalPolicy,
            SandboxPolicy:  req.SandboxMode,
            Model:          req.Model,
        }); err != nil {
            client.Close()
            return nil, err
        }
    }

    return &Session{
        ID:         sessionID,
        ThreadID:   threadID,
        ProjectID:  req.ProjectID,
        Workdir:    req.Workdir,
        Status:     "running",
        RunnerType: "app-server",
        Model:      req.Model,
    }, nil
}

// 转发 Codex 事件到 per-session 通道
func (p *CodexProvider) forwardEvents(sessionID string, client *AppServerClient) {
    for event := range client.Events() {
        event.SessionID = sessionID

        // 拦截审批请求
        if event.Type == "session.approval_request" {
            req := event.Payload.(ApprovalRequest)
            req.SessionID = sessionID
            decision := p.approval.HandleRequest(context.Background(), req)
            // 将决策发送回 Codex（具体 RPC 方法在 Day 0 验证）
            client.sendApprovalDecision(req.ID, decision)
            continue
        }

        // 发送到该 session 的专属通道
        p.emit(sessionID, event)
    }
}

func (p *CodexProvider) SendInput(ctx context.Context, sessionID, input string) error {
    p.clientsMu.RLock()
    client, ok := p.clients[sessionID]
    p.clientsMu.RUnlock()
    if !ok {
        return ErrSessionNotFound
    }
    return client.SteerTurn(ctx, client.threadID(sessionID), input)
}

func (p *CodexProvider) InterruptSession(ctx context.Context, sessionID string) error {
    p.clientsMu.RLock()
    client, ok := p.clients[sessionID]
    p.clientsMu.RUnlock()
    if !ok {
        return ErrSessionNotFound
    }
    return client.InterruptTurn(ctx, client.threadID(sessionID))
}

func (p *CodexProvider) StopSession(ctx context.Context, sessionID string) error {
    p.clientsMu.Lock()
    client, ok := p.clients[sessionID]
    if ok {
        delete(p.clients, sessionID)
    }
    p.clientsMu.Unlock()
    if !ok {
        return ErrSessionNotFound
    }
    return client.Close()
}

func (p *CodexProvider) Capabilities() ProviderCapabilities {
    return p.getCapabilities("app-server-stdio")
}
```

---

## 五、Session Manager

### 5.1 管理器实现

```go
// internal/session/manager.go

type Manager struct {
    store      *SessionStore
    registry   *provider.Registry
    wsHub      *ws.Hub
    eventSeq   map[string]int64 // sessionID → last seq
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

func (m *Manager) CreateSession(ctx context.Context, req CreateSessionRequest) (*Session, error) {
    // 1. 获取 Provider
    p, err := m.registry.Get(req.Provider)
    if err != nil {
        return nil, err
    }

    // 2. 创建会话
    session, err := p.CreateSession(ctx, req)
    if err != nil {
        return nil, err
    }

    // 3. 持久化
    if err := m.store.Save(session); err != nil {
        return nil, err
    }

    // 4. 订阅 per-session 事件通道并收集
    go m.collectEvents(session.ID, p)

    // 5. 广播创建事件
    m.wsHub.Broadcast(map[string]any{
        "type":       "session.created",
        "session_id": session.ID,
        "data":       session,
    })

    return session, nil
}

// 收集 Provider 事件并持久化（使用 per-session 订阅）
func (m *Manager) collectEvents(sessionID string, p provider.Provider) {
    // 订阅该 session 的专属事件通道
    events := p.Subscribe(sessionID)
    defer p.Unsubscribe(sessionID)

    for event := range events {

        // 分配 seq
        m.eventSeqMu.Lock()
        m.eventSeq[sessionID]++
        seq := m.eventSeq[sessionID]
        m.eventSeqMu.Unlock()

        // 持久化
        m.store.SaveEvent(SessionEvent{
            SessionID: sessionID,
            Seq:       seq,
            Type:      event.Type,
            Payload:   event.Payload,
            CreatedAt: event.Timestamp,
        })

        // 广播到 WebSocket
        m.wsHub.Broadcast(map[string]any{
            "type":       event.Type,
            "seq":        seq,
            "session_id": sessionID,
            "time":       event.Timestamp.Unix(),
            "data":       event.Payload,
        })
    }
}

// 断线恢复：获取 last_seq 之后的事件
func (m *Manager) GetEventsAfterSeq(sessionID string, afterSeq int64, limit int) ([]SessionEvent, error) {
    return m.store.GetEventsAfterSeq(sessionID, afterSeq, limit)
}

// 获取会话列表
func (m *Manager) ListSessions(projectID string) ([]Session, error) {
    return m.store.ListByProject(projectID)
}

// 获取会话详情
func (m *Manager) GetSession(id string) (*Session, error) {
    return m.store.Get(id)
}

// 停止会话
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
    session.ExitedAt = timePtr(time.Now())
    return m.store.Update(session)
}

// 分叉会话
func (m *Manager) ForkSession(ctx context.Context, id string) (*Session, error) {
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

    newSession := &Session{
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

// Agent 重启后恢复
func (m *Manager) Recover(ctx context.Context) error {
    sessions, err := m.store.GetActiveSessions()
    if err != nil {
        return err
    }

    for _, s := range sessions {
        // 尝试通过 Codex thread/resume 恢复
        p, err := m.registry.Get(s.ProviderID)
        if err != nil {
            m.store.UpdateStatus(s.ID, "lost")
            continue
        }

        if err := p.ResumeSession(ctx, s.ID, s.ThreadID); err != nil {
            m.store.UpdateStatus(s.ID, "lost")
            continue
        }

        s.Status = "running"
        m.store.Update(&s)
    }

    return nil
}
```

### 5.2 Session Store

```go
// internal/session/store.go

type SessionStore struct {
    db *storage.SQLite
}

func (s *SessionStore) Save(session *Session) error {
    _, err := s.db.Exec(`
        INSERT INTO sessions (id, provider_id, thread_id, project_id, title,
            workdir, status, runner_type, model, approval_mode, sandbox_mode,
            config, last_seq, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)`,
        session.ID, session.ProviderID, session.ThreadID, session.ProjectID,
        session.Title, session.Workdir, session.Status, session.RunnerType,
        session.Model, session.ApprovalMode, session.SandboxMode,
        session.Config, time.Now().Unix(), time.Now().Unix())
    return err
}

func (s *SessionStore) Get(id string) (*Session, error) {
    row := s.db.QueryRow(`SELECT * FROM sessions WHERE id = ?`, id)
    // scan...
}

func (s *SessionStore) ListByProject(projectID string) ([]Session, error) {
    rows, err := s.db.Query(`SELECT * FROM sessions WHERE project_id = ? ORDER BY updated_at DESC`, projectID)
    // scan...
}

func (s *SessionStore) GetActiveSessions() ([]Session, error) {
    rows, err := s.db.Query(`SELECT * FROM sessions WHERE status IN ('running', 'waiting_input')`)
    // scan...
}

func (s *SessionStore) UpdateStatus(id, status string) error {
    _, err := s.db.Exec(`UPDATE sessions SET status = ?, updated_at = ? WHERE id = ?`,
        status, time.Now().Unix(), id)
    return err
}

func (s *SessionStore) SaveEvent(event SessionEvent) error {
    _, err := s.db.Exec(`
        INSERT INTO session_events (session_id, seq, type, payload, created_at)
        VALUES (?, ?, ?, ?, ?)`,
        event.SessionID, event.Seq, event.Type, event.Payload, event.CreatedAt.Unix())
    return err
}

func (s *SessionStore) GetEventsAfterSeq(sessionID string, afterSeq int64, limit int) ([]SessionEvent, error) {
    rows, err := s.db.Query(`
        SELECT id, session_id, seq, type, payload, created_at
        FROM session_events
        WHERE session_id = ? AND seq > ?
        ORDER BY seq ASC
        LIMIT ?`, sessionID, afterSeq, limit)
    // scan...
}
```

---

## 六、HTTP API（会话相关）

```go
// internal/api/handlers/session.go

// POST /api/sessions
func (h *SessionHandler) Create(c *gin.Context) {
    var req struct {
        Provider       string `json:"provider"`
        ProjectID      string `json:"project_id"`
        Model          string `json:"model"`
        ApprovalPolicy string `json:"approval_policy"`
        SandboxMode    string `json:"sandbox_mode"`
        Prompt         string `json:"prompt"`
    }
    c.ShouldBindJSON(&req)

    session, err := h.manager.CreateSession(c.Request.Context(), CreateSessionRequest{
        Provider:       req.Provider,
        ProjectID:      req.ProjectID,
        Model:          req.Model,
        ApprovalPolicy: req.ApprovalPolicy,
        SandboxMode:    req.SandboxMode,
        Prompt:         req.Prompt,
    })
    // ...
}

// GET /api/sessions/:id
func (h *SessionHandler) Get(c *gin.Context) {}

// GET /api/sessions?project_id=xxx
func (h *SessionHandler) List(c *gin.Context) {}

// POST /api/sessions/:id/input
func (h *SessionHandler) SendInput(c *gin.Context) {
    var req struct {
        Input string `json:"input"`
    }
    c.ShouldBindJSON(&req)
    h.manager.SendInput(c, c.Param("id"), req.Input)
}

// POST /api/sessions/:id/interrupt
func (h *SessionHandler) Interrupt(c *gin.Context) {}

// POST /api/sessions/:id/stop
func (h *SessionHandler) Stop(c *gin.Context) {}

// POST /api/sessions/:id/fork
func (h *SessionHandler) Fork(c *gin.Context) {}

// POST /api/sessions/:id/compact
func (h *SessionHandler) Compact(c *gin.Context) {}

// POST /api/sessions/:id/rollback
func (h *SessionHandler) Rollback(c *gin.Context) {}

// GET /api/sessions/:id/events?after_seq=N&limit=100
func (h *SessionHandler) GetEvents(c *gin.Context) {}

// POST /api/sessions/:id/approve
func (h *SessionHandler) Approve(c *gin.Context) {
    var req struct {
        ApprovalID string `json:"approval_id"`
        Action     string `json:"action"` // accept | acceptForSession | decline | cancel
    }
    c.ShouldBindJSON(&req)
    h.approvalProxy.Resolve(req.ApprovalID, ApprovalDecision{Action: req.Action})
}
```

---

## 七、Flutter（会话相关页面）

### 7.1 会话创建页面

```dart
// features/sessions/create/session_create_page.dart

class SessionCreatePage extends ConsumerStatefulWidget {
  final String projectId;

  // 状态：
  // - availableProviders: 从 GET /api/providers 获取
  // - availableModels: 从 GET /api/providers/:name/models 获取
  // - selectedProvider: 默认 "codex"
  // - selectedModel: 默认 "gpt-5.4"
  // - approvalPolicy: 默认 "on-request"
  // - sandboxMode: 默认 "workspace-write"
  // - promptController: 用户输入

  // UI：
  // - Provider 选择（Chip 列表）
  // - 模型选择（下拉）
  // - 审批策略（三选一 Radio）
  // - 沙箱模式（三选一 Radio）
  // - Prompt 输入框
  // - 快捷模式按钮：
  //   - "快速提问"：read-only + on-request
  //   - "自动编码"：workspace-write + on-request
  //   - "完全信任"：danger-full-access + never
  // - 创建按钮
}
```

### 7.2 会话聊天页面

```dart
// features/sessions/chat/chat_page.dart

class ChatPage extends ConsumerStatefulWidget {
  final String sessionId;

  // 数据源：
  // 1. 初始加载：GET /api/sessions/:id/events?after_seq=0&limit=100
  // 2. 实时更新：WebSocket 事件流
  // 3. 断线恢复：重连后 GET /api/sessions/:id/events?after_seq=lastSeq

  // 消息类型渲染：
  // - session.message → AI 文本气泡（Markdown 渲染）
  // - session.command_started → 命令执行指示器（转圈动画）
  // - session.command_completed → 命令卡片（可展开查看完整输出）
  // - session.file_read → 文件读取指示
  // - session.file_write → 文件变更卡片（+N -M，可点击查看 Diff）
  // - session.mcp_tool_started → MCP 工具调用指示器
  // - session.mcp_tool_completed → MCP 工具结果卡片（可展开）
  // - session.approval_request → 审批对话框（阻塞式）
  // - session.turn_started → 加载指示器
  // - session.turn_completed → 加载结束（含 token 统计）
  // - session.error → 错误消息
}

// 消息气泡组件
class MessageBubble extends StatelessWidget {
  final SessionEvent event;

  // 根据 event.type 渲染不同内容
  // - agent_message: Markdown 渲染
  // - command_execution: 终端样式卡片，可展开/折叠
  // - file_change: 文件路径 + additions/deletions 摘要 + 查看 Diff 按钮
  // - mcp_tool_call: 工具名称 + 参数摘要 + 结果（可展开）
}

// 工具调用卡片组件（命令 + MCP 工具共用）
class ToolCallCard extends StatelessWidget {
  final SessionEvent event;

  // 折叠状态：显示图标 + 工具名 + 摘要（一行）
  //   命令：▶ $ git status
  //   MCP：🔧 github.search_repos(query="magent")
  //
  // 展开状态：
  //   命令：完整命令 + 完整输出（终端样式）
  //   MCP：完整参数 JSON + 完整结果 JSON
  //
  // 状态指示：
  //   进行中：转圈 + "执行中..."
  //   完成：✓ 绿色
  //   失败：✗ 红色 + 错误信息
}

// 审批对话框
class ApprovalDialog extends StatelessWidget {
  final ApprovalRequest request;

  // 根据 request.type 显示不同内容：
  //
  // command_execution：
  //   图标：▶
  //   标题："命令执行审批"
  //   内容：命令文本（等宽字体）
  //   详情：工作目录
  //
  // file_change：
  //   图标：📝
  //   标题："文件变更审批"
  //   内容：文件路径 + diff 摘要
  //
  // mcp_tool_call：
  //   图标：🔧
  //   标题："MCP 工具调用审批"
  //   内容：服务器名.工具名 + 参数摘要
  //   详情：完整参数 JSON

  // 按钮：
  // - "允许"（accept）
  // - "本次会话允许"（acceptForSession）
  // - "拒绝"（decline）
  // - "取消任务"（cancel）
}
```

### 7.3 输入栏

```dart
// features/sessions/chat/input_bar.dart

class ChatInputBar extends ConsumerWidget {
  final String sessionId;

  // 功能：
  // - 文本输入
  // - 发送按钮 → POST /api/sessions/:id/input
  // - 快捷按钮行：
  //   - "继续" → 发送 "continue"
  //   - "总结" → 发送 "summarize what you've done"
  //   - "查看 Diff" → 导航到 Git 页面
  //   - "Ctrl-C" → POST /api/sessions/:id/interrupt
  //   - "停止" → POST /api/sessions/:id/stop
}
```

---

## 八、基础数据同步（Config Sync）

手机端不硬编码任何 Provider 配置（模型列表、推理强度、审批策略可选值等），全部从 Agent 动态获取。

### 8.1 Agent 端：Config Service

```go
// internal/config/service.go

type ConfigService struct {
    registry *provider.Registry
    cfg      *Config
    store    *storage.SQLite

    // 缓存
    cache     *BootstrapData
    cacheHash string
    cacheMu   sync.RWMutex

    // 变更通知
    dirty     chan struct{}
}

func NewConfigService(registry *provider.Registry, cfg *Config, store *storage.SQLite) *ConfigService {
    s := &ConfigService{
        registry: registry,
        cfg:      cfg,
        store:    store,
        dirty:    make(chan struct{}, 1),
    }
    // 启动时从 DB 加载缓存
    s.loadCache()
    // 启动后台刷新
    go s.refreshLoop()
    return s
}

// Check 返回当前 config_hash，Flutter 用来判断是否需要拉全量
func (s *ConfigService) Check() *CheckResult {
    s.cacheMu.RLock()
    defer s.cacheMu.RUnlock()
    return &CheckResult{
        ConfigHash: s.cacheHash,
        UpdatedAt:  s.cache.UpdatedAt,
    }
}

// Bootstrap 返回全量数据，支持 local_hash 对比
func (s *ConfigService) Bootstrap(ctx context.Context, localHash string) (*BootstrapData, int, error) {
    s.cacheMu.RLock()
    // 如果本地 hash 匹配，返回 304
    if localHash != "" && localHash == s.cacheHash {
        s.cacheMu.RUnlock()
        return nil, 304, nil
    }
    data := s.cache
    s.cacheMu.RUnlock()

    // 缓存有效直接返回
    if data != nil {
        return data, 200, nil
    }

    // 缓存为空，强制刷新
    if err := s.refresh(ctx); err != nil {
        return nil, 500, err
    }

    s.cacheMu.RLock()
    defer s.cacheMu.RUnlock()
    return s.cache, 200, nil
}

// MarkDirty 标记配置需要刷新（Provider 变化、项目增删、配置修改时调用）
func (s *ConfigService) MarkDirty() {
    select {
    case s.dirty <- struct{}{}:
    default:
        already pending
    }
}

// 后台刷新循环
func (s *ConfigService) refreshLoop() {
    for range s.dirty {
        ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
        s.refresh(ctx)
        cancel()
    }
}

// 刷新缓存
func (s *ConfigService) refresh(ctx context.Context) error {
    providers := s.registry.List()

    var providerConfigs []ProviderConfigData
    for _, p := range providers {
        if p.Status != "available" {
            providerConfigs = append(providerConfigs, ProviderConfigData{
                Name:   p.Name,
                Status: "unavailable",
                Error:  p.Error,
            })
            continue
        }

        schema := s.getProviderConfigSchema(ctx, p.Name)
        presets := s.getProviderPresets(p.Name)
        mcpServers := s.getMCPServers(p.Name)

        providerConfigs = append(providerConfigs, ProviderConfigData{
            Name:         p.Name,
            Status:       "available",
            Version:      p.Version,
            RunMode:      p.RunMode,
            Capabilities: p.Capabilities,
            ConfigSchema: schema,
            Presets:      presets,
            MCPServers:   mcpServers,
        })
    }

    data := &BootstrapData{
        Agent: AgentData{
            Version:      version,
            Capabilities: s.getAgentCapabilities(),
        },
        Providers: providerConfigs,
        Projects:  s.getProjects(ctx),
        Workspace: s.getWorkspaceConfig(),
        UpdatedAt: time.Now().Unix(),
    }

    // 计算 hash
    hash := s.computeHash(data)

    // 更新缓存
    s.cacheMu.Lock()
    s.cache = data
    s.cacheHash = hash
    s.cacheMu.Unlock()

    // 持久化到 DB
    s.saveCache(data, hash)

    return nil
}

// 计算配置 hash（基于所有影响配置的内容）
func (s *ConfigService) computeHash(data *BootstrapData) string {
    h := sha256.New()

    // Agent 版本
    h.Write([]byte(data.Agent.Version))

    // Provider 状态
    for _, p := range data.Providers {
        h.Write([]byte(p.Name))
        h.Write([]byte(p.Status))
        h.Write([]byte(p.Version))
        if p.ConfigSchema != nil {
            schemaJSON, _ := json.Marshal(p.ConfigSchema)
            h.Write(schemaJSON)
        }
    }

    // 项目列表
    for _, p := range data.Projects {
        h.Write([]byte(p.ID))
        h.Write([]byte(p.Name))
    }

    // 工作空间配置
    wsJSON, _ := json.Marshal(data.Workspace)
    h.Write(wsJSON)

    return hex.EncodeToString(h.Sum(nil))[:16]
}

// 从 DB 加载缓存
func (s *ConfigService) loadCache() {
    row := s.store.QueryRow(`SELECT config_hash, data FROM bootstrap_cache WHERE id = 1`)
    var hash string
    var dataBytes []byte
    if err := row.Scan(&hash, &dataBytes); err != nil {
        return // 无缓存
    }
    var data BootstrapData
    json.Unmarshal(dataBytes, &data)

    s.cacheMu.Lock()
    s.cache = &data
    s.cacheHash = hash
    s.cacheMu.Unlock()
}

// 持久化缓存到 DB
func (s *ConfigService) saveCache(data *BootstrapData, hash string) {
    dataBytes, _ := json.Marshal(data)
    s.store.Exec(`
        INSERT OR REPLACE INTO bootstrap_cache (id, config_hash, data, updated_at)
        VALUES (1, ?, ?, ?)`, hash, dataBytes, time.Now().Unix())
}

// 动态配置 Schema：每个字段的类型、可选值、默认值
func (s *ConfigService) getProviderConfigSchema(provider string) map[string]FieldSchema {
    switch provider {
    case "codex":
        return map[string]FieldSchema{
            "model": {
                Type:    "enum",
                Label:   "模型",
                Values:  s.getCodexModels(), // 从 Codex API 动态获取
                Default: "gpt-5.4",
            },
            "approval_policy": {
                Type:    "enum",
                Label:   "审批策略",
                Values:  []string{"untrusted", "on-request", "never"},
                Default: "on-request",
                Descriptions: map[string]string{
                    "untrusted": "最严格，所有操作都需要审批",
                    "on-request": "仅在需要时请求审批",
                    "never":     "从不请求审批（危险）",
                },
            },
            "sandbox_mode": {
                Type:    "enum",
                Label:   "沙箱模式",
                Values:  []string{"read-only", "workspace-write", "danger-full-access"},
                Default: "workspace-write",
            },
            "reasoning_effort": {
                Type:    "enum",
                Label:   "推理强度",
                Values:  []string{"low", "medium", "high"},
                Default: "medium",
            },
            "web_search": {
                Type:    "enum",
                Label:   "网络搜索",
                Values:  []string{"off", "cached", "on"},
                Default: "cached",
            },
        }
    default:
        return nil
    }
}

// 动态获取模型列表（调用 Codex App Server model/list）
func (s *ConfigService) getCodexModels() []string {
    // 通过 Codex App Server 的 model/list API 获取
    // 不硬编码，新增模型时自动出现
}
```

### 8.2 数据结构

```go
type BootstrapData struct {
    Agent      AgentData            `json:"agent"`
    Providers  []ProviderConfigData `json:"providers"`
    Projects   []ProjectSummary     `json:"projects"`
    Workspace  WorkspaceConfig      `json:"workspace"`
}

type AgentData struct {
    Version      string             `json:"version"`
    Capabilities AgentCapabilities  `json:"capabilities"`
}

type ProviderConfigData struct {
    Name         string               `json:"name"`
    Status       string               `json:"status"`
    Version      string               `json:"version,omitempty"`
    RunMode      string               `json:"run_mode,omitempty"`
    Error        string               `json:"error,omitempty"`
    Capabilities ProviderCapabilities `json:"capabilities,omitempty"`
    ConfigSchema map[string]FieldSchema `json:"config_schema,omitempty"`
    Presets      []ConfigPreset       `json:"presets,omitempty"`
    MCPServers   []MCPServerInfo      `json:"mcp_servers,omitempty"`
}

type FieldSchema struct {
    Type        string            `json:"type"` // "enum" | "string" | "int" | "bool"
    Label       string            `json:"label"`
    Values      []string          `json:"values,omitempty"`    // enum 可选值
    Default     any               `json:"default,omitempty"`
    Min         *int              `json:"min,omitempty"`       // int 最小值
    Max         *int              `json:"max,omitempty"`       // int 最大值
    Placeholder string            `json:"placeholder,omitempty"`
    Descriptions map[string]string `json:"descriptions,omitempty"` // enum 值的描述
}

type ConfigPreset struct {
    Name        string         `json:"name"`
    Description string         `json:"description"`
    Config      map[string]any `json:"config"`
}

type MCPServerInfo struct {
    Name        string   `json:"name"`
    Description string   `json:"description"`
    Tools       []string `json:"tools"`
}
```

### 8.3 HTTP API

```go
// 轻量检查：仅返回 hash，Flutter 用来判断是否需要拉全量
// GET /api/sync/check
func (h *SyncHandler) Check(c *gin.Context) {
    result := h.configService.Check()
    c.JSON(200, result) // {"config_hash": "xxx", "updated_at": 1710000000}
}

// 全量拉取：支持 local_hash 参数，匹配则 304
// GET /api/sync/bootstrap?local_hash=xxx
func (h *SyncHandler) Bootstrap(c *gin.Context) {
    localHash := c.Query("local_hash")
    data, status, err := h.configService.Bootstrap(c.Request.Context(), localHash)
    if status == 304 {
        c.Status(304)
        return
    }
    if err != nil {
        c.JSON(500, gin.H{"error": err.Error()})
        return
    }
    c.JSON(200, data)
}

// 单独刷新某个 Provider 的配置（可选）
// GET /api/providers/:name/config-schema
func (h *ProviderHandler) ConfigSchema(c *gin.Context) {
    name := c.Param("name")
    schema := h.configService.getProviderConfigSchema(c, name)
    c.JSON(200, gin.H{"schema": schema})
}

// 获取可用模型（从 Provider 动态获取）
// GET /api/providers/:name/models
func (h *ProviderHandler) Models(c *gin.Context) {
    name := c.Param("name")
    p, err := h.registry.Get(name)
    if err != nil {
        c.JSON(404, gin.H{"error": "provider not found"})
        return
    }
    client := p.GetDefaultClient()
    models, err := client.ListModels(c.Request.Context())
    c.JSON(200, gin.H{"models": models})
}
```

### 8.4 Flutter 端：启动同步

```dart
// core/sync/bootstrap_sync.dart

class BootstrapSync {
  final ApiClient _api;
  final DriftDatabase _db;

  BootstrapData? _data;
  String? _configHash;

  BootstrapData? get data => _data;
  String? get configHash => _configHash;

  /// App 启动或连接 Agent 时调用
  /// 两级同步：先 check hash，变化才拉全量
  Future<BootstrapData> sync() async {
    // 第 1 步：轻量 check（~100B）
    final checkResp = await _api.dio.get('/api/sync/check');
    final remoteHash = checkResp.data['config_hash'] as String;

    // 第 2 步：对比本地 hash
    final localHash = await _getLocalHash();
    if (remoteHash == localHash && _data != null) {
      // hash 未变，使用本地缓存，无需拉全量
      return _data!;
    }

    // 第 3 步：hash 变化，拉全量（传入 local_hash，Agent 可返回 304）
    final resp = await _api.dio.get(
      '/api/sync/bootstrap',
      queryParameters: {'local_hash': localHash ?? ''},
    );

    if (resp.statusCode == 304) {
      // Agent 认为本地仍有效（边界情况）
      return _data!;
    }

    _data = BootstrapData.fromJson(resp.data);
    _configHash = _data!.configHash;

    // 缓存到本地 SQLite
    await _cacheBootstrap(_data!, _configHash!);

    return _data!;
  }

  /// 从本地 SQLite 加载缓存（离线时或首次同步前）
  Future<BootstrapData?> loadFromCache() async {
    final row = await _db.bootstrapCache.getOrNull(1);
    if (row == null) return null;

    _data = BootstrapData.fromJson(jsonDecode(row.data));
    _configHash = row.configHash;
    return _data;
  }

  Future<String?> _getLocalHash() async {
    if (_configHash != null) return _configHash;
    final row = await _db.bootstrapCache.getOrNull(1);
    _configHash = row?.configHash;
    return _configHash;
  }

  Future<void> _cacheBootstrap(BootstrapData data, String hash) async {
    await _db.bootstrapCache.insert(
      BootstrapCacheRow(id: 1, configHash: hash, data: jsonEncode(data.toJson())),
      mode: InsertMode.replace,
    );
  }

  // 便捷查询方法
  Map<String, FieldSchema>? getProviderConfigSchema(String providerName) {
    return _data?.providers
        .firstWhereOrNull((p) => p.name == providerName)
        ?.configSchema;
  }

  List<String> getModels(String providerName) {
    final schema = getProviderConfigSchema(providerName);
    return schema?['model']?.values ?? [];
  }

  List<ConfigPreset> getPresets(String providerName) {
    return _data?.providers
        .firstWhereOrNull((p) => p.name == providerName)
        ?.presets ?? [];
  }
}
```

**同步流程**：

```
Flutter 启动 / 连接 Agent
  ↓
GET /api/sync/check
  ↓ 返回 config_hash
  ↓
对比本地 SQLite 中的 hash
  ├── 相同 → 使用本地缓存，完成（流量 ~100B）
  └── 不同 ↓
GET /api/sync/bootstrap?local_hash=xxx
  ↓
Agent 对比 local_hash
  ├── 匹配 → 304（边界情况，Flutter 用本地缓存）
  └── 不匹配 → 返回全量 JSON（~2-5KB）
  ↓
Flutter 更新本地缓存 + hash
  ↓
UI 用新数据渲染
```

### 8.5 Flutter 端：创建会话页面（动态配置版）

```dart
// features/sessions/create/session_create_page.dart

class SessionCreatePage extends ConsumerStatefulWidget {
  final String projectId;

  // 所有选项从 BootstrapData 获取，不硬编码

  // Provider 选择：
  //   从 data.providers.where(p => p.status == 'available') 获取
  //   不可用的显示灰色 + 错误原因

  // 模型选择：
  //   从 data.providers[selected].config_schema.model.values 获取
  //   默认值从 config_schema.model.default 获取

  // 审批策略：
  //   从 config_schema.approval_policy.values 获取
  //   每个值显示 config_schema.approval_policy.descriptions[value]

  // 沙箱模式：
  //   从 config_schema.sandbox_mode.values 获取

  // 推理强度：
  //   从 config_schema.reasoning_effort.values 获取

  // 预设快捷按钮：
  //   从 data.providers[selected].presets 获取
  //   点击预设 → 自动填充对应配置

  // MCP 工具展示：
  //   从 data.providers[selected].mcp_servers 获取
  //   显示可用的 MCP 服务器和工具列表
}
```

---

## 九、实施步骤

### Week 1：Provider 基础 + App Server 客户端

| 天 | 任务 |
|---|---|
| D1 | Provider 接口定义 + Registry |
| D2 | JSON-RPC 2.0 协议实现 |
| D3 | App Server 客户端（stdio 模式）：Initialize + StartThread |
| D4 | App Server 客户端：StartTurn + 事件监听 |
| D5 | App Server 客户端：SteerTurn + InterruptTurn |
| D6-7 | 事件映射（含工具调用事件）+ 单元测试 |

### Week 2：Session Manager + 审批代理 + 配置同步

| 天 | 任务 |
|---|---|
| D8 | Session Store 实现 |
| D9 | Session Manager：Create/Get/List |
| D10 | Session Manager：事件收集 + 持久化 |
| D11 | 审批代理：规则匹配 + 手机转发 |
| D12 | Config Service：Bootstrap API + Provider Schema |
| D13 | Config Service：动态模型列表（model/list） |
| D14 | Session Manager：Stop/Fork/Compact/Rollback + 断线恢复 |

### Week 3：HTTP API + Flutter

| 天 | 任务 |
|---|---|
| D15 | Session HTTP API 全部端点 + Sync Bootstrap API |
| D16 | WebSocket 事件推送完善（含工具调用事件） |
| D17-18 | Flutter：启动同步 + 会话创建页面（动态配置） |
| D19-20 | Flutter：会话聊天页面（工具调用卡片 + 审批对话框） |
| D21 | Flutter：断线恢复 + 联调测试 |

---

## 九、验收标准

1. 可通过 App Server 协议创建 Codex 会话，AI 输出实时显示在手机端
2. Codex 执行命令时，审批请求正确推送到手机，手机可 approve/decline
3. 关闭手机 App 后重连，可恢复之前的会话输出
4. Agent 重启后，可恢复之前的会话（通过 thread/resume）
5. 会话事件按 seq 持久化，支持增量获取
6. `codex exec --json` 事件正确映射为 Magent 事件格式
