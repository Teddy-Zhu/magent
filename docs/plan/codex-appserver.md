# Codex App Server 协议集成细节

## 一、协议概述

Codex App Server 是 OpenAI Codex CLI 的编程接口，基于 JSON-RPC 2.0 协议。

### 1.1 传输方式

| 方式 | 启动命令 | 说明 |
|---|---|---|
| stdio | `codex app-server` | 默认，最安全，无网络暴露，JSONL 格式 |
| WebSocket | `codex app-server --listen ws://IP:PORT` | 实验性，每帧一条 JSON-RPC 消息 |
| off | `codex app-server --listen off` | 禁用本地传输 |

### 1.2 消息格式

请求：`{ "method", "params", "id" }`
响应：`{ "id", "result" }` 或 `{ "id", "error": { "code", "message" } }`
通知：`{ "method", "params" }`（无 `id`）

### 1.3 WebSocket 认证

| 认证方式 | 启动参数 |
|---|---|
| capability-token 文件 | `--ws-auth capability-token --ws-token-file /path` |
| capability-token SHA256 | `--ws-auth capability-token --ws-token-sha256 HEX` |
| signed-bearer-token | `--ws-auth signed-bearer-token --ws-shared-secret-file /path` |

客户端在握手时发送 `Authorization: Bearer <token>`。

### 1.4 背压与健康检查

- 有界队列，满时返回 JSON-RPC 错误码 `-32001`，消息 `"Server overloaded; retry later."`
- WebSocket 模式健康检查：`GET /readyz`（监听器就绪）、`GET /healthz`（无 Origin 头时 200）

### 1.5 Schema 生成

```bash
codex app-server generate-ts --out ./schemas
codex app-server generate-json-schema --out ./schemas
```

---

## 二、核心概念

- **Thread** — 用户与 Codex Agent 的对话，包含多个 Turn
- **Turn** — 单次用户请求 + Agent 工作，包含多个 Item，流式推送增量更新
- **Item** — 输入/输出单元（用户消息、AI 消息、命令执行、文件变更、工具调用等）

---

## 三、初始化握手

```go
// 步骤 1：发送 initialize
send(JSONRPCRequest{
    Method: "initialize",
    ID:     0,
    Params: map[string]any{
        "clientInfo": map[string]any{
            "name":    "magent",
            "title":   "Magent Agent",
            "version": "0.1.0",
        },
        "capabilities": map[string]any{
            "experimentalApi":          true,
            "optOutNotificationMethods": []string{},
        },
    },
})

// 步骤 2：等待 initialize 响应
// 返回 user agent string, platformFamily, platformOs

// 步骤 3：发送 initialized 通知
send(JSONRPCRequest{ Method: "initialized" })
```

错误情况：
- initialize 前发送请求 → `"Not initialized"`
- 重复 initialize → `"Already initialized"`
- 未开启 experimentalApi 调用实验方法 → `"<descriptor> requires experimentalApi capability"`

---

## 四、Thread 方法

### 4.1 thread/start — 创建线程

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| model | string | 否 | 模型 ID |
| cwd | string | 否 | 工作目录 |
| approvalPolicy | string | 否 | `"never"` / `"unlessTrusted"` / `"onRequest"` |
| sandbox | string | 否 | 沙箱模式 |
| personality | string | 否 | 人格预设 |
| serviceName | string | 否 | 线程级指标标签 |
| dynamicTools | array | 否 | 实验性，持久化到 rollout metadata |

响应：`{ "thread": { "id", "preview", "ephemeral", "modelProvider", "createdAt" } }`

### 4.2 thread/resume — 恢复线程

| 字段 | 类型 | 必填 |
|---|---|---|
| threadId | string | 是 |
| personality | string | 否 |

### 4.3 thread/fork — 分叉线程

| 字段 | 类型 | 必填 |
|---|---|---|
| threadId | string | 是 |

响应：`{ "thread": { "id" } }`

### 4.4 thread/read — 读取线程

| 字段 | 类型 | 必填 |
|---|---|---|
| threadId | string | 是 |
| includeTurns | boolean | 否 |

线程包含 `status` 字段，类型见 4.10。

### 4.5 thread/turns/list — 列出线程的 Turn

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| threadId | string | 是 | |
| limit | number | 否 | 页大小 |
| sortDirection | string | 否 | `"desc"`（默认）/ `"asc"` |
| cursor | string | 否 | 分页游标 |

响应：`{ "data": [], "nextCursor", "backwardsCursor" }`

### 4.6 thread/list — 列出线程

| 字段 | 类型 | 说明 |
|---|---|---|
| cursor | string | 分页游标 |
| limit | number | 页大小 |
| sortKey | string | `"created_at"`（默认）/ `"updated_at"` |
| modelProviders | string[] | 按 provider 过滤 |
| sourceKinds | string[] | 按来源过滤 |
| archived | boolean | `true` = 仅归档 |
| cwd | string | 精确匹配工作目录 |
| searchTerm | string | 搜索摘要/metadata |

`sourceKinds` 枚举值：`cli`, `vscode`, `exec`, `appServer`, `subAgent`, `subAgentReview`, `subAgentCompact`, `subAgentThreadSpawn`, `subAgentOther`, `unknown`

响应：`{ "data": [thread objects with status], "nextCursor" }`

### 4.7 thread/loaded/list — 列出已加载线程

无必填参数。响应：`{ "data": ["thr_123", "thr_456"] }`

### 4.8 thread/name/set — 设置线程名称

设置/更新用户可见的线程名称，触发 `thread/name/updated` 通知。

### 4.9 thread/metadata/update — 更新线程 metadata

| 字段 | 类型 | 说明 |
|---|---|---|
| threadId | string | 必填 |
| gitInfo | object | `{ "sha"?, "branch"?, "originUrl"?, ... }`，`null` 清除 |

### 4.10 thread/archive — 归档线程

### 4.11 thread/unarchive — 取消归档

### 4.12 thread/unsubscribe — 取消订阅

| 字段 | 类型 | 必填 |
|---|---|---|
| threadId | string | 是 |

响应：`{ "status": "unsubscribed" | "notSubscribed" | "notLoaded" }`

若为最后一个订阅者，线程在 30 分钟不活动后卸载，触发 `thread/status/changed`（notLoaded）+ `thread/closed`。

### 4.13 thread/compact/start — 压缩历史

立即返回 `{}`，进度通过 `turn/*` 和 `item/*` 通知推送。

### 4.14 thread/shellCommand — 执行 Shell 命令

| 字段 | 类型 | 必填 |
|---|---|---|
| threadId | string | 是 |
| command | string | 是 |

**在沙箱外执行，拥有完全访问权限**。若线程有活跃 turn，作为辅助执行；若空闲，启动独立 turn。

### 4.15 thread/rollback — 回滚

| 字段 | 类型 | 必填 |
|---|---|---|
| threadId | string | 是 |
| numTurns | number | 是 |

响应：`{ "thread": { "id", "name", "ephemeral", "turns"? } }`

### 4.16 thread/inject_items — 注入 Items

| 字段 | 类型 | 必填 |
|---|---|---|
| threadId | string | 是 |
| items | array | 是 — Responses API items |

### 4.17 thread/backgroundTerminals/clean — 清理后台终端

实验性，需 `capabilities.experimentalApi`。

### 4.18 Thread 通知

| 通知 | 载荷 |
|---|---|
| `thread/started` | `{ "thread": { "id" } }` |
| `thread/archived` | `{ "threadId" }` |
| `thread/unarchived` | `{ "threadId" }` |
| `thread/closed` | `{ "threadId" }` |
| `thread/status/changed` | `{ "threadId", "status" }` |
| `thread/name/updated` | `{ "threadId", "name" }` |
| `thread/tokenUsage/updated` | 活跃线程的 token 使用数据 |

**线程状态类型**：`notLoaded`, `idle`, `systemError`, `active`（含 `activeFlags` 数组，如 `["waitingOnApproval"]`）

---

## 五、Turn 方法

### 5.1 turn/start — 开始生成

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| threadId | string | 是 | |
| input | array | 是 | 输入 item 数组 |
| model | string | 否 | 覆盖模型 |
| effort | string | 否 | 推理强度 |
| cwd | string | 否 | 覆盖工作目录 |
| approvalPolicy | string | 否 | |
| sandboxPolicy | object | 否 | 沙箱配置 |
| summary | string | 否 | 如 `"concise"` |
| personality | string | 否 | |
| outputSchema | object | 否 | JSON Schema，仅当前 turn |
| collaborationMode | string | 否 | 协作模式预设 |

**输入 item 类型**：

| 类型 | 字段 | 说明 |
|---|---|---|
| text | `{ "type": "text", "text": "..." }` | 文本输入 |
| image | `{ "type": "image", "url": "https://..." }` | 图片 URL |
| localImage | `{ "type": "localImage", "path": "/tmp/screenshot.png" }` | 本地图片 |
| skill | `{ "type": "skill", "name": "...", "path": "..." }` | 技能调用 |
| mention | `{ "type": "mention", "name": "...", "path": "app://..." }` | App/Connector 调用 |

响应：`{ "turn": { "id", "status": "inProgress", "items": [], "error": null } }`

### 5.2 turn/steer — 追加输入

| 字段 | 类型 | 必填 |
|---|---|---|
| threadId | string | 是 |
| input | array | 是 |
| expectedTurnId | string | 是 |

不接受 turn 级覆盖参数，不触发新的 `turn/started`。

### 5.3 turn/interrupt — 中断

| 字段 | 类型 | 必填 |
|---|---|---|
| threadId | string | 是 |
| turnId | string | 是 |

### 5.4 Turn 通知

| 通知 | 载荷 |
|---|---|
| `turn/started` | `{ "turn": { "id", "items": [], "status": "inProgress" } }` |
| `turn/completed` | `{ "turn": { "id", "status": "completed" \| "interrupted" \| "failed", "error"? } }` |
| `turn/diff/updated` | `{ "threadId", "turnId", "diff" }` — 聚合 unified diff |
| `turn/plan/updated` | `{ "turnId", "explanation?", "plan" }` — plan entries: `{ "step", "status": "pending" \| "inProgress" \| "completed" }` |

---

## 六、Item 类型

| type | 关键字段 |
|---|---|
| userMessage | `{ id, content }` — content 为 `text`, `image`, `localImage` 数组 |
| agentMessage | `{ id, text, phase? }` — phase: `"commentary"` / `"final_answer"` |
| plan | `{ id, text }` |
| reasoning | `{ id, summary, content }` — summary 为可读摘要，content 为原始推理块 |
| commandExecution | `{ id, command, cwd, status, commandActions, aggregatedOutput?, exitCode?, durationMs? }` |
| fileChange | `{ id, changes, status }` — changes: `[{ path, kind, diff }]` |
| mcpToolCall | `{ id, server, tool, status, arguments, result?, error? }` |
| dynamicToolCall | `{ id, tool, arguments, status, contentItems?, success?, durationMs? }` |
| collabToolCall | `{ id, tool, status, senderThreadId, receiverThreadId?, newThreadId?, prompt?, agentStatus? }` |
| webSearch | `{ id, query, action? }` |
| imageView | `{ id, path }` |
| enteredReviewMode | `{ id, review }` |
| exitedReviewMode | `{ id, review }` |
| contextCompaction | `{ id }` |

`webSearch.action.type` 枚举：`search`（query?, queries?）、`openPage`（url?）、`findInPage`（url?, pattern?）

### 6.1 Item 生命周期通知

- `item/started` — 工作开始时推送完整 item
- `item/completed` — 最终权威 item 状态

### 6.2 Item 增量通知

| 通知 | 说明 |
|---|---|
| `item/agentMessage/delta` | 流式 AI 文本 |
| `item/plan/delta` | 流式 plan 文本 |
| `item/reasoning/summaryTextDelta` | 可读推理摘要，`summaryIndex` 在新段落时递增 |
| `item/reasoning/summaryPartAdded` | 推理摘要段落边界 |
| `item/reasoning/textDelta` | 原始推理文本 |
| `item/commandExecution/outputDelta` | 命令 stdout/stderr |
| `item/fileChange/outputDelta` | apply_patch 工具调用响应 |

---

## 七、Review 系统

### 7.1 review/start — 启动 Review

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| threadId | string | 是 | |
| delivery | string | 否 | `"inline"`（默认）/ `"detached"` |
| target | object | 是 | 见下表 |

**target 类型**：

| 类型 | 说明 |
|---|---|
| `{ "type": "uncommittedChanges" }` | 未提交变更 |
| `{ "type": "baseBranch", ... }` | 与分支对比 |
| `{ "type": "commit", "sha": "...", "title": "..." }` | 指定 commit |
| `{ "type": "custom", ... }` | 自由指令 |

响应：`{ "turn": { id, status, items, error }, "reviewThreadId" }`

`delivery: "detached"` 时，`reviewThreadId` 为新线程 ID，触发 `thread/started`。

Review 生命周期 items：`enteredReviewMode`（reviewer 启动）、`exitedReviewMode`（reviewer 完成）。

---

## 八、命令执行

### 8.1 command/exec — 执行命令

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| command | string[] | 是 | argv 数组，空数组被拒绝 |
| cwd | string | 否 | 工作目录 |
| sandboxPolicy | object | 否 | 同 turn/start |
| timeoutMs | number | 否 | 超时（毫秒），省略用服务端默认 |
| tty | boolean | 否 | PTY 会话 |
| streamStdoutStderr | boolean | 否 | 接收 outputDelta 通知 |
| processId | string | 否 | 用于后续 write/resize/terminate |

响应：`{ "exitCode", "stdout", "stderr" }`

### 8.2 command/exec/write — 写入 stdin

向运行中的会话写入 stdin 字节或关闭 stdin。

### 8.3 command/exec/resize — 调整 PTY 大小

### 8.4 command/exec/terminate — 终止会话

### 8.5 command/exec/outputDelta — 通知

Base64 编码的 stdout/stderr 块。

---

## 九、沙箱策略

### 9.1 sandboxPolicy 类型

| 类型 | 说明 |
|---|---|
| dangerFullAccess | 无限制 |
| readOnly | 只读访问 |
| workspaceWrite | 指定根目录内可写 |
| externalSandbox | Codex 跳过自身沙箱，由调用方处理 |

### 9.2 readOnly — access 字段

- `{ "type": "fullAccess" }`（默认）
- 受限：`{ "type": "restricted", "includePlatformDefaults": boolean, "readableRoots": ["path"] }`

### 9.3 workspaceWrite 字段

- `writableRoots`: string[]
- `readOnlyAccess`: 同 readOnly.access
- `networkAccess`: boolean（workspaceWrite）/ `"restricted"` | `"enabled"`（externalSandbox）

### 9.4 externalSandbox — networkAccess

`"restricted"`（默认）/ `"enabled"`

macOS 上 `includePlatformDefaults: true` 追加平台默认 Seatbelt 策略。

---

## 十、Model 方法

### 10.1 model/list — 列出模型

| 字段 | 类型 | 说明 |
|---|---|---|
| limit | number | 页大小 |
| includeHidden | boolean | 包含 `hidden: true` 条目 |

响应：`{ "data": [model entries], "nextCursor" }`

**Model entry 字段**：

| 字段 | 类型 | 说明 |
|---|---|---|
| id | string | 模型 ID |
| model | string | 模型标识 |
| displayName | string | 显示名称 |
| hidden | boolean | 是否隐藏 |
| defaultReasoningEffort | string | 默认推理强度，如 `"medium"` |
| supportedReasoningEfforts | array | `[{ "reasoningEffort", "description" }]` |
| inputModalities | string[] | 如 `["text", "image"]`，缺失时视为 `["text", "image"]` |
| supportsPersonality | boolean | 是否支持人格 |
| isDefault | boolean | 是否默认模型 |
| upgrade | string | 推荐升级的模型 ID |
| upgradeInfo | object | 迁移元数据 |

**Agent 用途**：调用此 API 获取模型列表及能力，通过 `/api/sync/bootstrap` 返回给 Flutter。新增模型时无需更新 App。

### 10.2 experimentalFeature/list — 列出实验特性

| 字段 | 类型 |
|---|---|
| limit | number |
| cursor | string |

每个条目：`name`, `stage`, `displayName`, `description`, `announcement`, `enabled`, `defaultEnabled`

`stage` 枚举：`beta`, `underDevelopment`, `stable`, `deprecated`, `removed`

### 10.3 experimentalFeature/enablement/set — 设置实验特性

修补内存中的运行时启用状态。

### 10.4 collaborationMode/list — 列出协作模式

列出协作模式预设（实验性，无分页）。

---

## 十一、Skills 系统

### 11.1 skills/list — 列出技能

| 字段 | 类型 | 说明 |
|---|---|---|
| cwds | string[] | 按目录范围筛选技能 |
| forceReload | boolean | 从磁盘刷新 |
| perCwdExtraUserRoots | array | `[{ "cwd", "extraUserRoots": string[] }]` |

响应：`{ "data": [{ "cwd", "skills": [...], "errors": [] }] }`

**Skill entry 字段**：`name`, `description`, `enabled`, `interface`（`{ displayName, shortDescription }`）, `dependencies`（`{ tools: [...] }`）

**dependencies.tools 类型**：

| 类型 | 字段 |
|---|---|
| env_var | `{ "type": "env_var", "value": "GITHUB_TOKEN", "description": "..." }` |
| mcp | `{ "type": "mcp", "value": "...", "transport": "streamable_http", "url": "https://..." }` |

### 11.2 skills/changed — 通知

监视的本地技能文件变化时触发，应重新运行 `skills/list`。

### 11.3 skills/config/write — 写入技能配置

| 字段 | 类型 |
|---|---|
| path | string — SKILL.md 绝对路径 |
| enabled | boolean |

### 11.4 技能调用方式

在文本输入中包含 `$<skill-name>`，同时传入 `skill` 类型的 input item（含 `name` 和 `path`）。

---

## 十二、Apps（Connectors）

### 12.1 app/list — 列出 Apps

| 字段 | 类型 | 说明 |
|---|---|---|
| cursor | string | 分页 |
| limit | number | 页大小 |
| threadId | string | 否，用该线程配置进行特性门控 |
| forceRefetch | boolean | 绕过缓存 |

响应：`{ "data": [app entries], "nextCursor" }`

**App entry 字段**：`id`, `name`, `description`, `logoUrl`, `logoUrlDark`, `distributionChannel`, `branding`, `appMetadata`, `labels`, `installUrl`, `isAccessible`, `isEnabled`

### 12.2 app/list/updated — 通知

可访问或目录 apps 加载完成时触发。

### 12.3 App 调用方式

在文本中包含 `$<app-slug>`，同时传入 `mention` 类型的 input item（`path: "app://<id>"`）。

---

## 十三、Plugin 系统

### 13.1 plugin/list — 列出插件

列出发现的插件市场和插件状态，包括安装/认证策略元数据、市场加载错误、精选插件 ID、源元数据。

**Plugin source 类型**：
- `{ "type": "local", "path": "..." }`
- `{ "type": "git", "url": "...", "path": "...", "refName": "...", "sha": "..." }`
- `{ "type": "remote" }`

### 13.2 plugin/read — 读取插件

### 13.3 plugin/install — 安装插件

### 13.4 plugin/uninstall — 卸载插件

### 13.5 marketplace/add — 添加远程市场

---

## 十四、MCP 方法

### 14.1 mcpServer/oauth/login — OAuth 登录

启动已配置 MCP 服务器的 OAuth 登录，返回授权 URL，完成时触发 `mcpServer/oauthLogin/completed`。

### 14.2 mcpServerStatus/list — 列出 MCP 服务器状态

| 字段 | 类型 | 说明 |
|---|---|---|
| detail | string | `"full"` / `"toolsAndAuthOnly"` |

列出 MCP 服务器、工具、资源、认证状态，cursor + limit 分页。

### 14.3 mcpServer/resource/read — 读取 MCP 资源

### 14.4 mcpServer/tool/call — 调用 MCP 工具

### 14.5 MCP 通知

| 通知 | 载荷 |
|---|---|
| `mcpServer/startupStatus/updated` | `{ "name", "status", "error" }` |
| `mcpServer/oauthLogin/completed` | `{ "name", "success", "error?" }` |

### 14.6 config/mcpServer/reload — 重载 MCP 配置

从磁盘重载 MCP 服务器配置，为已加载线程排队刷新。

---

## 十五、文件系统方法

所有操作基于绝对路径。

| 方法 | 说明 |
|---|---|
| fs/readFile | 读取文件 |
| fs/writeFile | 写入文件 |
| fs/createDirectory | 创建目录 |
| fs/getMetadata | 获取文件/目录元数据 |
| fs/readDirectory | 列出目录内容 |
| fs/remove | 删除文件/目录 |
| fs/copy | 复制文件/目录 |
| fs/watch | 监视路径变化 |
| fs/unwatch | 停止监视 |
| fs/changed | 通知：`{ "watchId", "changedPaths": string[] }` |

---

## 十六、Config 方法

### 16.1 config/read — 读取配置

| 字段 | 类型 |
|---|---|
| includeLayers | boolean |

响应：`{ "config": { ... } }` — 有效解析后的配置

### 16.2 config/value/write — 写入配置值

| 字段 | 类型 | 说明 |
|---|---|---|
| keyPath | string | 点分隔路径 |
| value | any | 值 |
| mergeStrategy | string | `"replace"` / `"upsert"` |

### 16.3 config/batchWrite — 批量写入配置

| 字段 | 类型 |
|---|---|
| edits | `[{ keyPath, value, mergeStrategy }]` |

原子性地将多个编辑应用到 `config.toml`。

### 16.4 configRequirements/read — 读取配置需求

响应：`{ "requirements": { ... } | null }`

**requirements 字段**：
- `allowedApprovalPolicies` — string[]，如 `["onRequest", "unlessTrusted"]`
- `allowedSandboxModes` — string[]，如 `["readOnly", "workspaceWrite"]`
- `featureRequirements` — object，如 `{ "personality": true, "unified_exec": false }`
- `network.enabled` — boolean
- `network.allowedDomains` — string[]
- `network.allowUnixSockets` — string[]
- `network.dangerouslyAllowAllUnixSockets` — boolean

**Agent 用途**：读取当前配置和配置需求，生成 `config_schema`（含可选值和默认值），通过 bootstrap 返回给 Flutter。

---

## 十七、审批流程

### 17.1 命令执行审批

**消息顺序**：
1. `item/started` — pending `commandExecution`，含 `command`, `cwd` 等字段
2. `item/commandExecution/requestApproval` — 含 `itemId`, `threadId`, `turnId`, `reason?`, `command?`, `cwd?`, `commandActions?`, `proposedExecpolicyAmendment?`, `networkApprovalContext?`, `availableDecisions?`, `additionalPermissions?`
3. 客户端响应决策
4. `serverRequest/resolved`
5. `item/completed` — 最终状态

**命令执行决策值**：

| 决策 | 说明 |
|---|---|
| `"accept"` | 允许本次 |
| `"acceptForSession"` | 本会话内允许同类操作 |
| `"decline"` | 拒绝 |
| `"cancel"` | 取消整个 turn |
| `{ "acceptWithExecpolicyAmendment": { "execpolicy_amendment": ["cmd", "..."] } }` | 允许并修改策略 |

`networkApprovalContext` 字段：`host`, `protocol` — 用于托管网络访问提示。网络提示按目标（host + protocol + port）分组。

### 17.2 文件变更审批

**消息顺序**：
1. `item/started` — `fileChange`，含 proposed `changes`, `status: "inProgress"`
2. `item/fileChange/requestApproval` — 含 `itemId`, `threadId`, `turnId`, `reason?`, `grantRoot?`
3. 客户端响应
4. `serverRequest/resolved`
5. `item/completed`

**文件变更决策值**：`"accept"`, `"acceptForSession"`, `"decline"`, `"cancel"`

### 17.3 tool/requestUserInput — 请求用户输入

向用户提出 1-3 个简短问题。问题可设置 `isOther` 用于自由输入选项。

### 17.4 Dynamic Tool Calls（实验性）

流程：
1. `item/started` — `dynamicToolCall`, `status = "inProgress"`, `tool`, `arguments`
2. `item/tool/call` — 服务端请求客户端
3. 客户端响应 content items
4. `item/completed` — 最终状态, `contentItems`, `success`

### 17.5 MCP Tool-Call 审批（Apps）

有副作用的 App 工具调用可能触发 `tool/requestUserInput`，选项：Accept、Decline、Cancel。破坏性工具标注始终触发审批。

### 17.6 serverRequest/resolved — 通知

确认待处理请求已应答或已清除。载荷含 `{ "threadId", "requestId" }`。

---

## 十八、认证方法

### 18.1 account/read — 读取账户

| 字段 | 类型 | 说明 |
|---|---|---|
| refreshToken | boolean | 强制刷新 token（仅 managed ChatGPT 模式） |

响应：`{ "account": { ... } | null, "requiresOpenaiAuth": boolean }`

账户类型：`{ "type": "apiKey" }`、`{ "type": "chatgpt", "email": "...", "planType": "pro" | "plus" | "business" | ... }`、`null`

### 18.2 account/login/start — 启动登录

| 类型 | 关键字段 |
|---|---|
| apiKey | `apiKey` |
| chatgpt | 返回 `loginId`, `authUrl` |
| chatgptDeviceCode | 返回 `loginId`, `verificationUrl`, `userCode` |
| chatgptAuthTokens | `accessToken`, `chatgptAccountId`, `chatgptPlanType`（实验性） |

### 18.3 account/login/completed — 通知

`{ "loginId", "success": boolean, "error": string | null }`

### 18.4 account/login/cancel — 取消登录

### 18.5 account/logout — 登出

### 18.6 account/updated — 通知

`{ "authMode": "apikey" | "chatgpt" | "chatgptAuthTokens" | null, "planType": string | null }`

### 18.7 account/chatgptAuthTokens/refresh — 刷新 token

服务端请求，超时约 10 秒。

### 18.8 account/rateLimits/read — 读取速率限制

响应含 `rateLimits` 和 `rateLimitsByLimitId`。

**速率限制字段**：`limitId`（如 `"codex"`, `"codex_other"`）, `limitName`, `primary.usedPercent`, `primary.windowDurationMins`, `primary.resetsAt`, `secondary`, `rateLimitReachedType`, `planType`, `credits`

### 18.9 account/rateLimits/updated — 通知

速率限制变化时触发。

---

## 十九、Go 客户端实现要点

### 19.1 stdio 连接

```go
cmd := exec.Command("codex", "app-server")
stdin, _ := cmd.StdinPipe()
stdout, _ := cmd.StdoutPipe()
cmd.Stderr = logWriter
cmd.Start()

// 写入：fmt.Fprintf(stdin, "%s\n", jsonMsg)
// 读取：scanner := bufio.NewScanner(stdout); scanner.Scan()
```

### 19.2 请求/响应匹配

```go
type pendingRequest struct {
    id   int64
    resp chan JSONRPCResponse
}

// 发送时记录 pending
pending[id] = make(chan JSONRPCResponse, 1)

// 收到响应时匹配
if resp.ID != nil {
    if ch, ok := pending[*resp.ID]; ok {
        ch <- resp
    }
}
```

### 19.3 超时处理

```go
select {
case resp := <-pending[id].resp:
    return resp, nil
case <-time.After(30 * time.Second):
    return nil, ErrTimeout
case <-ctx.Done():
    return nil, ctx.Err()
}
```

### 19.4 进程管理

```go
// 优雅关闭
cmd.Process.Signal(os.Interrupt)
time.Sleep(2 * time.Second)
cmd.Process.Kill()

// 进程退出监听
go func() {
    err := cmd.Wait()
    if err != nil {
        log.Printf("codex exited: %v", err)
    }
    close(client.done)
}()
```

### 19.5 背压处理

收到 `-32001` 错误码时，等待后重试。

---

## 二十、错误处理

### 20.1 JSON-RPC 错误码

| Code | 含义 |
|---|---|
| -32700 | Parse error |
| -32600 | Invalid Request |
| -32601 | Method not found |
| -32602 | Invalid params |
| -32603 | Internal error |
| -32000 to -32099 | Server error |
| -32001 | Server overloaded（背压） |

### 20.2 Turn 失败

Turn 失败时推送 `{ error: { message, codexErrorInfo?, additionalDetails? } }`，然后 `turn/completed` 带 `status: "failed"`。

**codexErrorInfo 枚举值**：

| 值 | 说明 |
|---|---|
| ContextWindowExceeded | 上下文窗口超限 |
| UsageLimitExceeded | 使用量超限 |
| HttpConnectionFailed | HTTP 连接失败 |
| ResponseStreamConnectionFailed | 响应流连接失败 |
| ResponseStreamDisconnected | 响应流断开 |
| ResponseTooManyFailedAttempts | 失败次数过多 |
| BadRequest | 错误请求 |
| Unauthorized | 未授权 |
| SandboxError | 沙箱错误 |
| InternalServerError | 内部错误 |
| Other | 其他 |

有上游 HTTP 状态码时，在相关 codexErrorInfo 变体的 `httpStatusCode` 中转发。

### 20.3 Codex 特定错误处理

| 场景 | 处理 |
|---|---|
| thread 不存在 | 返回 404，重新创建 thread |
| turn 已在进行中 | 先 interrupt 再操作 |
| 审批超时 | 自动 decline |
| 模型不可用 | 提示切换模型 |
| API key 无效 | 提示检查配置 |
| 背压 (-32001) | 等待后重试 |

---

## 二十一、Agent 集成映射

### 21.1 Magent 使用的 Codex 方法

| Magent 功能 | Codex 方法 |
|---|---|
| 初始化连接 | `initialize` + `initialized` |
| 创建会话 | `thread/start` |
| 恢复会话 | `thread/resume` |
| 发送消息 | `turn/start` |
| 追加输入 | `turn/steer` |
| 中断生成 | `turn/interrupt` |
| 分叉会话 | `thread/fork` |
| 压缩历史 | `thread/compact/start` |
| 回滚 | `thread/rollback` |
| 获取模型列表 | `model/list` |
| 读取配置 | `config/read` + `configRequirements/read` |
| 写入配置 | `config/value/write` / `config/batchWrite` |
| 列出线程 | `thread/list` |
| 执行命令 | `command/exec` |
| 读取文件 | `fs/readFile` |
| 写入文件 | `fs/writeFile` |
| 列出 MCP 服务器 | `mcpServerStatus/list` |
| 调用 MCP 工具 | `mcpServer/tool/call` |
| 列出技能 | `skills/list` |
| 读取速率限制 | `account/rateLimits/read` |

### 21.2 通知到 ProviderEvent 映射

| Codex 通知 | ProviderEvent 类型 |
|---|---|
| `turn/started` | turn_started |
| `turn/completed` | turn_completed |
| `item/started` + agentMessage | message_start |
| `item/agentMessage/delta` | message_delta |
| `item/completed` + agentMessage | message_end |
| `item/started` + commandExecution | command_started |
| `item/commandExecution/outputDelta` | command_output |
| `item/completed` + commandExecution | command_completed |
| `item/started` + fileChange | file_change_start |
| `item/completed` + fileChange | file_change_end |
| `item/started` + mcpToolCall | mcp_tool_started |
| `item/completed` + mcpToolCall | mcp_tool_completed |
| `item/commandExecution/requestApproval` | approval_request |
| `item/fileChange/requestApproval` | approval_request |
| `thread/status/changed` | thread_status |
| `error` | error |
