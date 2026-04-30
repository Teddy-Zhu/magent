# Magent 总体计划

## 产品定义

手机版远程 AI Code 工具。手机端不直接运行 AI CLI，通过 Go Agent 远程控制 Codex 等 AI 编码工具，手机端只负责控制、查看、输入、审查变更。

**一句话**：Go Agent 是"远程 AI Code 运行时"，Flutter App 是"低流量远程控制台"，Codex 是第一个 Provider。

## 核心原则

1. 手机端不跑 AI CLI，Agent 负责长期运行
2. 优先使用 Provider 原生编程协议（如 Codex App Server），PTY 仅作回退
3. 所有高流量数据支持缓存、增量、分页、压缩
4. 会话不依赖手机在线，断线可恢复
5. **配置不写死在手机端**——模型列表、推理强度、窗口大小、审批策略等均从 Agent 动态获取
6. **工具调用透明可交互**——AI 使用的工具（命令执行、文件操作、MCP 工具）在手机端可见、可审批、可查看详情

## 整体架构

```
Flutter App (手机端)
├── Agent 管理（多 Agent 连接）
├── 项目管理
├── AI 会话（创建/恢复/分叉）
├── 工具调用展示（命令/文件操作/MCP 工具 可查看详情）
├── 审批响应（approve/decline 远程操作）
├── Git 工作区（四层低流量同步）
├── 文件浏览（分层加载 + hash 缓存）
├── Diff 查看（按需分页）
├── 基础数据同步（启动时从 Agent 拉取模型/配置/能力）
└── 本地缓存（SQLite）

    HTTPS / WebSocket  Token 鉴权  gzip/zstd

Go Agent (服务端)
├── HTTP API（查询类接口）
├── WebSocket Server（实时事件推送 + 心跳）
├── Auth（Token + 可选 mTLS）
├── Project Manager
├── Session Manager（持久化 + 断线恢复）
├── Provider Manager（注册/检测/调度）
├── Codex Provider（App Server 协议优先）
│   ├── App Server 客户端（jrpc2 库）
│   ├── 审批代理（转发审批到手机）
│   ├── 工具调用代理（MCP 工具转发 + 结果回传）
│   └── PTY 回退（终端模式兼容）
├── Config Service（动态配置缓存 + hash 机制）
├── Git Service（四层 diff 系统 + go-diff 库）
├── File Service（分层文件树 + hash 缓存）
├── Watch Service（fsnotify + debounce）
└── Storage（SQLite）
```

## Provider 运行模式优先级

| 优先级 | 模式 | 说明 |
|---|---|---|
| 1 | App Server (stdio) | JSON-RPC 2.0，最安全，无网络暴露 |
| 2 | App Server (WebSocket) | JSON-RPC 2.0，支持远程 App Server |
| 3 | PTY + 终端解析 | 回退方案，用于旧版 Codex 或自定义 CLI |

## 实施阶段总览

Phase 1 是基础，Phase 2/3/4 可并行开发（它们只依赖 Phase 1），Phase 5 汇总。

```
Phase 1（2 周）
  ├──→ Phase 2（3 周）Codex + Session
  ├──→ Phase 3（2 周）Git 系统      ──→ Phase 5（2 周）产品化
  └──→ Phase 4（1.5 周）文件系统  ─┘
                                        ├──→ Phase 6（1.5 周）Provider 扩展
                                        └──→ Phase 7（2 周）高级功能
```

| 阶段 | 主题 | 周期 | 前置 | 详细文档 |
|---|---|---|---|---|
| Phase 1 | 基础框架 | 2 周 | 无 | [phase1-foundation.md](plan/phase1-foundation.md) |
| Phase 2 | Codex Provider + 会话系统 | 3 周 | P1 | [phase2-codex-session.md](plan/phase2-codex-session.md) |
| Phase 3 | Git 低流量系统 | 2 周 | P1 | [phase3-git.md](plan/phase3-git.md) |
| Phase 4 | 文件低流量系统 | 1.5 周 | P1 | [phase4-files.md](plan/phase4-files.md) |
| Phase 5 | 操作能力 + 产品化 | 2 周 | P2+P3+P4 | [phase5-operations.md](plan/phase5-operations.md) |
| Phase 6 | Provider 扩展 | 1.5 周 | P5 | [phase6-providers.md](plan/phase6-providers.md) |
| Phase 7 | 高级功能 | 2 周 | P5 | [phase7-advanced.md](plan/phase7-advanced.md) |

**并行后总周期：~8.5 周**（Phase 1 + max(Phase 2,3,4) + Phase 5 + max(Phase 6,7)）

## 横切关注点

| 主题 | 详细文档 |
|---|---|
| 通信协议（HTTP API + WebSocket 事件） | [communication.md](plan/communication.md) |
| Codex App Server 协议集成细节 | [codex-appserver.md](plan/codex-appserver.md) |

## 技术栈

**Go Agent**：
- Web: gin-gonic/gin
- WebSocket: gorilla/websocket
- JSON-RPC 2.0: **creachadair/jrpc2**（替代手写，支持 stdio/自定义 channel）
- Diff 解析: **sourcegraph/go-diff**（生产级 unified diff 解析）
- PTY: creack/pty
- 文件监听: fsnotify/fsnotify
- SQLite: modernc.org/sqlite（WAL 模式 + `SetMaxOpenConns(1)`）
- 压缩: klauspost/compress（含 gzhttp 自动协商）
- 配置: spf13/viper + spf13/cobra
- 日志: go.uber.org/zap
- TOML: BurntSushi/toml
- UUID: google/uuid

**Flutter App**：
- HTTP: dio
- WebSocket: web_socket_channel
- 状态管理: flutter_riverpod
- 路由: go_router
- SQLite: drift + sqlite3_flutter_libs
- 安全存储: flutter_secure_storage（仅存主密钥，Agent 信息存 Drift）
- 模型序列化: **freezed + json_serializable**（代码生成，替代手写 fromJson/toJson）
- 本地通知: flutter_local_notifications
- UI: flutter_markdown, highlight, xterm

## MVP 边界（收窄版）

**第一轮 MVP（4-5 周，跑通核心链路）**：
- Phase 1：基础框架
- Phase 2：Codex Provider（**仅 stdio 模式**）+ 基础会话（创建/输出/停止）
- Phase 3 简化版：Git Summary + Changes（不做 Diff 分页）
- Phase 4 简化版：目录列表 + 文件读取（不做分页）
- 动态配置同步（bootstrap + hash 机制）
- Token 鉴权

**第二轮 MVP（+3 周）**：
- Phase 2 补全：审批代理、断线恢复、工具调用展示
- Phase 3 补全：Diff 分页、Git Watcher
- Phase 4 补全：文件分页、写入操作
- Phase 5：Git 操作、Session 高级功能

**暂不做**：
- 多用户/团队权限、云同步
- 完整 IDE 编辑器、LSP
- Claude/Aider/Qwen Provider（Phase 6）
- Push 通知、加密备份（Phase 7）

## 关键约束

| 约束 | 处理方式 |
|---|---|
| Codex App Server 协议可能变化 | Phase 2 首日做协议验证，确认后再编码 |
| 事件通道不能成为瓶颈 | per-session channel，不使用共享 channel |
| WebSocket 死连接 | 30s ping/60s pong 超时断开 + 每 token 最多 5 连接 |
| SQLite 并发写入 | WAL 模式 + `SetMaxOpenConns(1)` |
| 断线恢复数据量 | 最大回放 1000 条事件，超出提示全量刷新 |

## 工程规范

**统一响应格式**：封装工具函数，禁止裸 `c.JSON()` 调用。

```go
// internal/api/response.go
func OK(c *gin.Context, data any) {
    c.JSON(200, gin.H{"ok": true, "data": data})
}
func Fail(c *gin.Context, httpCode int, errCode, msg string) {
    c.JSON(httpCode, gin.H{"ok": false, "error": gin.H{"code": errCode, "message": msg}})
}
func NotModified(c *gin.Context) {
    c.Status(304)
}
```

**健康检查**：`GET /healthz`（无需鉴权），返回 Agent 版本 + 运行状态。

**结构化日志**：zap + request_id 链路追踪。
