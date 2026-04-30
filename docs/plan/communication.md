# 通信协议设计

## 一、HTTP API 总览

### 1.1 Agent 信息

```
GET /api/agent/info

Response:
{
  "version": "0.1.0",
  "providers": ["codex", "claude", "aider"],
  "capabilities": {
    "max_concurrent_sessions": 10,
    "supports_websocket": true,
    "supports_compression": ["gzip", "zstd"]
  }
}
```

### 1.2 项目管理

```
GET    /api/projects                  # 列表
POST   /api/projects                  # 创建
GET    /api/projects/:id              # 详情
PUT    /api/projects/:id              # 更新
DELETE /api/projects/:id              # 删除

POST Body:
{
  "name": "my-project",
  "path": "/home/user/project",
  "default_provider": "codex"
}

Response:
{
  "id": "proj_xxx",
  "name": "my-project",
  "path": "/home/user/project",
  "default_provider": "codex",
  "created_at": 1710000000,
  "updated_at": 1710000000
}
```

### 1.3 会话管理

```
GET    /api/sessions?project_id=p1    # 列表
POST   /api/sessions                  # 创建
GET    /api/sessions/:id              # 详情
PUT    /api/sessions/:id              # 更新（title, config）
DELETE /api/sessions/:id              # 删除/归档
POST   /api/sessions/:id/input        # 发送输入
POST   /api/sessions/:id/interrupt    # 中断
POST   /api/sessions/:id/stop         # 停止
POST   /api/sessions/:id/fork         # 分叉
POST   /api/sessions/:id/compact      # 压缩历史
POST   /api/sessions/:id/rollback     # 回滚
GET    /api/sessions/:id/events?after_seq=N&limit=100  # 增量事件
POST   /api/sessions/:id/approve      # 审批决策
POST   /api/sessions/:id/export?format=markdown  # 导出

创建会话 POST Body:
{
  "provider": "codex",
  "project_id": "proj_xxx",
  "model": "gpt-5.5",
  "approval_policy": "on-request",
  "sandbox_mode": "workspace-write",
  "prompt": "修复登录 bug"
}

审批 POST Body:
{
  "approval_id": "approval_xxx",
  "action": "accept"  // accept | acceptForSession | decline | cancel
}
```

### 1.4 Git 管理

```
GET  /api/git/summary?project_id=p1
GET  /api/git/changes?project_id=p1&base_version=41
GET  /api/git/diff/file?project_id=p1&path=x&diff_hash=abc&offset=0&limit=200
POST /api/git/stage           {project_id, paths: [...]}
POST /api/git/unstage         {project_id, paths: [...]}
POST /api/git/discard         {project_id, paths: [...], staged: false}
POST /api/git/commit          {project_id, message, all: false}
POST /api/git/push            {project_id, remote, branch, force}
GET  /api/git/log?project_id=p1&limit=50&offset=0
GET  /api/git/branches?project_id=p1
```

### 1.5 文件管理

```
GET  /api/files/list?project_id=p1&path=internal&known_hash=abc
GET  /api/files/read?project_id=p1&path=main.go&hash=abc
GET  /api/files/read/lines?project_id=p1&path=x&start=1&limit=200
GET  /api/files/read/range?project_id=p1&path=x&offset=0&limit=65536
POST /api/files/write          {project_id, path, content}
POST /api/files/create         {project_id, path, is_dir}
POST /api/files/delete         {project_id, path}
POST /api/files/rename         {project_id, old_path, new_path}
```

### 1.6 Provider

```
GET /api/providers                          # 列表 + 状态
GET /api/providers/:name/capabilities       # 能力
GET /api/providers/:name/models             # 可用模型
GET /api/providers/:name/config-schema      # 配置 Schema（含可选值）
```

### 1.7 Codex 配置

```
GET /api/codex/config
PUT /api/codex/config     {model, approval_policy, sandbox_mode, ...}
```

### 1.8 基础数据同步（App 启动时）

Flutter 启动或连接 Agent 时，同步基础配置数据。**带版本号，有变化才拉取全量数据**。

**Agent 端缓存机制**：
- Agent 维护一份 bootstrap 缓存（内存 + SQLite 持久化）
- 缓存内容变化时（Provider 检测完成、配置变更、项目增删、MCP 变化等），重新计算 config_hash
- config_hash 基于所有缓存内容的 SHA256 计算
- 提供轻量级 check 接口，仅返回 hash 值

```
# 轻量检查（推荐，每次连接时调用）
GET /api/sync/check

Response:
{
  "config_hash": "a1b2c3d4e5f6",
  "updated_at": 1710000000
}

# 全量拉取（仅在 hash 变化时调用）
GET /api/sync/bootstrap

# Flutter 传入本地 hash，Agent 对比后决定是否返回全量
# 如果 hash 匹配，返回 304
# 如果 hash 不匹配，返回全量数据 + 新 hash

Query: ?local_hash=a1b2c3d4e5f6

Response (200):
{
  "config_hash": "f6e5d4c3b2a1",
  "updated_at": 1710000001,
  "agent": {
    "version": "0.1.0",
    "capabilities": {
      "max_concurrent_sessions": 10,
      "supports_websocket": true,
      "supports_compression": ["gzip", "zstd"]
    }
  },
  "providers": [
    {
      "name": "codex",
      "status": "available",
      "version": "0.35.0",
      "run_mode": "app-server-stdio",
      "capabilities": {
        "protocol": "app-server-stdio",
        "supports_resume": true,
        "supports_fork": true,
        "supports_approval": true,
        "supports_mcp": true,
        ...
      },
      "config_schema": {
        "model": {
          "type": "enum",
          "values": ["gpt-5.4", "gpt-5.5", "o3", "o4-mini"],
          "default": "gpt-5.4",
          "label": "模型"
        },
        "approval_policy": {
          "type": "enum",
          "values": ["untrusted", "on-request", "never"],
          "default": "on-request",
          "label": "审批策略",
          "descriptions": {
            "untrusted": "最严格，所有操作都需要审批",
            "on-request": "仅在需要时请求审批",
            "never": "从不请求审批（危险）"
          }
        },
        "sandbox_mode": {
          "type": "enum",
          "values": ["read-only", "workspace-write", "danger-full-access"],
          "default": "workspace-write",
          "label": "沙箱模式"
        },
        "reasoning_effort": {
          "type": "enum",
          "values": ["low", "medium", "high"],
          "default": "medium",
          "label": "推理强度"
        },
        "web_search": {
          "type": "enum",
          "values": ["off", "cached", "on"],
          "default": "cached",
          "label": "网络搜索"
        }
      },
      "presets": [
        {
          "name": "快速提问",
          "description": "只读模式，适合问问题",
          "config": {"sandbox_mode": "read-only", "approval_policy": "on-request"}
        },
        {
          "name": "自动编码",
          "description": "工作区可写，自动审批",
          "config": {"sandbox_mode": "workspace-write", "approval_policy": "on-request"}
        },
        {
          "name": "完全信任",
          "description": "跳过所有审批，仅限隔离环境",
          "config": {"sandbox_mode": "danger-full-access", "approval_policy": "never"}
        }
      ],
      "mcp_servers": [
        {
          "name": "github",
          "description": "GitHub API 集成",
          "tools": ["search_repos", "create_pr", "list_issues"]
        }
      ]
    },
    {
      "name": "claude",
      "status": "unavailable",
      "error": "not installed",
      ...
    }
  ],
  "projects": [
    {"id": "proj_xxx", "name": "my-project", "default_provider": "codex"}
  ],
  "workspace": {
    "allowed_dirs": ["/home/user/work"],
    "excluded_patterns": [".git", "node_modules"]
  }
}

Response (304):
无 Body，表示本地缓存仍有效
```

**设计要点**：
- **两级同步**：先 check（~100B），hash 变化才拉全量（~2-5KB）
- Flutter 启动时：调用 check → hash 不变则用本地缓存，hash 变化则拉全量
- 每次重新连接 Agent 时：同样先 check
- 模型列表、推理强度等选项完全由 Agent 决定，Flutter 只负责渲染
- 新增 Provider 或模型时，无需更新 Flutter App
- MCP 工具列表也通过此接口获取
- Agent 端缓存避免每次请求都重新检测 Provider 和读取配置

### 1.9 统一响应格式

```json
// 成功
{ "ok": true, "data": {...} }

// 错误
{ "ok": false, "error": { "code": "NOT_FOUND", "message": "...", "detail": "..." } }

// 304 Not Modified（Git summary、文件 hash 匹配时）
HTTP 304 无 Body
```

---

## 二、WebSocket 事件

### 2.1 连接

```
ws://agent:9000/api/ws?token=xxx

升级成功后，Agent 发送：
{ "type": "connected", "data": { "version": "0.1.0" } }
```

### 2.2 事件格式

```json
{
  "type": "session.output",
  "seq": 1024,
  "session_id": "sess_xxx",
  "time": 1710000000,
  "data": {}
}
```

- `type`：事件类型
- `seq`：序列号（每个 session 独立递增）
- `session_id`：所属会话
- `time`：Unix 时间戳
- `data`：事件数据

### 2.3 事件类型

| 类型 | data 示例 | 说明 |
|---|---|---|
| `connected` | `{version}` | 连接成功 |
| `session.created` | `{session}` | 会话创建 |
| `session.started` | `{}` | 会话开始 |
| `session.output` | `{content}` | AI 文本输出 |
| `session.turn_started` | `{}` | Turn 开始 |
| `session.turn_completed` | `{usage}` | Turn 完成（含 token 统计） |
| `session.turn_failed` | `{error}` | Turn 失败 |
| `session.item_started` | `{id, type, ...}` | 项开始 |
| `session.item_completed` | `{id, type, ...}` | 项完成 |
| `session.command_started` | `{id, command, cwd}` | 命令开始执行 |
| `session.command_completed` | `{id, command, output, exit_code}` | 命令执行完成 |
| `session.file_read` | `{id, path}` | AI 读取文件 |
| `session.file_write` | `{id, path, additions, deletions}` | AI 写入文件 |
| `session.message` | `{text}` | AI 消息 |
| `session.mcp_tool_started` | `{id, server, tool, args}` | MCP 工具调用开始 |
| `session.mcp_tool_completed` | `{id, server, tool, result}` | MCP 工具调用完成 |
| `session.approval_request` | `{id, type, command/path/tool, ...}` | 审批请求 |
| `session.approval_resolved` | `{id, action}` | 审批已解决 |
| `session.status_changed` | `{status}` | 状态变化 |
| `session.error` | `{code, message}` | 错误 |
| `session.exited` | `{exit_code}` | 会话退出 |
| `git.changed` | `{project_id, summary}` | Git 状态变化 |
| `file.changed` | `{project_id, path}` | 文件变化 |

### 2.4 断线恢复

```json
// Flutter 重连后发送：
{
  "type": "session.attach",
  "session_id": "sess_xxx",
  "last_seq": 1020
}

// Agent 返回 seq 1021 之后的所有事件
```

### 2.5 事件压缩策略

- **输出合并**：50ms 窗口内的小 chunk 合并为一个 `session.output` 事件
- **WebSocket permessage-deflate**：协议层压缩
- **HTTP gzip/zstd**：响应压缩

---

## 三、安全

### 3.1 认证

- 所有 HTTP 请求需要 `Authorization: Bearer <token>` Header
- WebSocket 连接需要 `?token=xxx` Query 参数
- Token 在配置文件中定义，支持多个

### 3.2 权限

```yaml
tokens:
  - name: "iphone"
    token: "xxxx"
    permissions: ["read", "write", "session", "git", "approve"]
  - name: "readonly"
    token: "yyyy"
    permissions: ["read"]
```

权限矩阵：

| 权限 | HTTP | WS |
|---|---|---|
| read | GET 请求 | 接收事件 |
| write | POST/PUT/DELETE | - |
| session | 会话操作 | 审批响应 |
| git | Git 操作 | - |
| approve | 审批响应 | - |

### 3.3 限流

- HTTP：60 req/min per token
- WebSocket：20 msg/sec per connection
- 审批超时：120s 无响应自动 decline

---

## 四、压缩

### 4.1 HTTP 响应压缩

```
客户端请求头：Accept-Encoding: gzip, zstd
服务端响应头：Content-Encoding: zstd (或 gzip)
```

### 4.2 WebSocket 压缩

```
使用 permessage-deflate 扩展
gorilla/websocket 默认支持
```

### 4.3 数据压缩策略

| 数据类型 | 压缩方式 | 压缩率 |
|---|---|---|
| Git Summary | 不压缩（~200B） | - |
| Git Changes | gzip | ~60% |
| Diff Content | gzip | ~70% |
| 文件内容 | gzip | ~60-80% |
| Session Events | gzip | ~50% |

---

## 五、WebSocket 心跳

```
Agent → Flutter: ping 每 30s 一次
Flutter → Agent: pong 响应
超时：60s 无 pong → 断开连接
最大连接数：每个 token 最多 5 个连接
```

---

## 六、错误处理与重试

### 6.1 HTTP 重试策略（Flutter 端）

```dart
// 网络请求重试配置
class RetryPolicy {
  static const maxRetries = 3;
  static const baseDelay = Duration(seconds: 1);
  static const maxDelay = Duration(seconds: 10);

  // 指数退避：1s → 2s → 4s
  // 只重试 5xx 和网络错误，不重试 4xx
  // 401 不重试（token 无效）
  // 429 不重试（限流，等待 Retry-After）
}

// Dio 拦截器
class RetryInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != null &&
        err.response!.statusCode! < 500) {
      return handler.next(err); // 4xx 不重试
    }
    // 指数退避重试...
  }
}
```

### 6.2 Codex 进程崩溃恢复（Agent 端）

```go
// App Server 进程退出后的处理
func (c *AppServerClient) waitProcess() {
    err := c.cmd.Wait()
    close(c.done)

    if err != nil {
        // 非正常退出 → 尝试重启（最多 3 次）
        if c.restartCount < 3 {
            c.restartCount++
            time.Sleep(time.Duration(c.restartCount) * time.Second)
            c.reconnect()
        } else {
            // 标记 session 为 "failed"
            c.events <- ProviderEvent{Type: "session.error", Payload: map[string]any{
                "code": "PROCESS_CRASHED",
                "message": "codex process crashed after 3 restart attempts",
            }}
        }
    }
}
```

### 6.3 WebSocket 断线恢复（Flutter 端）

```dart
// 断线恢复策略
class WsReconnectPolicy {
  static const initialDelay = Duration(seconds: 2);
  static const maxDelay = Duration(seconds: 30);
  static const maxRetries = 10; // 超过 10 次提示用户手动重连

  // 指数退避：2s → 4s → 8s → 16s → 30s → 30s → ...
  // 重连后发送 session.attach {last_seq} 恢复事件流
  // 超过 maxRetries → 显示"连接断开，请检查网络"
}
```

### 6.4 SQLite 并发安全

```
Go Agent:
  - db.SetMaxOpenConns(1)  // SQLite 单写者
  - WAL 模式允许并发读
  - busy_timeout=5000ms 避免锁冲突

Flutter (Drift):
  - Drift 内部处理连接池
  - 写操作串行执行
  - 读操作可并发
```
