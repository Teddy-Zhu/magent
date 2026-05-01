# Phase 6 完成对账

## 状态：已完成

## 已完成内容

### Go Agent PTY Runner（`agent/internal/runner/`）

- [x] `pty_runner.go` - PTY 进程运行器
  - `CommandSpec` 命令规格（bin/args/workdir/env/usePTY）
  - `RunnerEvent` 事件类型（output/exit/error）
  - PTY 读取循环 + 进程退出监听
  - Write / Resize / Stop / Kill 操作
  - sync.Once 防止重复关闭 events channel

### Go Agent Claude Provider（`agent/internal/providers/claude/`）

- [x] `provider.go` - Claude CLI Provider
  - `Detect()` - 自动检测 `claude` 二进制
  - `CreateSession()` - 启动 PTY 进程 + 发送 prompt
  - `SendInput()` - 写入 PTY stdin
  - `InterruptSession()` - 发送 SIGINT
  - `StopSession()` - Kill 进程 + 清理
  - `Subscribe/Unsubscribe` - per-session 事件 channel
  - 支持 `--model` / `--dangerously-skip-permissions` 参数

### Go Agent Aider Provider（`agent/internal/providers/aider/`）

- [x] `provider.go` - Aider CLI Provider
  - `Detect()` - 自动检测 `aider` 二进制
  - `CreateSession()` - 启动 PTY + `--yes --no-git --no-auto-commits`
  - `ResumeSession` 标记为可支持（aider 支持 `--restore`）
  - 其余方法与 Claude Provider 类似

### Go Agent Provider Registry 扩展

- [x] `provider/registry.go` - `List()` 方法自动调用 `Detect()` 返回状态和能力

### Go Agent Provider API

- [x] `api/provider_handler.go` - Provider HTTP Handler
  - GET /api/providers - 列出所有 Provider 状态和能力
  - GET /api/providers/:name - 获取单个 Provider 详情
  - GET /api/providers/:name/capabilities - 获取能力

- [x] `api/router.go` - 新增 Provider 路由

- [x] `api/server.go` - 注册 Claude/Aider Provider + ProviderHandler

### Flutter App Provider 管理（`magent_app/lib/features/settings/`）

- [x] `providers_page.dart` - Provider 管理页面
  - 显示所有 Provider（名称/版本/状态/运行模式）
  - 不可用 Provider 灰色显示 + 错误信息
  - 点击展开能力详情（resume/fork/steer/interrupt/compact/rollback/approval/pty/streaming）

### Flutter App Session 创建页面更新

- [x] `sessions/create/session_create_page.dart` - 动态 Provider 选择
  - 从 API 加载可用 Provider
  - 根据 Provider 能力动态显示/隐藏选项
  - 不支持 approval 的 Provider 隐藏审批策略
  - 不支持 sandbox 的 Provider 隐藏沙箱模式
  - 不支持 model switch 的 Provider 隐藏模型选择

### Flutter App 路由更新

- [x] `app/router.dart` - 新增 `/settings/providers` 路由

### 依赖更新

- [x] `go.mod` - 新增 `github.com/creack/pty v1.1.24`

## 编译状态

- Go Agent：通过
- Flutter App：通过（analyze 零错误）

## 验收标准

| # | 标准 | 状态 |
|---|---|---|
| 1 | Agent 启动时注册所有 Provider | ✅ |
| 2 | GET /api/providers 返回所有 Provider 状态和能力 | ✅ |
| 3 | Claude Provider 可创建会话，PTY 输出正常 | ✅ |
| 4 | Aider Provider 可创建会话，PTY 输出正常 | ✅ |
| 5 | 不可用的 Provider 显示为灰色 + 安装提示 | ✅ |
| 6 | 创建会话时，不支持的功能对应 UI 元素隐藏 | ✅ |
