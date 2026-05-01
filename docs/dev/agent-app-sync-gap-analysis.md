# Agent/App 低流量同步与 Codex 协议实现差距分析

日期：2026-05-01

## 结论

当前代码已经具备“App 控制 Agent、Agent 通过 Codex app-server stdio 控制本地 Codex、Agent 提供 Git/File API”的基本雏形，但还没有完整实现目标中的低流量同步、可靠断线恢复、审批闭环和本地缓存一致性。

最需要优先处理的是三类问题：

1. 会话事件没有稳定 `seq` 和持久化，App 端用 `known_count` 做增量会丢数据、重复数据，且 HTTP 历史事件字段和 UI 解析字段不一致。
2. 审批链路目前不通：App 调用的审批接口后端没有注册，后端 `ApprovalProxy` 也没有被 HTTP/WebSocket 客户端消息闭环驱动。
3. 基础数据 `config_hash` 机制只是半成品：后端 hash 覆盖不完整且没有被项目/Provider 变更触发刷新，App 端 `BootstrapSync` 没接入主流程，也没有持久化 hash。

所以现状不能算“已完整实现”。它更接近 MVP 原型，能验证部分创建会话、发送输入、读取 Git/File 数据的链路，但还不满足“手机端低流量远程控制台”的产品目标。

## 目标架构对照

目标中的关键原则是：

- Agent 轻量化：尽量做协议适配、鉴权、缓存索引、事件转发，不承担复杂业务状态。
- Codex 优先使用 app-server 协议，PTY 只是回退。
- App 本地有 DB 缓存基础数据、session 列表、session 历史消息。
- 启动、session 列表、session 消息都要支持 hash/seq/cursor 增量；动态状态可以实时刷新。
- 高流量数据如 Git diff、文件内容必须分页、hash 缓存、按需读取。

现状部分满足：Codex 使用 app-server stdio；Git diff 和文件读取有分页接口；App 有 Drift 表缓存 session 和 events。未满足的是缓存协议本身的可靠性和使用闭环。

## 当前已实现内容

### Agent 端

- HTTP 路由已覆盖 Agent info、Providers、Projects、Sessions、Git、Files、Sync、WebSocket：`agent/internal/api/router.go`。
- Codex provider 已通过 `codex app-server` stdio 启动，并实现 `initialize`、`thread/start`、`turn/start`、`turn/steer`、`turn/interrupt`、`thread/read`、`thread/list`、`model/list` 等部分方法：`agent/internal/providers/codex/appserver_client.go`。
- Session manager 能创建、恢复、发送输入、停止，并将 provider 事件广播到 WebSocket：`agent/internal/session/manager.go`。
- Git summary/changes/file diff/log/branch/stage/commit/push 等接口已存在：`agent/internal/api/git_handler.go`。
- File list/read 有 `known_hash` 和 304 支持：`agent/internal/fileservice/service.go`。
- Bootstrap sync 有 `/api/sync/check` 和 `/api/sync/bootstrap?local_hash=`：`agent/internal/sync/bootstrap.go`。

### App 端

- Drift 本地库已定义 `SessionEntries` 和 `SessionEventEntries`：`magent_app/lib/core/storage/app_database.dart`。
- `SessionRepository` 已实现“先读本地 DB，再从 API 同步”的雏形：`magent_app/lib/core/repositories/session_repository.dart`。
- Session 创建页能从 `/api/providers/:name/config` 动态读取模型、推理强度、审批策略和沙箱模式：`magent_app/lib/features/sessions/create/session_create_page.dart`。
- Git、文件、会话页面已接入对应 API，具备基础 UI 工作流。

## P0 问题：会直接影响核心链路

### 1. SessionStore 写库实际会失败

`agent/internal/storage/migrations.go` 中 `sessions` 表要求 `status`、`runner_type`、`created_at`、`updated_at` 非空。但 `agent/internal/session/store.go` 的 `Save()` 只插入：

```sql
id, provider_id, thread_id, project_id, model, created_at
```

缺少 `status`、`runner_type`、`updated_at`。这会触发 SQLite NOT NULL 约束错误。`CreateSession()` 里保存失败只记录日志，不阻断，所以表面上会话创建成功，但本地 metadata 没有保存。

影响：

- 停止后的 session 可能无法按 project 正确列出。
- resume/fork/rollback 等依赖 DB metadata 的能力不可靠。
- App 端 session 缓存会依赖 provider thread list 临时补齐，状态和项目归属容易漂移。

建议：修复 `Save()` 字段，保存 `workdir/status/runner_type/approval_mode/sandbox_mode/updated_at/last_seq`，并让创建会话时保存失败返回错误或降级为明确告警。

### 2. 会话事件没有可靠增量协议

后端迁移里有 `session_events(seq)` 和 `sessions.last_seq`，但当前代码没有使用：

- `Manager.forwardEvents()` 只 WebSocket 广播，不写 `session_events`。
- `/api/sessions/:id/events` 使用 `known_count`，不是 `after_seq`。
- `Manager.GetEvents()` 每次调用 provider `ReadThreadHistory()` 全量读取，再按数组下标切片。
- `ReadThreadHistory()` 只映射 `userMessage` 和 `agentMessage`，命令、文件、MCP、plan、reasoning、diff 等历史都丢失。

App 端也有字段不匹配：

- HTTP 返回的 `ProviderEvent` 字段是 `payload`/`timestamp`，但 `SessionRepository._syncEventsFromApi()` 读取的是 `data`/`time`。
- ChatPage 渲染用户消息只认 `user.input`，后端历史映射的是 `session.user_message`。
- `getEvents()` 会后台同步一次，随后 ChatPage 又调用 `refreshEvents()`，在没有远端唯一 seq 的情况下容易重复插入。

建议协议：

- Agent 持久化所有 provider event：`session_id + seq + type + payload + created_at`。
- HTTP 改为 `GET /api/sessions/:id/events?after_seq=N&limit=100`。
- WebSocket 事件统一带 `seq`：`{type:"session.event", session_id, seq, event_type, data}`。
- App 表增加唯一键 `(session_id, seq)`，用 `insertOnConflictUpdate` 或忽略重复。
- 历史读取只作为补洞来源，不能用数组 count 当游标。

### 3. 审批链路未闭环

Codex provider 已能接收 app-server 的 server-initiated approval request，并调用 `ApprovalProxy.HandleRequest()`。但链路断在 App 到 Agent：

- App 调用 `/api/sessions/approve`：`magent_app/lib/core/api/session_api.dart`。
- 后端路由没有注册 `/api/sessions/approve`，也没有 `/api/sessions/:id/approve`。
- `ApprovalProxy.Resolve()` 没有被任何 API handler 或 WebSocket 消息调用。
- `ws.Client.ReadPump()` 仍是 TODO，不能从 WebSocket 接收审批响应。
- `ApprovalProxy` 用 `req.ID` 做 pending key，但 item id 可能为空；应使用 JSON-RPC request id 或稳定 `approval_id`。

另外，Codex app-server 文档中的审批响应是 decision payload，包含 `accept`、`acceptForSession`、`decline`、`cancel`，命令审批还可能包含 `acceptWithExecpolicyAmendment`。当前代码返回 `{"decision": action}`，需要用真实 schema 验证是否匹配当前 Codex 版本。

建议：

- 增加 `POST /api/sessions/:id/approve`，body 包含 `approval_id/action/message`。
- approval request 下发时生成 Agent 自己的 `approval_id`，映射到 Codex JSON-RPC request id。
- 响应 Codex 时严格按 `docs/extra/codex_appserver.html` 的 decision schema。
- WebSocket 也支持 `approval.resolve`，HTTP 作为兜底。

### 4. Codex 协议字段存在枚举风险

当前 App 和 Agent 使用的值包括：

- `approval_policy`: `on-request`、`untrusted`、`never`
- `sandbox_mode`: `workspace-write`、`read-only`、`danger-full-access`

而 `docs/extra/codex_appserver.html` 中出现的 app-server v2 字段更偏向：

- `approvalPolicy`: `onRequest`、`unlessTrusted`、`never`
- `sandbox` 或 `sandboxPolicy.type`: `workspaceWrite`、`readOnly`、`dangerFullAccess`

`StartThread()` 直接把 App 传来的 `workspace-write` 写入 `thread/start.sandbox`，`StartTurn()` 虽然构造了 `sandboxPolicyObject()`，但 `approvalPolicy` 仍可能是 `on-request`。如果当前 Codex 版本严格校验枚举，这会导致创建线程或开始 turn 失败。

建议：在 Agent provider 边界做统一映射，不让 App 直接透传 Codex 内部枚举：

- App/Agent 公共枚举可继续使用 kebab-case。
- CodexProvider 内部映射到 Codex app-server 当前 schema。
- 用 `codex app-server generate-json-schema` 或真实 smoke test 固化枚举。

### 5. Provider 事件 fan-out 模型错误

`CodexProvider.Subscribe()` 返回同一个 channel，注释说“Multiple readers on the same channel is safe”。Go channel 多 reader 的语义是竞争消费，不是广播。

影响：

- `Manager.forwardEvents()`、Git commit message suggest、未来的历史持久化 worker 如果同时订阅，会互相抢事件。
- App 可能看不到部分事件，AI 自动生成 commit message 也可能丢 delta。

建议：Provider 内部维护 `sessionID -> subscribers[]chan`，`emit()` 对每个 subscriber 非阻塞发送；或者只允许一个内部消费者，再由 SessionManager 负责持久化和广播。

## P1 问题：低流量同步不完整

### 1. Bootstrap hash 覆盖不完整且 App 未接入

后端 `ConfigService.computeHash()` 只计算：

- Agent version
- provider name/status
- project id

它忽略了 provider version、run_mode、capabilities、config_schema、模型列表、项目名称/路径/default_provider、workspace allow/exclude 配置等。配置变了但 hash 不变，App 就不会重新拉。

同时：

- `MarkDirty()` 没有在 project create/update/delete、provider config 变化、workspace 配置变化时调用。
- `BootstrapData` 没有返回 `config_hash` 字段，和通信设计不一致。
- App `BootstrapSync` 没有在启动、连接 Agent、进入 Projects 时接入。
- `BootstrapSync` 按 `resp.data['config_hash']` 读取，但后端统一响应是 `{ok,data}`，实际应读取 `resp.data['data']['config_hash']` 或调整 API。
- Dio 默认会把 HTTP 304 当异常，当前 `resp.statusCode == 304` 分支可能走不到。
- `_configHash` 只存在内存里，没有按 Agent 持久化。

建议：用 canonical JSON 计算完整 hash，排除 `updated_at` 这类动态字段；后端 bootstrap response 包含 `config_hash`；App 增加 `sync_state(agent_id, scope, hash, updated_at)` 表并在连接后立即同步。

### 2. Session 列表没有真正增量

当前 `/api/sessions?project_id=` 每次返回全量列表。App 本地先读 DB，再全量刷新，但没有：

- list hash/revision
- cursor 分页
- deleted/archived tombstone
- 动态状态与静态列表分离

并且 `SessionRepository._syncSessionsFromApi()` 只 upsert，不删除 API 中已消失的本地 session。

建议：

- Session 列表接口返回 `list_hash` 或 `revision`，支持 `local_hash` 命中 304。
- 列表项拆分静态字段和动态状态：静态字段参与 hash，状态通过 `session.status_changed` WS 或轻量 status API 更新。
- 增加 tombstone 或全量刷新时删除本地缺失项。

### 3. App 本地 DB 没有 Agent 维度

当前 Drift 表没有 `agent_id`。如果 App 配置多个 Agent，不同 Agent 的 session id/project id 可能冲突，也无法分别保存 config hash、项目列表、Provider 配置。

建议所有缓存表都带 `agent_id`：

- `agents`
- `sync_state`
- `projects`
- `providers`
- `sessions`
- `session_events`
- `file_cache`
- `dir_cache`
- `git_state`

### 4. WebSocket 没有接入 UI

`WsClient` 存在，但没有被页面使用。ChatPage、ProjectDetailPage 主要靠 HTTP 刷新。因此：

- 实时 token/delta 不会自动显示。
- session status 不会动态变化。
- 断线重连没有 `last_seq` 补偿。
- approval request 即使后端广播，App UI 也收不到。

建议把 WebSocket 做成全局 provider：

- Agent 激活后建立连接。
- 连接成功发送 `client.hello` 和当前本地各 session `last_seq`。
- 收到 `session.event` 后写入 Drift，再通知 UI。
- 重连后对打开中的 session 调 `/events?after_seq=last_seq` 补齐。

## P1 问题：Git/File 缓存和低流量细节

### Git 版本号和 diff_hash 不可靠

`GetSummary()` 的 `worktreeHash` 使用 `git ls-files -s`，这主要反映 index，不足以表示 unstaged 文件内容变化。`getOrBumpVersion()` 只比较 `head/worktreeHash/indexHash`，不比较 status 输出和文件内容，因此同一个文件多次修改时 version 可能不变。

`GetChanges()` 还有几个问题：

- App 同时调用 summary 和 changes，`changes` 可能先执行，此时没有 git_state，会返回 version 0。
- `OldHash/NewHash` 从未填充，`DiffHash` 基本只由 path + staged/unstaged 决定，文件内容变化后 diff_hash 不变。
- untracked 文件没有 diff_hash，`GetFileDiff()` 对 untracked 文件会返回空 diff。
- `git_diff_cache` 缓存的是解析后的行，再读取时重新按 unified diff 解析，行号会丢失或变成 0。
- `GitWatcher` 已实现但没有被项目或 WebSocket 启动。

建议：

- Git version 基于 `git status --porcelain=v1 -z`、`git diff --raw`、`git diff --cached --raw`、untracked 列表和必要的 file stat/content hash 计算。
- `diff_hash` 基于真实 diff 内容 hash，后端自己计算，不信任客户端传入。
- `GET /git/changes?base_version=` 命中版本时返回 `{version, files:null/not_modified:true}` 或 304。
- `GetChanges()` 内部先确保 summary/state 已刷新，避免并发 race。
- 对 untracked 文件提供 synthetic diff 或跳转文件读取。

### Git 操作接口有功能缺口

- Force push 后端要求 `X-Confirm-Force: true`，App `GitApi.push(force:true)` 没带 header，force push 会失败。
- Pull 没有实现，Files tab 里只提示 “Pull not yet implemented on agent”。
- `discard` 不能删除 untracked 文件。
- `commit/suggest` 通过新建 Codex session 等待事件，但受 channel fan-out 问题影响，可能抢不到 AI 输出。

### File hash 接口有但 App 未使用缓存

后端：

- `/api/files/list` 支持 `known_hash` 和 304。
- `/api/files/read` 支持 `known_hash`、offset、limit 和 304。

App：

- `ProjectFilesTab` 每次都不传 `knownHash`。
- 没有 dir/file cache 表。
- `readRawFile()` 直接整文件读取，不分页、无 hash、无大小保护。
- Dio 默认 304 会抛异常，FileApi 没处理 304。

安全和正确性问题：

- `RawFile` 没走 `fileservice.validatePath()`，存在路径穿越/越权读取风险。
- `validatePath()` 用 `strings.HasPrefix(absPath, absProject)`，没有路径分隔符判断，`/repo2` 可能被 `/repo` 误判为允许。
- symlink 没有做 `EvalSymlinks` 后再校验。
- `readLines()` 对跨 32KB chunk 的长行处理不可靠，也漏算没有换行结尾的最后一行。

建议：

- 所有文件读取都统一走 `fileservice` 校验。
- App 增加 `dir_cache` 和 `file_cache`，传 `known_hash`，处理 304。
- Raw 文件增加 size limit、range、hash，图片也走分块或缩略图接口。

## P2 问题：Codex app-server 能力未完整覆盖

当前已实现基础会话，但 `docs/extra/codex_appserver.html` 中的很多能力尚未接入：

- `thread/fork`：Provider 返回 `fork not implemented`。
- `thread/compact/start`：Provider 返回 `compact not implemented`。
- `thread/rollback`：Provider 返回 `rollback not implemented`。
- `thread/name/set`、archive/unarchive、metadata/update 未实现。
- `thread/turns/list` 分页未使用，历史读取用 `thread/read includeTurns` 全量。
- `turn/diff/updated`、`turn/plan/updated`、`item/plan/delta`、reasoning summary delta、command output delta、fileChange output delta 等通知没有完整映射。
- `serverRequest/resolved` 没有映射到 App，用于清理 pending approval。
- `skills/list`、`app/list`、`mcpServerStatus/list`、`config/read/write` 等只在 client 中有部分方法或未暴露。

建议优先级：

1. 先补全事件类型和审批。
2. 再补 `turns/list` 分页作为历史同步基础。
3. 最后补 fork/compact/rollback/name/archive/metadata。

## App 端缓存模型建议

建议将 Drift schema 调整为以下方向：

```text
agents(id, name, url, created_at, updated_at)
sync_state(agent_id, scope, key, hash, cursor, updated_at)
projects(agent_id, id, name, path, default_provider, updated_at)
providers(agent_id, name, status, version, run_mode, capabilities_json, config_json, updated_at)
sessions(agent_id, id, project_id, provider_id, thread_id, title, model, workdir, status, last_seq, created_at, updated_at)
session_events(agent_id, session_id, seq, type, payload_json, created_at, PRIMARY KEY(agent_id, session_id, seq))
git_project_state(agent_id, project_id, version, summary_json, updated_at)
git_file_changes(agent_id, project_id, version, path, staged, status, diff_hash, stat_json)
dir_cache(agent_id, project_id, path, hash, items_json, updated_at)
file_cache(agent_id, project_id, path, hash, offset, limit, content, updated_at)
```

同步策略：

- App 启动或切换 Agent：先读本地 DB 展示，再 `/sync/check`，hash 变更才 `/sync/bootstrap`。
- 进入项目：先展示本地 session 列表，再请求 session list hash/revision，必要时更新列表。
- 打开会话：先展示本地 `session_events`，连接 WS 或 HTTP 拉 `after_seq=last_seq`。
- WS 收到实时事件：事务写 DB，再刷新 UI。
- Git/File：先用本地 hash 请求，304 用缓存；200 更新缓存。

## Agent 端协议建议

### 基础数据

```http
GET /api/sync/check
GET /api/sync/bootstrap?local_hash=...
```

响应保持统一包装也可以，但 App 必须统一解包：

```json
{
  "ok": true,
  "data": {
    "config_hash": "...",
    "updated_at": 1710000000,
    "agent": {},
    "providers": [],
    "projects": [],
    "workspace": {}
  }
}
```

### Session 列表

```http
GET /api/sessions?project_id=...&local_hash=...&limit=50&cursor=...
```

命中 hash 返回 304 或：

```json
{
  "project_id": "...",
  "list_hash": "...",
  "data": [],
  "next_cursor": null,
  "deleted_ids": []
}
```

动态状态通过：

```json
{"type":"session.status_changed","session_id":"...","status":"running","updated_at":...}
```

### Session 事件

```http
GET /api/sessions/:id/events?after_seq=1020&limit=200
```

```json
{
  "session_id": "...",
  "from_seq": 1021,
  "last_seq": 1042,
  "has_more": false,
  "events": [
    {"seq":1021,"type":"session.message_delta","data":{},"created_at":...}
  ]
}
```

WebSocket 使用同样事件结构，避免 HTTP/WS 字段不一致。

## 推荐实施顺序

1. 修复 session DB 写入和事件持久化：`SessionStore.Save()`、`session_events`、`after_seq` API、App event schema。
2. 打通审批：后端 approve route、`ApprovalProxy` request id 映射、App 调用路径、WS/HTTP 双通道。
3. 接入全局 WebSocket：实时事件写 Drift，重连后按 `last_seq` 补齐。
4. 修正 bootstrap：完整 hash、`MarkDirty()` 调用点、App 启动接入和持久化。
5. 修正 Codex enum 映射和事件 mapper：用当前 app-server schema 验证 snake_case/camelCase item type。
6. 修正 Git version/diff_hash 和 untracked diff；App 侧开始使用 `base_version` 和 diff cache。
7. 文件缓存落地：App 传 `known_hash`，处理 304，后端统一路径校验。
8. 补 Codex 高级能力：fork、compact、rollback、turns/list 分页、thread metadata/name/archive。

## 验证清单

- 新建 Codex session 后，`sessions` 表有完整 metadata，`updated_at/status/runner_type` 不为空。
- 发送一条消息后，Agent `session_events` seq 连续递增，App Drift 中 `(session_id, seq)` 无重复。
- App 断网期间 Codex 继续输出；恢复后通过 `after_seq` 补齐，无重复、无空消息。
- Codex 触发命令审批时，App 能收到审批卡片，点击允许/拒绝后 Codex turn 能继续或正确 declined。
- 修改 provider config、项目名、workspace 配置后，`config_hash` 必然变化；无变化时 bootstrap 返回 304 且 App 不全量拉取。
- 同一文件多次修改后 Git version 和 diff_hash 都变化；旧 diff cache 不会污染新 diff。
- App 打开同一目录第二次会传 `known_hash`，后端 304 时 App 使用本地缓存。
- 多 Agent 切换后，项目、session、事件缓存互不串数据。
