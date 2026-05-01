# Provider 统一语言改造方案

## 背景

Magent 当前已经有 `agent/internal/provider` 作为统一 provider 接口，但 session 状态、审批策略、沙箱模式、事件类型和部分字段仍以普通字符串在后端、App、本地缓存和具体 provider 之间流动。Codex app-server、Claude CLI、Aider CLI 的协议语言不同，导致当前代码里出现多处重复转换：

- Codex wire 参数：`onRequest`、`workspaceWrite`、`threadId`、`item/agentMessage/delta`。
- Magent API 字段：`approval_policy`、`sandbox_mode`、`provider_id`、`session.message_delta`。
- App 兼容字段：`provider` / `provider_id` / `modelProvider`、`active` / `running` / `{type: active}`。

这些转换有些是必要的 provider 边界适配，但目前部分 provider 私有语言已经泄漏到业务层和 App，后续接入 Claude、Aider 或更多 provider 时会继续放大。

## 目标

1. 建立 Magent 自身的 canonical provider language。
2. Provider 私有协议只允许出现在对应 provider adapter 内。
3. API、存储、同步和 App 只消费 Magent canonical 字段。
4. 新增 provider 时，只需要实现 provider adapter 的双向映射，不修改 App 或 session 业务逻辑。当前执行范围先聚焦 Codex 和现有功能，不继续扩展其他 provider。

## 当前状态

更新时间：2026-05-01。

按当前范围，阶段 1 到阶段 4 的核心边界已完成：

- 后端已新增 `agent/internal/provider/types.go`，集中定义 session 状态、审批策略、沙箱模式、事件类型和 item 类型。
- `provider.CreateSessionRequest.ApplyDefaults()` 已统一处理模型默认值和 canonical 化。
- Codex adapter 已拆出 `wire.go`、`events.go`、`config.go`，provider 私有枚举只保留在 adapter 内部和 adapter 测试中。
- AI commit suggest 已改为构造 canonical `provider.CreateSessionRequest`，Codex `thread/start` 与 `turn/start` 在 adapter 内分别转换成 app-server 要求的 wire enum。
- 后端 session store 会在读写时规范化 `status`、`approval_policy`、`sandbox_mode`。
- 后端 create session API 已以 `provider_id` 为 canonical 入参，短期兼容旧 `provider` 入参。
- App 已新增 `magent_app/lib/core/session/session_language.dart`，集中处理状态、审批、沙箱和事件语言；repository、session 列表和 chat 页只消费集中 helper 输出。
- Codex 历史事件和 item projection 已输出 canonical event/item。

仍保留的兼容点：

- 后端 DB sessions 表已迁移到 `approval_policy` 列；旧 `approval_mode` 列会在启动迁移时复制到新列并移除。
- App 本地缓存 schema 已升级到 6，旧 `session_entries.provider` 列已移除；repository 不再读取旧 `provider` 或 `approval_mode` 字段。
- App 仍在 `core/session/session_language.dart` 集中兼容 Codex 旧状态、审批和沙箱 wire 值，用于处理历史事件或 provider 边界输入。
- Claude/Aider 历史 item projection 不纳入当前计划范围，后续需要扩展 provider 时再单独规划。

## Canonical 语言

在 `agent/internal/provider/types.go` 中定义强类型常量。

### SessionStatus

- `running`
- `stopped`
- `completed`
- `failed`
- `lost`

### ApprovalPolicy

- `on-request`
- `on-failure`
- `never`
- `untrusted`
- `granular`

### SandboxMode

- `read-only`
- `workspace-write`
- `danger-full-access`

### EventType

- `session.started`
- `session.status_changed`
- `session.turn_started`
- `session.turn_completed`
- `session.turn_failed`
- `session.user_message`
- `session.message`
- `session.message_delta`
- `session.output`
- `session.plan`
- `session.plan_delta`
- `session.plan_updated`
- `session.reasoning`
- `session.reasoning_summary_delta`
- `session.reasoning_text_delta`
- `session.reasoning_summary_part`
- `session.diff_updated`
- `session.command_completed`
- `session.command_output_delta`
- `session.file_write`
- `session.file_read`
- `session.file_change_output_delta`
- `session.mcp_tool_completed`
- `session.approval_request`
- `session.approval_resolved`
- `session.error`
- `session.exited`
- `session.item_started`
- `session.item_completed`

### ItemType

- `user_message`
- `agent_message`
- `command_execution`
- `file_change`
- `file_read`
- `mcp_tool_call`
- `plan`
- `reasoning`
- `diff`

## 分层边界

### provider 包

职责：

- 定义 canonical 类型和常量。
- 提供 `NormalizeSessionStatus`、`NormalizeApprovalPolicy`、`NormalizeSandboxMode`、`NormalizeItemType` 等兼容输入函数。
- `CreateSessionRequest.ApplyDefaults()` 在进入具体 provider 前完成默认值和 canonical 化。

不应该：

- 包含 Codex 或其他 provider 的 wire 枚举。
- 暴露 provider 私有字段给 API 或 App。

### 具体 provider adapter

每个 provider 自己维护 wire 映射文件。当前计划只验收 Codex：

- `agent/internal/providers/codex/wire.go`
- `agent/internal/providers/codex/events.go`
- `agent/internal/providers/codex/config.go`

其他 provider 后续扩展时按同样结构补齐：

- `agent/internal/providers/claude/wire.go`
- `agent/internal/providers/claude/events.go`
- `agent/internal/providers/claude/config.go`
- `agent/internal/providers/aider/wire.go`
- `agent/internal/providers/aider/events.go`
- `agent/internal/providers/aider/config.go`

职责：

- Magent canonical -> provider wire。
- provider wire -> Magent canonical。
- Provider 事件转换成统一 `ProviderEvent`。
- Provider item 转换成统一 `SessionItem`。

示例：

- Codex `thread/start.sandbox` 使用 `workspace-write`。
- Codex `turn/start.sandboxPolicy.type` 使用 `workspaceWrite`。
- Claude/Aider 不纳入当前执行范围。

### session / api / sync

职责：

- 只读写 canonical 字段。
- API DTO 固定输入/输出 `provider_id`、`status`、`approval_policy`、`sandbox_mode`。
- 不再猜测 `modelProvider`、`active`、`notLoaded` 等 provider 私有值。

### App

职责：

- 只消费 API canonical 字段。
- 本地 DB 字段保持 canonical。
- provider 私有状态、审批和沙箱兼容只允许集中放在 `core/session/session_language.dart`。
- UI 文案层负责显示中文标签，不参与协议转换。

## 迁移步骤

### 阶段 1：后端类型收敛

状态：已完成。

1. 已新增 `agent/internal/provider/types.go`。
2. 已将 session control plane 的状态、审批和沙箱字段收敛到 typed constants。
3. 已在 `provider.CreateSessionRequest` 增加 `ApplyDefaults(config ProviderConfig)`。
4. Codex adapter 保留兼容输入，但出站只通过 `codexApprovalPolicy()`、`codexThreadSandboxMode()`、`sandboxPolicyObject()`。

### 阶段 2：事件和 item 收敛

状态：按 Codex 和现有功能范围已完成。

1. 已将 Codex `handleNotification` 中的事件映射拆到 `codex/events.go`。
2. 已为 Codex provider event 映射增加测试。
3. Codex 历史 turns 已转为 canonical events/items。

### 阶段 3：API 和 App 收敛

状态：已完成主路径，App 本地缓存旧字段已清理。

1. 后端 session API 已以 canonical 字段输出；create session 以 `provider_id` 为 canonical 入参，并兼容旧 `provider`。
2. App API 创建会话已发送 `provider_id`，不再发送旧 `provider` 字段。
3. App repository 常规 DB/API map 输出只使用 `provider_id`、`approval_policy`、`sandbox_mode`。
4. App 本地缓存 schema 已升级到 6，移除旧 `session_entries.provider` 列。
5. App 状态、审批、沙箱、事件和 item 的兼容/显示集中到 `core/session/session_language.dart`。

### 阶段 4：新增 provider 接入规范

状态：规范已落地，当前不继续扩展其他 provider。

新增 provider 必须提供：

1. `wire.go`：枚举和参数映射。
2. `events.go`：事件映射。
3. `config.go`：provider config 转 canonical config。
4. `*_test.go`：覆盖参数映射、状态映射、事件映射。

## 验收标准

- `rg "['\"](workspaceWrite|onRequest|modelProvider|dangerFullAccess|readOnly|unlessTrusted|notLoaded|systemError)['\"]" agent/internal/session agent/internal/api magent_app/lib` 只允许命中：
  - `magent_app/lib/core/session/session_language.dart` 的集中兼容逻辑。
  - `agent/internal/session/*_test.go` 的旧值兼容测试。
- `agent/internal/providers/*` 之外不出现 provider wire 枚举。
- App session 列表和 chat 页不再各自实现多套字段 fallback。
- Codex 能通过 create session API 创建会话，并在 adapter 内完成 wire enum 转换。
- AI commit suggest 使用同一套 canonical request，不再因 provider wire enum 变化报错。

已运行验证：

- `cd agent && go test ./internal/providers/codex`
- `cd agent && go test ./internal/provider ./internal/session`
- `cd agent && go test ./internal/session ./internal/api`
- `cd agent && go test ./internal/storage ./internal/session`
- `cd agent && go test ./...`
- `cd magent_app && flutter test`
- `cd magent_app && flutter analyze`
- `cd magent_app && dart run build_runner build --delete-conflicting-outputs`

当前范围结论：

- Codex 和现有功能的 provider canonical language 计划已完成。
- Claude/Aider 等其他 provider 暂不扩展，后续如重新纳入范围，需要另开 provider 接入计划。
