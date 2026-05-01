# Phase 2 完成对账

## 状态：已完成

## 已完成内容

### Provider 接口定义（`agent/internal/provider/`）

- [x] `provider.go` - Provider 接口定义
  - CreateSession / ResumeSession / ForkSession
  - SendInput / InterruptSession / StopSession
  - Subscribe / Unsubscribe（per-session 事件通道）
  - Capabilities

- [x] `registry.go` - Provider 注册表
  - Register / Get / List

### JSON-RPC 2.0 协议（`agent/internal/protocol/`）

- [x] `jsonrpc.go` - 协议定义
  - JSONRPCRequest / JSONRPCResponse / JSONRPCError
  - RequestIDGenerator

### Codex App Server 客户端（`agent/internal/codex/`）

- [x] `appserver_client.go` - App Server 客户端
  - stdio 模式
  - Initialize 握手
  - StartThread / StartTurn / SteerTurn / InterruptTurn
  - ListModels / ReadConfig / ListMCPServers
  - 事件读取循环

- [x] `event_mapper.go` - 事件映射
  - Codex 通知 → ProviderEvent 映射
  - 支持：message, command, file_write, file_read, mcp_tool, approval_request

- [x] `approval_proxy.go` - 审批代理
  - 规则匹配
  - 转发到手机
  - acceptForSession 支持
  - 120s 超时

- [x] `provider.go` - Codex Provider 实现
  - Detect（检测 codex 二进制）
  - CreateSession（完整流程）
  - forwardEvents（事件转发）
  - per-session 事件通道

### Session Manager（`agent/internal/session/`）

- [x] `store.go` - Session 存储
  - Save / Get / ListByProject / GetActiveSessions
  - Update / UpdateStatus
  - SaveEvent / GetEventsAfterSeq

- [x] `manager.go` - Session 管理器
  - CreateSession（创建会话 + 持久化 + 订阅事件）
  - collectEvents（事件收集 + 持久化 + 广播）
  - ListSessions / GetSession / StopSession
  - SendInput / InterruptSession / ForkSession
  - Recover（断线恢复）

### Config Service（`agent/internal/sync/`）

- [x] `bootstrap.go` - 配置同步服务
  - Check（轻量 hash 检查）
  - Bootstrap（全量拉取，支持 local_hash 对比）
  - 缓存机制（内存 + SQLite）
  - Provider 配置 Schema

### HTTP API

- [x] `session_handler.go` - Session API
  - POST /api/sessions
  - GET /api/sessions/:id
  - GET /api/sessions?project_id=xxx
  - POST /api/sessions/:id/input
  - POST /api/sessions/:id/interrupt
  - POST /api/sessions/:id/stop
  - POST /api/sessions/:id/fork
  - GET /api/sessions/:id/events

- [x] `sync_handler.go` - Sync API
  - GET /api/sync/check
  - GET /api/sync/bootstrap

### Flutter App（`magent_app/`）

- [x] `core/api/session_api.dart` - Session API 客户端
  - createSession / getSession / listSessions
  - sendInput / interrupt / stop / fork
  - getEvents / approve

- [x] `core/sync/bootstrap_sync.dart` - 配置同步
  - BootstrapData 模型
  - BootstrapSync 服务（check + bootstrap）
  - 动态配置查询（模型列表、审批策略、沙箱模式）

- [x] `features/sessions/create/session_create_page.dart` - 会话创建页面
  - Provider 选择
  - 模型选择（动态）
  - 审批策略选择
  - 沙箱模式选择
  - Prompt 输入
  - 快捷预设按钮

- [x] `features/sessions/chat/chat_page.dart` - 会话聊天页面
  - 事件列表渲染
  - 消息气泡（Markdown 渲染）
  - 工具调用卡片（命令、文件操作）
  - 审批对话框
  - 错误卡片
  - 输入栏 + 快捷按钮

## 编译状态

- Go Agent：通过
- Flutter App：通过（flutter analyze 无错误）

## 验收标准

1. 可通过 App Server 协议创建 Codex 会话
2. AI 输出实时显示在手机端
3. Codex 执行命令时，审批请求正确推送到手机
4. 关闭手机 App 后重连，可恢复之前的会话输出
5. Agent 重启后，可恢复之前的会话
6. 会话事件按 seq 持久化，支持增量获取
