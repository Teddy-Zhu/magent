# Phase 6：Provider 扩展（1.5 周）

## 目标

支持多个 AI 编码 Provider（Claude、Aider、Qwen），实现统一的 Provider 管理界面。

## 前置条件

Phase 1-2 完成（Provider 接口 + Codex Provider 已就绪）。

## 产出

- Claude Provider（PTY 模式）
- Aider Provider（PTY 模式）
- Provider 自动检测
- Provider 能力查询
- Flutter Provider 管理页面

---

## 一、新 Provider 实现策略

新 Provider 使用 PTY 模式（因为它们没有类似 Codex App Server 的协议）。

### PTY Runner

```go
// internal/runner/pty_runner.go

type PTYRunner struct {
    cmd     *exec.Cmd
    pty     *os.File
    events  chan RunnerEvent
    done    chan struct{}
}

type RunnerEvent struct {
    Type    string // "output" | "exit" | "error"
    Data    []byte
    ExitCode int
}

func NewPTYRunner() *PTYRunner {
    return &PTYRunner{
        events: make(chan RunnerEvent, 256),
        done:   make(chan struct{}),
    }
}

func (r *PTYRunner) Start(ctx context.Context, spec CommandSpec) error {
    r.cmd = exec.CommandContext(ctx, spec.Bin, spec.Args...)
    r.cmd.Dir = spec.Workdir
    r.cmd.Env = append(os.Environ(), spec.Env...)

    ptmx, err := pty.Start(r.cmd)
    if err != nil {
        return err
    }
    r.pty = ptmx

    go r.readLoop()
    go r.waitExit()

    return nil
}

func (r *PTYRunner) readLoop() {
    buf := make([]byte, 4096)
    for {
        n, err := r.pty.Read(buf)
        if n > 0 {
            data := make([]byte, n)
            copy(data, buf[:n])
            r.events <- RunnerEvent{Type: "output", Data: data}
        }
        if err != nil {
            close(r.done)
            return
        }
    }
}

func (r *PTYRunner) waitExit() {
    err := r.cmd.Wait()
    exitCode := 0
    if err != nil {
        if exitErr, ok := err.(*exec.ExitError); ok {
            exitCode = exitErr.ExitCode()
        }
    }
    r.events <- RunnerEvent{Type: "exit", ExitCode: exitCode}
}

func (r *PTYRunner) Write(data []byte) error {
    _, err := r.pty.Write(data)
    return err
}

func (r *PTYRunner) Resize(cols, rows int) error {
    return pty.Setsize(r.pty, &pty.Winsize{Cols: uint16(cols), Rows: uint16(rows)})
}

func (r *PTYRunner) Stop() error {
    r.cmd.Process.Signal(os.Interrupt)
    return nil
}

func (r *PTYRunner) Events() <-chan RunnerEvent {
    return r.events
}
```

---

## 二、Claude Provider

### 2.1 Provider 实现

```go
// internal/providers/claude/provider.go

type ClaudeProvider struct {
    runners map[string]*PTYRunner
    events  chan ProviderEvent
    mu      sync.RWMutex
}

func New() *ClaudeProvider {
    return &ClaudeProvider{
        runners: make(map[string]*PTYRunner),
        events:  make(chan ProviderEvent, 256),
    }
}

func (p *ClaudeProvider) Name() string { return "claude" }

func (p *ClaudeProvider) Detect(ctx context.Context) (*ProviderInfo, error) {
    bin, err := exec.LookPath("claude")
    if err != nil {
        return nil, ErrNotInstalled
    }

    version := getClaudeVersion(bin)

    return &ProviderInfo{
        Name:    "claude",
        Version: version,
        Binary:  bin,
        Status:  "available",
        RunMode: "pty",
        Capabilities: ProviderCapabilities{
            Protocol:          "pty",
            SupportsResume:    false,
            SupportsFork:      false,
            SupportsSteer:     false,
            SupportsInterrupt: true,
            SupportsPTY:       true,
            StructuredOutput:  false,
            StreamingOutput:   true,
        },
    }, nil
}

func (p *ClaudeProvider) CreateSession(ctx context.Context, req CreateSessionRequest) (*Session, error) {
    sessionID := uuid.New().String()

    // 构建命令
    args := []string{}
    if req.Model != "" {
        args = append(args, "--model", req.Model)
    }
    // Claude 的 --dangerously-skip-permissions 等效于 full-auto
    if req.ApprovalPolicy == "never" {
        args = append(args, "--dangerously-skip-permissions")
    }
    args = append(args, "--print") // 非交互模式，输出后退出

    runner := NewPTYRunner()
    if err := runner.Start(ctx, CommandSpec{
        Bin:     "claude",
        Args:    args,
        Workdir: req.Workdir,
        UsePTY:  true,
    }); err != nil {
        return nil, err
    }

    p.mu.Lock()
    p.runners[sessionID] = runner
    p.mu.Unlock()

    // 发送 prompt
    if req.Prompt != "" {
        runner.Write([]byte(req.Prompt + "\n"))
    }

    // 收集输出
    go p.collectOutput(sessionID, runner)

    return &Session{
        ID:         sessionID,
        ProjectID:  req.ProjectID,
        Workdir:    req.Workdir,
        Status:     "running",
        RunnerType: "pty",
        Model:      req.Model,
    }, nil
}

func (p *ClaudeProvider) collectOutput(sessionID string, runner *PTYRunner) {
    for event := range runner.Events() {
        switch event.Type {
        case "output":
            p.events <- ProviderEvent{
                SessionID: sessionID,
                Type:      "session.output",
                Payload:   map[string]any{"content": string(event.Data)},
                Timestamp: time.Now(),
            }
        case "exit":
            p.events <- ProviderEvent{
                SessionID: sessionID,
                Type:      "session.exited",
                Payload:   map[string]any{"exit_code": event.ExitCode},
                Timestamp: time.Now(),
            }
            p.mu.Lock()
            delete(p.runners, sessionID)
            p.mu.Unlock()
        }
    }
}

func (p *ClaudeProvider) SendInput(ctx context.Context, sessionID, input string) error {
    p.mu.RLock()
    runner, ok := p.runners[sessionID]
    p.mu.RUnlock()
    if !ok {
        return ErrSessionNotFound
    }
    return runner.Write([]byte(input + "\n"))
}

func (p *ClaudeProvider) StopSession(ctx context.Context, sessionID string) error {
    p.mu.Lock()
    runner, ok := p.runners[sessionID]
    if ok {
        delete(p.runners, sessionID)
    }
    p.mu.Unlock()
    if !ok {
        return ErrSessionNotFound
    }
    return runner.Stop()
}

func (p *ClaudeProvider) Events() <-chan ProviderEvent { return p.events }

func (p *ClaudeProvider) Capabilities() ProviderCapabilities {
    return ProviderCapabilities{
        Protocol:          "pty",
        SupportsResume:    false,
        SupportsFork:      false,
        SupportsInterrupt: true,
        SupportsPTY:       true,
        StreamingOutput:   true,
    }
}

func (p *ClaudeProvider) Close() error {
    p.mu.Lock()
    defer p.mu.Unlock()
    for _, r := range p.runners {
        r.Stop()
    }
    return nil
}
```

---

## 三、Aider Provider

```go
// internal/providers/aider/provider.go

type AiderProvider struct {
    runners map[string]*PTYRunner
    events  chan ProviderEvent
    mu      sync.RWMutex
}

func (p *AiderProvider) Name() string { return "aider" }

func (p *AiderProvider) Detect(ctx context.Context) (*ProviderInfo, error) {
    bin, err := exec.LookPath("aider")
    if err != nil {
        return nil, ErrNotInstalled
    }

    return &ProviderInfo{
        Name:    "aider",
        Version: getAiderVersion(bin),
        Binary:  bin,
        Status:  "available",
        RunMode: "pty",
        Capabilities: ProviderCapabilities{
            Protocol:          "pty",
            SupportsResume:    true,  // aider 支持 --restore
            SupportsFork:      false,
            SupportsInterrupt: true,
            SupportsPTY:       true,
            StructuredOutput:  false,
            StreamingOutput:   true,
        },
    }, nil
}

func (p *AiderProvider) CreateSession(ctx context.Context, req CreateSessionRequest) (*Session, error) {
    sessionID := uuid.New().String()

    args := []string{
        "--yes",           // 自动确认
        "--no-git",        // 不让 aider 管理 git（由 Agent 管理）
        "--no-auto-commits",
    }
    if req.Model != "" {
        args = append(args, "--model", req.Model)
    }
    args = append(args, "--file", ".") // 当前目录所有文件

    runner := NewPTYRunner()
    if err := runner.Start(ctx, CommandSpec{
        Bin:     "aider",
        Args:    args,
        Workdir: req.Workdir,
        UsePTY:  true,
    }); err != nil {
        return nil, err
    }

    p.mu.Lock()
    p.runners[sessionID] = runner
    p.mu.Unlock()

    if req.Prompt != "" {
        runner.Write([]byte(req.Prompt + "\n"))
    }

    go p.collectOutput(sessionID, runner)

    return &Session{
        ID:         sessionID,
        ProjectID:  req.ProjectID,
        Workdir:    req.Workdir,
        Status:     "running",
        RunnerType: "pty",
        Model:      req.Model,
    }, nil
}

// 其余方法与 ClaudeProvider 类似...
```

---

## 四、Provider 自动检测

```go
// 在 Agent 启动时自动检测已安装的 Provider

func (r *Registry) AutoDetect(ctx context.Context) {
    providers := []Provider{
        codex.New(cfg.Codex),
        claude.New(),
        aider.New(),
    }

    for _, p := range providers {
        info, err := p.Detect(ctx)
        if err != nil {
            log.Printf("provider %s not available: %v", p.Name(), err)
            continue
        }
        r.Register(p.Name(), p)
        log.Printf("provider %s detected: %s (%s)", info.Name, info.Version, info.RunMode)
    }
}
```

---

## 五、Flutter Provider 管理

### 5.1 Provider 列表

```dart
// features/settings/providers_page.dart

class ProvidersPage extends ConsumerWidget {
  // GET /api/providers
  // 显示：
  // - Provider 名称
  // - 版本
  // - 状态（available / unavailable）
  // - 运行模式（app-server / pty）
  // - 能力列表（resume/fork/interrupt/...）

  // 不可用的 Provider 显示安装提示
}
```

### 5.2 会话创建时选择 Provider

```dart
// 创建会话时，只显示可用的 Provider
// 每个 Provider 显示其支持的能力
// 不支持的功能对应的 UI 元素禁用
```

---

## 六、实施步骤

| 天 | 任务 |
|---|---|
| D1 | PTY Runner 实现 |
| D2 | Claude Provider 实现 |
| D3 | Aider Provider 实现 |
| D4 | Provider 自动检测 + 注册 |
| D5 | Provider API（列表/能力/模型） |
| D6-7 | Flutter：Provider 管理页面 + 创建会话 Provider 选择 |
| D8-9 | 联调测试多 Provider |
| D10 | Bug 修复 + 文档 |

---

## 七、验收标准

1. Agent 启动时自动检测已安装的 Provider
2. GET /api/providers 返回所有 Provider 状态和能力
3. 选择 Claude Provider 可创建会话，PTY 输出正常
4. 选择 Aider Provider 可创建会话，PTY 输出正常
5. 不可用的 Provider 在 Flutter 端显示为灰色 + 安装提示
6. 创建会话时，不支持的功能（如 resume）对应按钮禁用
