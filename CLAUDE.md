# Magent

手机版远程 AI Code 工具。Go Agent 是"远程 AI Code 运行时"，Flutter App 是"低流量远程控制台"，Codex 是第一个 Provider。

## 项目结构

```
magent/
├── agent/                    # Go Agent 后端 (Go 1.23, Gin + SQLite)
│   ├── cmd/agent/main.go     # 入口 (cobra: serve / init)
│   ├── internal/
│   │   ├── api/              # HTTP API + WebSocket (router.go 定义所有路由)
│   │   ├── fileservice/      # 文件服务 (hash 缓存, 分页读取)
│   │   ├── gitservice/       # Git 服务 (summary/changes/diff/watcher)
│   │   ├── codex/            # Codex Provider (JSON-RPC 2.0 over stdio)
│   │   ├── config/           # Viper 配置 (env prefix: MAGENT_)
│   │   ├── project/          # 项目管理 CRUD
│   │   ├── protocol/         # JSON-RPC 2.0 类型定义
│   │   ├── provider/         # Provider 接口 + Registry
│   │   ├── session/          # Session 生命周期管理 + 持久化
│   │   ├── storage/          # SQLite (WAL, MaxOpenConns=1) + 迁移
│   │   ├── sync/             # Bootstrap 配置同步 (hash 机制)
│   │   └── ws/               # WebSocket Hub (心跳 30s/60s)
│   └── configs/default.yaml
│
├── magent_app/               # Flutter App (Dart ^3.11.5)
│   ├── lib/
│   │   ├── app/              # MaterialApp, GoRouter 路由
│   │   ├── core/
│   │   │   ├── api/          # Dio HTTP + WebSocket 客户端
│   │   │   ├── models/       # Agent, Project 模型
│   │   │   ├── providers/    # Riverpod Provider (API 客户端工厂)
│   │   │   ├── storage/      # flutter_secure_storage
│   │   │   └── sync/         # Bootstrap 同步
│   │   ├── features/
│   │   │   ├── agents/       # Agent 连接/列表页
│   │   │   ├── projects/     # 项目列表/详情页 (3-Tab: 会话/变更/文件)
│   │   │   ├── sessions/     # 会话创建/聊天页
│   │   │   ├── git/          # Git 管理 (manage/ + widgets/)
│   │   │   └── settings/     # 设置页面 (缓存管理)
│   │   └── shared/widgets/   # 共享组件
│   └── pubspec.yaml
│
└── docs/                     # 文档
    ├── plan.md               # 总体计划
    ├── plan/                 # Phase 1-7 详细计划 + 协议文档
    └── completed/            # Phase 1, 2 完成对账
```

## 开发命令

```bash
# Go Agent
cd agent && go build ./...                    # 编译
cd agent && go run ./cmd/agent serve          # 运行服务
cd agent && go run ./cmd/agent init           # 初始化配置/生成 token

# Flutter App
cd magent_app && flutter pub get              # 安装依赖
cd magent_app && flutter run                  # 运行
cd magent_app && flutter analyze              # 静态分析
cd magent_app && dart run build_runner build  # 代码生成 (freezed/drift)
```

## 架构要点

### 通信协议
- HTTP API: 查询类接口 (项目/会话 CRUD, 配置同步)
- WebSocket: 实时事件推送 + 心跳 (per-session channel, 不用共享 channel)
- 鉴权: Token middleware (header: `Authorization: Bearer <token>`)
- 压缩: gzip/zstd 自动协商
- 统一响应: `OK(c, data)` / `Fail(c, httpCode, errCode, msg)` / `NotModified(c)`

### Provider 系统
- 接口: `provider.Provider` (Detect, CreateSession, ResumeSession, ForkSession, SendInput, InterruptSession, StopSession, Subscribe, Capabilities...)
- 当前实现: 仅 Codex Provider (stdio JSON-RPC 2.0)
- 优先级: App Server (stdio) > App Server (WebSocket) > PTY 回退
- 未来扩展: Claude, Aider (Phase 6)

### Session 管理
- Session Manager 负责生命周期: 创建/恢复/分叉/停止/输入/中断
- 事件流: per-session 订阅 -> 顺序编号 -> SQLite 持久化 -> WebSocket 广播
- 断线恢复: 最大回放 1000 条事件，超出提示全量刷新

### SQLite 约束
- WAL 模式 + `SetMaxOpenConns(1)` 单连接写入
- 已有 10 张表 (projects, sessions, session_events, git_state, git_file_changes, git_diff_cache, file_cache, dir_cache, audit_log, bootstrap_cache)

### Flutter 状态管理
- Riverpod (`ProviderScope` 包裹根 widget)
- GoRouter 声明式路由
- Dio HTTP 客户端 + WebSocket 客户端
- flutter_secure_storage 仅存主密钥，Agent 信息存 Drift

## 当前进度

| 阶段 | 状态 | 说明 |
|---|---|---|
| Phase 1: 基础框架 | 已完成 | HTTP/WS, SQLite, Project CRUD, 鉴权 |
| Phase 2: Codex + Session | 已完成 | Provider, JSON-RPC, 审批代理, 会话生命周期 |
| Phase 3: Git 同步 | 已完成 | Summary/Changes/Diff + Watcher |
| Phase 4: 文件浏览 | 已完成 | 目录列表 + 文件读取 + 缓存 |
| Phase 5: 操作+产品化 | 已完成 | Git 操作 + Session 高级功能 + 中间件 + 设置页 |
| Phase 6: Provider 扩展 | 已完成 | PTY Runner + Claude/Aider Provider + 动态 UI |
| Phase 7 | 未开始 | 见 docs/plan/ |

**下一步**: Phase 7 (高级功能)。

## 工程规范

- 统一响应: 使用 `response.go` 的 `OK/Fail/NotModified`，禁止裸 `c.JSON()`
- 健康检查: `GET /healthz` 无需鉴权
- 结构化日志: zap + request_id
- 配置: Viper 环境变量覆盖 (前缀 `MAGENT_`)
- Flutter 模型: 使用 freezed + json_serializable 代码生成
- WebSocket: 每 token 最多 5 连接，30s ping / 60s pong 超时断开

## 关键约束

| 约束 | 处理 |
|---|---|
| Codex App Server 协议可能变化 | Phase 2 首日做协议验证 |
| SQLite 并发写入 | WAL + 单连接 |
| 断线恢复数据量 | 最大 1000 条事件回放 |
| 事件通道瓶颈 | per-session channel |
| Git 中文文件名乱码 | 所有 git 命令必须加 `-c core.quotepath=false`，否则中文路径显示为 `\277\253` 八进制转义 |

### Git 命令规范

所有 git 命令通过 `gitservice.Service.Git()` 统一执行，已内置以下配置：
- `-c core.quotepath=false` — 禁止路径转义，保证中文文件名正常显示
- `-c log.showSignature=false` — 跳过 GPG 签名验证，避免输出干扰

**注意**: 如果新增 git 命令不通过 `Service.Git()` 执行，必须手动添加上述参数。
