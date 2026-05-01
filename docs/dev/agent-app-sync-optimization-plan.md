# Agent/App 同步与 Codex 控制优化计划

日期：2026-05-01

## 前提

本计划基于 `docs/dev/agent-app-sync-gap-analysis.md`。这里假设不需要兼容旧 API、旧 Drift schema、旧本地缓存、旧 session 事件格式，可以做破坏式重构，以获得最稳定、低流量、易维护的实现。

目标不是在现有实现上打补丁，而是把 Agent/App 通信层、事件模型、本地缓存模型和 Codex app-server 适配层整理成一套明确协议。

## 优化目标

1. App 端任何页面都先用本地 DB 展示，再做低流量同步。
2. Agent 端保持轻量，只做协议适配、短期实时缓冲、权限校验、低流量 API 和实时转发。
3. Codex 是第一优先 Provider，使用 app-server stdio 原生协议，不走 PTY。
4. 所有动态数据都有可靠增量机制：bootstrap 用 ETag/hash，session 以 Provider cursor/revision 为准，实时通道用 runtime cursor，Git/File 用实时 hash/version。
5. HTTP 与 WebSocket 使用同一种事件结构，避免两套字段映射。
6. 断线恢复必须可靠：App 断线期间 Codex 继续运行，重连后按 provider cursor 或 Provider-backed items/events 校准。
7. 审批必须闭环：Codex server request 到 App，App 决策回 Agent，Agent 按 Codex schema 响应。

## 总体方案

### 架构改造

推荐重构为四层：

```text
Flutter UI
  -> Repository/Sync Engine
  -> Local Drift Cache
  -> ApiClient + WsClient

Go HTTP/WS API
  -> Sync/Event/Session/Git/File Services
  -> SQLite control-plane metadata
  -> Provider adapters

CodexProvider
  -> CodexAppServerSupervisor
  -> JSON-RPC typed client
  -> event mapper + approval bridge

Local tools
  -> codex app-server
  -> git CLI
  -> filesystem
```

关键变化：

- Agent 内部只保存控制面状态：项目、Provider 配置快照、session 与 provider thread 的映射、pending approval。Session 内容、Git 状态、文件内容不作为 Agent DB 事实缓存。
- App 内部以 `SyncEngine` 为中心，所有 HTTP/WS 数据先写 Drift，再驱动 UI。
- Provider 不再让多个消费者抢同一个 channel，统一由 provider adapter 推送到 Agent event bus。
- Codex app-server 客户端使用强类型请求/响应和 schema 校验，不再直接传 map。

### API 策略

由于不考虑兼容性，建议引入新 API 根路径：

```text
/api/v1
```

旧 `/api/*` 可以直接删除或临时保留给开发调试，但 App 只接新 API。这样能避免旧字段如 `known_count`、`payload/timestamp`、`local_hash` 继续污染实现。

统一 HTTP 规则：

- 成功响应：`{"data": ...}`。
- 业务错误：`{"error":{"code":"...","message":"..."}}`。
- 缓存命中：HTTP 304，无 body。
- 所有 cacheable endpoint 支持 `ETag` 与 `If-None-Match`。
- JSON body 内也保留 `hash`/`revision`，方便 App 入库。

## 事实来源与缓存边界

本计划明确区分“事实来源”和“缓存/索引”。Agent DB 不作为 session、Git、File 的最终事实来源。

| 数据 | 事实来源 | Agent 侧 | App 侧 |
|---|---|---|---|
| Provider/模型/配置 | Provider/Codex config | 保存 bootstrap 快照和 hash，用于低流量启动 | 缓存 bootstrap |
| Project 配置 | Agent 自身配置 | 保存 | 缓存 |
| Session/thread/status/history | Provider，Codex 以 app-server thread/turn/item 为准 | 只保存 session 映射、创建参数、pending approval、最后观测状态；实时事件只放内存 ring buffer | 缓存 session 列表、items、events |
| Git summary/changes/diff | 实际 `.git` 和工作区 | 每次从真实 Git 计算；只允许短期内存 diff LRU | 缓存展示数据，用 hash/version 校验 |
| File/dir/blob | 实际文件系统 | 每次从真实文件系统计算 hash/range；不持久缓存内容 | 缓存 dir/file 内容，用 ETag 校验 |
| Approval | Codex server request | 必须保存 pending 映射直到 resolved/timeout | 缓存 UI 状态 |

因此：

- Agent 不持久化完整 `session_events`、`session_items`、Git file changes、文件内容。
- Agent 可以保留很小的内存 ring buffer，用于 WebSocket 短断线补发；Agent 重启后 App 应回退到 Provider-backed sync。
- App DB 是主要展示缓存；所有缓存都必须带 hash/cursor/revision 校验，不能脱离事实来源长期自信。

## 目标数据模型

### Agent SQLite

重建迁移，不保留旧表兼容。

```sql
projects(
  id text primary key,
  name text not null,
  path text not null,
  default_provider text not null,
  revision integer not null,
  created_at integer not null,
  updated_at integer not null,
  deleted_at integer
);

providers(
  name text primary key,
  status text not null,
  version text,
  run_mode text,
  capabilities_json text not null,
  config_json text not null,
  revision integer not null,
  updated_at integer not null
);

sessions(
  id text primary key,
  provider_id text not null,
  thread_id text not null,
  project_id text not null,
  title text,
  workdir text not null,
  last_status text,
  model text,
  effort text,
  approval_policy text,
  sandbox_mode text,
  list_revision integer not null,
  created_at integer not null,
  updated_at integer not null,
  archived_at integer,
  deleted_at integer
);

pending_approvals(
  approval_id text primary key,
  session_id text not null,
  thread_id text not null,
  turn_id text,
  item_id text,
  codex_request_id integer not null,
  type text not null,
  request_json text not null,
  status text not null,
  created_at integer not null,
  resolved_at integer
);

sync_scopes(
  scope text primary key,
  hash text not null,
  revision integer not null,
  data_json text,
  updated_at integer not null
);
```

Agent DB 不保存完整 session 事件日志、session 内容投影、Git 状态、Git diff、文件内容。Session 内容和状态从 Provider 读取并转发；DB 中的 `last_status` 只能作为最后观测值。Git/File 每次从真实工作区读取。若需要优化热点 diff 或短断线事件，可以使用进程内 LRU/ring buffer，不能把这类缓存当作重启后仍可信的数据源。

### App Drift

App 本地 DB 必须带 `agent_id`。不兼容旧 schema，直接提升 schemaVersion 并 destructive migration。

```text
agents(id, name, url, created_at, updated_at)
sync_state(agent_id, scope, key, hash, revision, cursor, updated_at)
projects(agent_id, id, name, path, default_provider, revision, updated_at, deleted_at)
providers(agent_id, name, status, version, run_mode, capabilities_json, config_json, revision, updated_at)
sessions(agent_id, id, project_id, provider_id, thread_id, title, workdir, status, model, effort, approval_policy, sandbox_mode, provider_cursor, list_revision, created_at, updated_at, archived_at, deleted_at)
session_events(agent_id, session_id, local_seq, provider_cursor, type, item_id, turn_id, payload_json, created_at)
session_items(agent_id, session_id, item_id, turn_id, type, status, role, summary, content_json, revision, created_at, updated_at)
pending_approvals(agent_id, approval_id, session_id, item_id, type, request_json, status, created_at, resolved_at)
git_state(agent_id, project_id, version, summary_json, changed_hash, updated_at)
git_file_changes(agent_id, project_id, version, path, staged, status, additions, deletions, binary, diff_hash, meta_json)
dir_cache(agent_id, project_id, path, hash, items_json, updated_at)
file_cache(agent_id, project_id, path, hash, range_key, encoding, content, updated_at)
```

Token 仍放 secure storage，但 Agent 基础信息放 Drift，避免多 Agent 缓存串数据。

## 新协议设计

### Bootstrap

```http
GET /api/v1/bootstrap
If-None-Match: "<bootstrap_hash>"
```

200：

```json
{
  "data": {
    "hash": "sha256:...",
    "revision": 42,
    "agent": {
      "version": "0.1.0",
      "capabilities": {
        "websocket": true,
        "compression": ["gzip"],
        "api_version": "v1"
      }
    },
    "providers": [],
    "projects": [],
    "workspace": {}
  }
}
```

304：本地缓存有效。

hash 计算规则：

- 使用 canonical JSON。
- 覆盖 agent capabilities、providers 完整配置、projects 静态字段、workspace 配置。
- 排除 `updated_at` 这类纯时间字段。
- provider detect/config 或 project 变更后同步更新 `sync_scopes.bootstrap`。

### Session 列表

列表静态字段和动态状态分离。静态字段走 revision/hash，动态状态通过 WS 实时更新。

```http
GET /api/v1/projects/:project_id/sessions/changes?after_revision=100&limit=200
```

```json
{
  "data": {
    "project_id": "p1",
    "from_revision": 101,
    "to_revision": 118,
    "has_more": false,
    "upserts": [
      {
        "id": "thr_...",
        "provider_id": "codex",
        "thread_id": "thr_...",
        "title": "...",
        "workdir": "...",
        "model": "gpt-5.4",
        "status": "idle",
        "provider_cursor": "opaque-provider-cursor-or-null",
        "list_revision": 118,
        "created_at": 1710000000,
        "updated_at": 1710000200
      }
    ],
    "deletes": []
  }
}
```

首次同步使用 `after_revision=0`。

### Session 事件

Session 事件的事实来源是 Provider。Agent 不持久保存完整事件日志，只做协议适配、短期内存 ring buffer 和 provider cursor 转换。App 本地仍然可以用自己的 `local_seq` 保存展示缓存，但该 `local_seq` 是 App 本地排序序号，不代表 Provider 的事实状态。

```http
GET /api/v1/sessions/:session_id/events?cursor=<provider_or_agent_cursor>&limit=500
```

```json
{
  "data": {
    "session_id": "thr_...",
    "cursor": "next-cursor",
    "has_more": false,
    "events": [
      {
        "type": "item.agent_message.delta",
        "item_id": "item_...",
        "turn_id": "turn_...",
        "data": {"delta": "..."},
        "created_at": 1710000201
      }
    ]
  }
}
```

### Session items

聊天历史和工具调用展示以 App 本地 `session_items` projection 为主，避免 UI 每次重放大量 delta。Agent 可以从 Codex `thread/turns/list` 或实时事件生成本次响应，但不持久保存 `session_items`。

```http
GET /api/v1/sessions/:session_id/items?cursor=<provider_cursor>&limit=200
```

```json
{
  "data": {
    "session_id": "thr_...",
    "cursor": "next-cursor",
    "has_more": false,
    "items": [
      {
        "item_id": "item_...",
        "type": "agent_message",
        "status": "completed",
        "content": {"text": "..."},
        "updated_at": 1710000210
      }
    ]
  }
}
```

UI 默认读取 App Drift 的 `session_items`。事件流只用于实时更新和本地缓存增量；当 App 怀疑缓存不一致时，重新从 Provider-backed items API 校准。

### WebSocket

连接：

```text
GET /api/v1/ws
Authorization: Bearer <token>
```

客户端第一条消息：

```json
{
  "type": "client.hello",
  "open_sessions": [
    {"session_id": "thr_...", "cursor": "last-provider-or-agent-cursor"}
  ]
}
```

服务端事件：

```json
{
  "type": "session.event",
  "session_id": "thr_...",
  "cursor": "provider-or-adapter-item-cursor",
  "ws_seq": 1024,
  "ws_cursor": "1024",
  "event_type": "item.agent_message.delta",
  "item_id": "item_...",
  "turn_id": "turn_...",
  "data": {},
  "created_at": 1710000201
}
```

```json
{
  "type": "session.item_changed",
  "session_id": "thr_...",
  "item": {}
}
```

```json
{
  "type": "session.status_changed",
  "session_id": "thr_...",
  "status": "active",
  "updated_at": 1710000201
}
```

WebSocket 不作为唯一可靠通道。短断线可以用 Agent 内存 ring buffer 补发；长断线或 Agent 重启后通过 Provider-backed HTTP sync 校准。

### 审批

服务端下发：

```json
{
  "type": "approval.requested",
  "approval_id": "appr_...",
  "session_id": "thr_...",
  "thread_id": "thr_...",
  "turn_id": "turn_...",
  "item_id": "item_...",
  "approval_type": "command_execution",
  "available_decisions": ["accept", "decline", "cancel"],
  "request": {
    "command": "...",
    "cwd": "...",
    "reason": "...",
    "networkApprovalContext": null,
    "additionalPermissions": []
  },
  "created_at": 1710000201
}
```

App 响应：

```http
POST /api/v1/sessions/:session_id/approvals/:approval_id
```

```json
{
  "decision": "accept"
}
```

或：

```json
{
  "decision": {
    "acceptWithExecpolicyAmendment": {
      "execpolicy_amendment": ["cmd", "..."]
    }
  }
}
```

Agent 内部用 `approval_id -> codex_request_id` 映射，响应 Codex JSON-RPC 后写入 `pending_approvals.status=resolved`，并广播：

```json
{"type":"approval.resolved","approval_id":"appr_...","decision":"accept"}
```

### Git

Git 的事实来源永远是实际 `.git` 和工作区。Agent 不持久保存 `git_state` 或 `git_file_changes`，每次请求都从真实 Git 计算当前 summary/version/hash。App 端可以缓存展示结果，但必须带 `base_version` 或 ETag 校验。

```http
GET /api/v1/projects/:project_id/git/summary
If-None-Match: "<git_state_hash>"
```

```http
GET /api/v1/projects/:project_id/git/changes?base_version=12
```

base version 命中时返回 304；变化时返回：

```json
{
  "data": {
    "version": 13,
    "summary": {},
    "files": [
      {
        "path": "lib/main.dart",
        "status": "modified",
        "staged": false,
        "additions": 10,
        "deletions": 2,
        "diff_hash": "sha256:..."
      }
    ]
  }
}
```

`diff_hash` 必须由真实 diff 内容 hash 生成。`GET /git/diffs/:diff_hash?offset=&limit=` 不信任客户端 path/hash 组合。Agent 可用进程内 LRU 缓存热点 diff，但缓存 miss 时必须重新从真实 Git 计算并校验 hash。

### Files

File/dir/blob 的事实来源永远是实际文件系统。Agent 不持久保存文件内容或目录树，只计算 hash/range 并返回给 App；App 端负责缓存展示内容。

所有文件 API 使用 project root resolver，禁止绕过校验。

```http
GET /api/v1/projects/:project_id/files/dir?path=lib
If-None-Match: "<dir_hash>"
```

```http
GET /api/v1/projects/:project_id/files/content?path=lib/main.dart&offset=0&limit=1000&unit=line
If-None-Match: "<file_hash>"
```

```http
GET /api/v1/projects/:project_id/files/blob?path=assets/a.png&offset=0&limit=65536
```

文件读取规则：

- 文本默认 line range。
- 二进制默认 byte range。
- 大文件必须分页。
- 响应包含 `hash`、`size`、`encoding`、`offset`、`limit`、`has_more`。

## Codex Provider 最佳实现

### AppServerSupervisor

将当前“每个 session 一个 codex app-server 进程”改为“每个 Agent/CodexProvider 一个 supervisor 管理的 app-server 进程”。

职责：

- 启动 `codex app-server`。
- 完成一次 `initialize`/`initialized`。
- 管理 JSON-RPC pending requests。
- 处理 server-initiated requests。
- 根据 `threadId` 路由 notifications。
- 进程崩溃后重启，标记 loaded session 为 `not_loaded`，由用户或自动策略 resume。

好处：

- 减少进程数量和资源消耗。
- thread/list、thread/read、model/list、skills/list 等共享一个连接。
- 事件路由集中，便于 Provider-backed 恢复、短断线补发和审批映射。

### Typed Codex Client

删除散落的 `map[string]any`，改为 typed structs：

- `InitializeRequest/Response`
- `ThreadStartRequest/Response`
- `TurnStartRequest/Response`
- `ThreadListRequest/Response`
- `ThreadReadRequest/Response`
- `TurnEvent`
- `ItemEvent`
- `ApprovalRequest/Decision`

Codex 枚举在 provider 边界转换：

```text
App public enum        Codex enum
on-request        ->  onRequest
untrusted         ->  unlessTrusted
never             ->  never
workspace-write   ->  workspaceWrite
read-only         ->  readOnly
danger-full-access -> dangerFullAccess
```

以 `docs/extra/codex_appserver.html` 和 `codex app-server generate-json-schema` 作为准入标准。生成 schema 可以放入 `agent/internal/providers/codex/schema/`，CI 中做基本校验。

### Event Mapper

Codex notification 全量映射到统一事件类型：

```text
thread.started
thread.status_changed
thread.name_updated
turn.started
turn.completed
turn.failed
turn.diff_updated
turn.plan_updated
item.started
item.completed
item.agent_message.delta
item.plan.delta
item.reasoning.summary_delta
item.command.output_delta
item.file_change.output_delta
approval.requested
approval.resolved
```

映射原则：

- 永远保留 raw payload 到 `payload_json`。
- Agent 实时响应中返回标准事件结构，但不把 item projection 持久化到 Agent DB。
- App 负责把 delta 合并进本地 `session_items` projection。
- `item/completed` 是权威最终状态，App 收到后覆盖本地 projection。
- Agent 如需支持短断线重放，只使用进程内 ring buffer；重启后回到 Provider-backed 历史读取。

## App 最佳实现

### SyncEngine

新增全局 `SyncEngine`，它是 App 唯一的同步入口：

```text
SyncEngine
  - bootstrap()
  - syncProjects()
  - syncProviders()
  - syncSessionList(projectId)
  - syncSessionEvents(sessionId)
  - syncSessionItems(sessionId)
  - syncGit(projectId)
  - syncDir(projectId, path)
  - syncFile(projectId, path, range)
```

UI 不直接调用 Dio。页面只读 repository/provider 暴露的 Drift stream：

- `watchProjects(agentId)`
- `watchSessions(projectId)`
- `watchSessionItems(sessionId)`
- `watchPendingApprovals(sessionId)`
- `watchGitChanges(projectId)`
- `watchDir(projectId, path)`

这样可以保证 UI 行为一致：先本地、后同步、实时更新。

### WebSocket lifecycle

App 激活 Agent 后创建一个全局 WS：

- app foreground 时连接。
- background 时可断开，但记录最后 provider cursor / runtime cursor。
- 重连后发送 `client.hello`。
- 收到事件后事务写 Drift。
- 若发现 cursor gap 或长时间断线，立即调用 Provider-backed HTTP sync 校准。

### Cache policy

App 本地缓存策略：

- bootstrap/provider/project：永久缓存，靠 hash/revision 更新。
- session events/items：作为 App 展示缓存，可提供手动清理；以 Provider 返回的 cursor/items 校准。
- Git state/diff：仅 App 侧按 project 缓存，可清理；Agent 不持久保存。
- File/dir cache：LRU + 最大容量，保留 hash。

## 实施计划

### Phase 0：破坏式协议和 schema 重置

目标：建立新 API/DB 基线，不再背旧实现。

任务：

- Agent 新增 `/api/v1` route group。
- 删除或停止 App 使用旧 `/api/*`。
- 重建 Agent SQLite migration。
- 重建 App Drift schema，schemaVersion 提升并 destructive migration。
- 定义共享 API/event JSON 文档。
- 统一时间戳：全部使用 Unix seconds 或 milliseconds，推荐 milliseconds。

验收：

- App 能连接 Agent，bootstrap 入库。
- 多 Agent 切换后缓存隔离。
- 旧 `known_count`、旧 `payload/timestamp`、旧 `/api/sessions/approve` 不再被 App 使用。

### Phase 1：session 控制面与 Provider-backed 增量

目标：先修最核心的会话可靠性，同时避免 Agent 把 session 内容缓存成事实来源。

Agent 任务：

- 修复 session metadata 写入，只保存 `project_id/provider_id/thread_id/workdir/model/effort/approval/sandbox/last_status` 等控制面字段。
- 实现 Provider-backed `/sessions/:id/events?cursor=&limit=`，优先读 Codex `thread/turns/list` 或实时 ring buffer，不依赖 Agent DB 历史。
- 实现 Provider-backed `/sessions/:id/items?cursor=&limit=`，Agent 只在响应期做转换，不持久化 item projection。
- `SessionManager` 标准化 provider event 后通过 WS 广播；短断线事件进入内存 ring buffer。
- 明确 Agent 重启后的恢复策略：通过 Provider `thread/list`/`thread/resume`/`turns/list` 重新同步。

App 任务：

- 实现 `SessionRepository` 新模型。
- ChatPage 改为 watch `session_items`。
- App 负责把事件 delta 合并成本地 `session_items`。
- 发送用户输入时先写 pending local item，服务端确认或 Provider items 校准后更新。

验收：

- 新建 session、发送消息、停止/恢复都能正确更新 DB。
- App 短断线后可由 ring buffer 补齐；长断线或 Agent 重启后可从 Provider items 校准。
- ChatPage 刷新不会重复插入消息。

### Phase 2：Codex supervisor、typed client、完整事件映射

目标：把 Codex app-server 适配层做稳定。

任务：

- 实现 `CodexAppServerSupervisor`。
- 将 `AppServerClient` 改为 typed JSON-RPC client。
- 实现 Codex enum 映射。
- 完整映射 turn/item/delta/plan/reasoning/command/file/MCP events。
- 使用 `thread/turns/list` 做历史分页，不再用 `thread/read includeTurns` 全量作为常规路径。
- 实现 `thread/fork`、`thread/compact/start`、`thread/rollback`。

验收：

- 一个 Codex app-server 进程可管理多个 session。
- 活跃 turn 的 delta 实时写入 App 本地 item projection；Agent 只转发和短期缓冲。
- 停止 Agent 后重启，可以 list/resume 既有 Codex thread。
- fork/compact/rollback 至少有 API 和基础 UI 入口。

### Phase 3：审批闭环

目标：命令、文件变更、MCP/connector 审批可用。

Agent 任务：

- 实现 `ApprovalService`。
- server-initiated JSON-RPC request 生成 `approval_id` 并写 `pending_approvals`。
- WS 广播 `approval.requested`。
- HTTP `POST /sessions/:id/approvals/:approval_id` 和 WS `approval.resolve` 都能 resolve。
- 按 Codex schema 响应 decision。
- 超时、断线、重复响应、turn 结束清理都要处理。

App 任务：

- Drift 保存 pending approval。
- ChatPage 或全局 overlay 展示审批。
- 支持 `accept`、`acceptForSession`、`decline`、`cancel`。
- 命令审批展示 command/cwd/reason/network/additionalPermissions。
- 文件审批展示 path/grantRoot/diff 摘要。

验收：

- Codex 请求 shell approval 时，App 能允许/拒绝并影响 turn 结果。
- 审批已处理后 UI 自动消失。
- App 断线时审批超时后 Codex 不会永久卡住。

### Phase 4：Bootstrap、Provider、Project 增量同步

目标：启动低流量同步可用。

Agent 任务：

- 实现 `BootstrapService` canonical hash。
- Provider detect/config/model/skills/app/MCP 变更时刷新 bootstrap scope。
- Project create/update/delete bump revision。
- `/bootstrap` 支持 ETag/304。
- `/projects/changes?after_revision=` 可选实现，或 bootstrap 中全量项目足够小则先保留在 bootstrap。

App 任务：

- Agent connect 成功后立即 bootstrap。
- `ProjectListPage` 只读 Drift，并触发 SyncEngine 后台同步。
- Provider settings/create session 页面只读本地 provider config，必要时触发刷新。

验收：

- 无变化时连接 Agent 只返回 304。
- Provider model 或 project 变更后 hash 必变。
- 启动 App 离线时仍能看到上次缓存的 projects/providers。

### Phase 5：WebSocket 全局接入

目标：App 不再依赖手动刷新获取实时变化。

Agent 任务：

- WS 支持 `client.hello`、`session.subscribe`、`session.unsubscribe`。
- 根据 token 做连接上限和权限校验。
- 广播 session events/status/items/git invalidation/approval。Git/File 只推送 invalidation，不推送缓存事实。
- 支持 ping/pong、写队列满时断开并要求客户端 HTTP catch-up。

App 任务：

- 全局 `WsConnectionProvider`。
- 重连 backoff。
- cursor gap/断线校准检测。
- foreground/background 生命周期处理。

验收：

- Codex 输出时 ChatPage 实时更新。
- Git 变化时项目页状态自动刷新。
- WS 短断线后可补发；长断线或 Agent 重启后可通过 Provider-backed HTTP sync 校准。

### Phase 6：Git 低流量和操作完整性

目标：Git 页面稳定、低流量、操作安全。

Agent 任务：

- 使用 `git status --porcelain=v2 -z --branch` 解析 summary。
- version/hash 覆盖 staged、unstaged、untracked、branch、ahead/behind。
- diff_hash 基于真实 diff 内容。
- diff cache 只做进程内 LRU，保存结构化 lines JSON，不写 Agent DB，不作为事实来源。
- untracked 文件提供 synthetic diff。
- 实现 pull。
- force push 使用 request body `confirm_force=true`，不依赖额外 header。
- discard 支持 untracked 删除，必须显式确认。
- 启动 GitWatcher，WS 只推送 `git.invalidated`，App 收到后重新请求真实 Git summary/changes。

App 任务：

- `ProjectChangesTab` 使用本地 git cache。
- 请求 changes 带 `base_version`。
- DiffSheet 支持分页加载更多。
- Pull/push/stage/unstage/discard 后不把本地缓存当真，优先等 `git.invalidated` 或主动拉真实 summary。

验收：

- 同一文件连续修改，version/diff_hash 必变化。
- 大 diff 分页加载，不一次拉全量。
- untracked 文件能查看 diff 或内容。
- force push、pull 流程可用。

### Phase 7：File 低流量和安全重构

目标：文件浏览/读取缓存有效且路径安全。

Agent 任务：

- 实现 `ProjectRootResolver`：`EvalSymlinks`、路径分隔符校验、禁止 symlink 逃逸。
- 所有 file API 统一通过 resolver，包括 blob/raw。
- dir/content/blob 全部支持 ETag/304。
- 文本按 line range，二进制按 byte range。
- 大文件和二进制设置默认最大响应大小。
- 可选：图片缩略图 endpoint。
- 不持久化目录树或文件内容；所有响应都基于当前真实文件系统。

App 任务：

- `dir_cache`、`file_cache` 入库。
- 文件页传 `If-None-Match`。
- 304 直接读本地缓存。
- 大文件按需加载更多。

验收：

- 打开同一目录第二次返回 304。
- 路径穿越和 symlink 逃逸测试失败。
- 大文本文件不会卡 UI。

### Phase 8：清理旧代码和产品化

任务：

- 删除旧 `/api` 客户端调用、旧 `known_count`、旧 `BootstrapSync` 内存 hash。
- 删除 provider shared channel 订阅模型。
- 删除未使用的 PTY 回退入口，或明确放入非 Codex provider。
- 增加 cache settings：查看缓存大小、清理 session/git/file cache。
- 增加日志脱敏：token、approval sensitive payload、文件内容摘要。
- 完成中英文文案统一。

验收：

- `rg "known_count|local_hash|/api/sessions/approve|payload\\]|timestamp"` 不再出现旧协议调用。
- Flutter analyze、Go test 通过。
- 手动端到端流程通过。

## 测试计划

## 当前实施进度

截至 2026-05-01，本轮已完成以下落地项：

- Agent 只注册 `/api/v1`，App API 调用已切到 `/api/v1`；旧 `known_count` 和旧审批路径不再出现在代码调用中。
- Agent SQLite 迁移已移除 session event、Git diff/file、目录/文件内容类持久缓存；Agent DB 保留 session 控制面和 `pending_approvals`。
- Codex provider 已切到单 shared app-server client，`thread/list`、`model/list`、`config/read`、实时事件和审批共用同一个连接。
- Codex app-server wire enum 已集中映射：`on-request -> onRequest`、`untrusted -> unlessTrusted`、`workspace-write -> workspaceWrite` 等，避免 App/API 公共枚举直接泄漏到 Codex wire 协议。
- Provider-backed `/sessions/:id/events` 和 `/sessions/:id/items` 已使用 `thread/turns/list`，不再走 `thread/read includeTurns` 作为常规历史路径，也不依赖 Agent DB 历史。
- Codex `thread/fork`、`thread/compact/start`、`thread/rollback` 已按 app-server 协议接入；fork 后使用新 Codex thread id 作为 session id，不再生成本地 UUID。
- WebSocket 事件已统一为 `session.event` envelope，并支持 `client.hello`、`session.subscribe`、`session.unsubscribe` 基础控制消息。
- Agent WebSocket 已加入内存 ring buffer：带 `session_id` 的事件会分配 `ws_seq/ws_cursor`，短断线可按 WS cursor 补发；补发窗口不足或 cursor 异常时返回 `session.sync_required`。
- Codex server-initiated approval 已写入 `pending_approvals`，resolve 后更新状态并广播 `approval.resolved`；HTTP approval endpoint 支持字符串 decision 和 Codex object decision。
- App Drift schema 已提升到 v5，project/provider/session/events/items/pending approvals/sync state 以及 Git/File 展示缓存都带 `agent_id`，多 Agent 缓存隔离已成为 DB 约束。
- App `SessionRepository` 已使用 cursor 同步 session events/items；ChatPage 默认读取本地 `session_items` projection，再通过 Provider-backed `/items` 校准。
- App 已把 HTTP Provider cursor 与 WS replay cursor 分开保存：`session_items/session_events` 用于 Provider-backed 历史分页，`session_ws` 只用于 WebSocket replay；收到 `session.sync_required` 时 ChatPage 会走 `/items` 校准。
- App 已开始把实时事件合并进本地 `session_items` projection：支持 agent message delta、plan delta/update、reasoning summary/text delta、command/file output delta，并以 completed item 覆盖为权威状态。
- ChatPage 已补齐 plan/reasoning/diff 这类结构化 item 的基础展示，避免实时 projection 入库后 UI 丢失这些 Codex item。
- Provider config 已开始从 Codex app-server 动态读取：`model/list` 提供模型和 reasoning effort，`configRequirements/read` 约束 approval/sandbox 可选项，并透出 requirements、skills、MCP servers 原始数据供 App 后续 UI 使用。
- HTTP 响应已移除兼容性 `ok` 字段，成功响应只返回 `{"data": ...}`，失败响应只返回 `{"error": ...}`。
- Bootstrap hash 已改为 canonical JSON，并排除纯时间字段；无变化时可通过 `If-None-Match`/`ETag` 返回 304。Agent 已在 project create/update/delete 后标记 bootstrap dirty，并提供 `POST /api/v1/bootstrap/refresh` 用于 App 主动重新检测 provider/project 基础数据。
- Bootstrap 响应已包含 provider 的完整 `config`，App 可以直接用 bootstrap 缓存的 models/reasoning effort/approval/sandbox/requirements/skills/MCP 原始数据，不再必须逐页调用 provider config endpoint。
- App Drift 已新增 `project_entries`、`provider_entries`，并新增 `BootstrapRepository`：bootstrap 使用 `If-None-Match`，304 时读本地 project/provider cache，200/refresh 时破坏式替换当前 agent 的基础数据缓存。
- `ProjectListPage`、项目详情 provider selector、Settings 默认 Provider、Providers 页面和创建会话页已迁移到 `BootstrapRepository`，先读本地 Drift，再后台用 bootstrap 校准。
- App 已新增全局 `RealtimeService` 和 `SyncEngine` 基座：全局只维护一条 Agent WebSocket，`SyncEngine` 启动时执行 bootstrap 校准，并把 session realtime event / `session.sync_required` 写入 Drift 或触发 Provider-backed items 校准；Git invalidation 也已通过 `SyncEngine.gitInvalidations` 分发给项目/Git 页面。
- ChatPage 的 session subscribe/unsubscribe 已封装到 `SyncEngine.subscribeSession` / `unsubscribeSession`，页面不再直接操作底层 WebSocket；ChatPage 只订阅 `SyncEngine.sessionEvents` 用于即时 UI 补充。
- App 已新增 `LifecycleSync`：前台恢复时启动 SyncEngine/WS 并执行 bootstrap 校准，后台/暂停时断开 WS 但保留订阅 cursor，恢复后由 WS hello/subscribe 继续补发或触发 HTTP 校准。
- App Drift/Repository 已补 `watchProjects`、`watchProviders`、`watchSessions`、`watchItems`；`ProjectListPage`、项目详情 session 列表和 ChatPage items 已改为由 Drift stream 驱动，HTTP/WS 只负责更新本地缓存。
- ChatPage 发送消息会先写本地 pending `user_message` item，再调用 Provider input；Provider-backed items 或 realtime projection 后续负责校准。
- Git/File Agent 侧已按真实工作区/文件系统读取，Agent 不持久保存 Git/File 内容缓存。
- App Drift 已新增 `git_summary_entries`、`git_changes_entries`、`dir_cache_entries`、`file_cache_entries`。这些表只作为 App 展示缓存，Git/File 事实仍以真实工作区和文件系统为准。
- App 已新增 `GitRepository` 和 `FileRepository`：Git summary 使用 `If-None-Match`，changes 使用 `base_version`，dir/file content 使用 hash/ETag；304 时读取本地缓存，200 时覆盖本地缓存。
- `ProjectChangesTab`、Git 管理页 Status tab 已迁移到 `GitRepository`，首屏优先展示本地 Git 缓存，stage/unstage/discard/commit/push 后主动重新拉取真实 summary/changes。
- `ProjectFilesTab` 已迁移到 `FileRepository`，目录和文本文件支持本地缓存优先、后台校准；文本文件先展示缓存时，远端内容返回后会更新当前预览。
- `DiffSheet` 已支持按 `offset/limit` 分页加载大 diff，不再默认一次拉取完整文件 diff。
- Agent 已启动 GitWatcher：对已有项目以及项目创建/更新/删除同步增删 watcher；watcher 监听 `.git` 关键文件和工作区目录，debounce 后只广播轻量 `git.invalidated`，不推送 Git 文件列表或 diff 内容。
- App 的项目 Changes 页和独立 Git 管理页已监听 `git.invalidated`，收到当前项目 invalidation 后重新通过 `GitRepository` 拉取真实 summary/changes 并更新本地展示缓存。
- Agent 已实现 `/projects/:id/git/pull`，App `GitApi/GitRepository` 和文件页 Pull 按钮已接入；pull 后主动刷新真实 Git summary/changes。
- Agent discard 已要求显式 `confirm=true`，并支持 untracked 文件/目录通过 `git clean -fd -- <path>` 删除；App discard 请求已携带确认字段。
- File raw/blob 已支持 `If-None-Match`/`ETag`、`offset/limit` 和默认最大响应大小；响应会返回 `hash`、`offset`、`limit`、`truncated`，避免大二进制/大文本一次性无限制传输。
- App `FileApi/FileRepository` 已支持 raw/blob 304 和本地缓存；图片、markdown、代码预览会先展示本地 raw cache，再后台校准真实文件内容。
- Agent 已增加进程内 diff LRU：缓存结构化 diff lines，不写 Agent DB；每次请求仍从真实 Git 重新计算 diff hash，hash 匹配后才复用解析结果并分页返回。
- Cache settings 已从假数据改为读取 Drift 真实展示缓存统计，支持按 Git/File/Session 或全部清理本地展示缓存；清理不影响 provider 历史、真实 Git 或真实文件系统。
- 已补 Agent bootstrap 单元测试：覆盖 hash 忽略 `updated_at` 和集合顺序、provider config 变化触发 hash 变化、`MarkDirty` 清空内存缓存并发出 dirty 信号。
- 已补 App Drift 单元测试：覆盖 `agent_id` 隔离、Git/Session 展示缓存统计和按 agent 清理，防止本地展示缓存跨 Agent 串数据。
- 已补 `SessionRepository` projection 单元测试：覆盖 pending user message 本地 item、agent message delta 合并、WS cursor 单独保存。
- 已补 `SyncEngine` 单元测试：覆盖启动时 bootstrap 同步、`session.sync_required` 触发 items catch-up、session event 入库/分发、Git invalidation 独立分发、subscribe 使用保存的 WS cursor。
- 已补 Codex fake JSON-RPC transport 测试：覆盖 `initialize`/`initialized` 流程、server-initiated request 路由、notification 到 provider event 的路由。

已验证：

- `cd agent && go test ./...`
- `cd magent_app && dart run build_runner build --delete-conflicting-outputs`
- `cd magent_app && dart format ...`
- `cd magent_app && flutter analyze`
- `cd magent_app && flutter test`

仍需后续完成的最佳实现项：

- App 已有全局 `SyncEngine`/全局 WS lifecycle 基座，project/provider/session/Git/File 的 repository 化主路径已完成；目录选择器和 home 目录读取仍是工具型直连 API，不作为状态源缓存。
- App 的实时 item projection 和 ChatPage 基础展示已覆盖主要 Codex item；后续还可增加 ChatPage/Git/File widget 测试。
- Provider config 已透出 Codex requirements/skills/MCP 原始数据，创建会话页已使用 bootstrap 缓存的 provider config；后续还需要把 requirements/skills/MCP 做成更完整的配置 UI。
- Git/File 的 App 展示缓存、304 校准、Git watcher invalidation、pull、discard untracked、raw/blob ETag/range/最大响应限制和进程内 diff LRU 已落地。
- File 页面当前已覆盖目录、文本内容和 raw/blob 预览缓存；后续可继续做专门的图片缩略图 API 和大文本滚动加载。
- 仍需补 Codex fake JSON-RPC 更完整场景测试、SyncEngine 网络异常测试、ChatPage/Git/File widget 测试和端到端手动验收。

### Go 测试

- `ProviderSessionSync`：cursor 分页、Provider-backed 历史读取、Agent 重启后校准。
- `RealtimeRingBuffer`：短断线补发、容量溢出后要求 HTTP 校准。
- `ApprovalService`：resolve、timeout、重复 resolve、Codex response schema。
- `CodexAppServerClient`：用 fake JSON-RPC server 测 initialize、server request、notification routing。
- `BootstrapService`：canonical hash 稳定性、字段变更触发 hash 变化。
- `GitService`：status parser、version bump、diff_hash、untracked synthetic diff。
- `FileService`：路径穿越、symlink 逃逸、304、range。

### Flutter 测试

- Drift DAO：agent_id 隔离、event upsert、item projection 更新。
- SyncEngine：bootstrap 304、session events catch-up、cursor gap/断线校准。
- Repository：离线先展示本地缓存，在线后更新。
- ChatPage widget：items 渲染、approval card、实时 delta。
- Git/File 页面：缓存命中和分页加载。

### 端到端手动验收

1. 连接 Agent，首次 bootstrap 200，第二次 304。
2. 创建 Codex session，发送消息，App 实时看到 agent delta。
3. App 断网，Codex 继续执行；恢复后补齐消息。
4. 触发命令审批，App 允许后 Codex 继续。
5. 修改工作区文件，Git 页面自动出现变化，diff 分页可读。
6. 打开目录和文件两次，第二次命中 304/本地缓存。
7. 切换另一个 Agent，本地缓存不串。

## 关键技术决策

### App 使用 item projection，而 Agent 不保存 session 内容事实

只存消息数组无法表达 Codex 的工具调用、delta、plan、reasoning、approval、diff 等结构。最佳方案是 App 本地保存 item projection 给 UI 高效读取；Agent 只在实时转发和 HTTP 响应期间做标准化转换，不把 projection 持久化为事实来源。需要校准时，App 重新向 Agent 请求 Provider-backed items。

### 使用 ETag/If-None-Match，而不是 query local_hash

HTTP 原生缓存语义更清晰，Dio 也能统一处理。JSON 里保留 hash 只是为了本地入库和调试。

### Agent 减少 session、Git、File 缓存

Session 的事实来源是 Provider，Git 的事实来源是实际工作区，File 的事实来源是实际文件系统。Agent DB 只保存控制面数据和 pending approval。短断线事件、热点 diff 可以用内存缓存优化，但不能写成长期事实缓存。App DB 才是展示缓存，并且每次同步都要用 Provider cursor、Git version/hash、File ETag 校验。

### Codex 使用单 supervisor

每个 session 一个 app-server 进程会导致资源浪费、事件路由分散、订阅竞争。单 supervisor 更符合 app-server 的设计，也更容易实现全局 thread/list、config/model/skills 同步。

## 风险与处理

| 风险 | 处理 |
|---|---|
| Codex app-server schema 变化 | 引入 generated schema 和 fake server 测试，provider 内做集中映射 |
| SQLite 写入成为瓶颈 | Agent DB 只写控制面和审批状态；高频 session/Git/File 内容不落 Agent DB |
| WS 丢消息 | WS 只做实时提示，短断线用 ring buffer，长断线用 Provider-backed HTTP sync 校准 |
| App DB schema 变更大 | 不兼容旧版本，直接 destructive migration |
| Git 大仓库扫描慢 | watcher + debounce 只做 invalidation；重型 diff 按需计算，热点 diff 用内存 LRU |
| 文件路径安全遗漏 | 所有 API 强制走 root resolver，单元测试覆盖 symlink/path traversal |

## 最终验收标准

- App 冷启动无网络时能展示上次缓存的 Agent、项目、session、消息。
- 有网络但无变更时，bootstrap/session list/git/file dir/file content 都能 304 或返回极小响应。
- session 内容以 Provider 为准，App 断线后能通过 Provider-backed sync 校准，不依赖 Agent DB 历史。
- Codex 审批闭环可用，命令/file/MCP 审批状态在 App 和 Agent 中一致。
- Git version/diff_hash 能准确反映 staged、unstaged、untracked 变化。
- 文件读取全部经过安全校验，支持 hash/range/304。
- Agent DB 不持久保存 session item projection、Git changes/diff、文件内容。
- 多 Agent 缓存完全隔离。
- 旧协议和旧缓存路径从 App 端完全移除。
