# Magent

Magent 是一个远程 AI Code 控制台项目。它由一个运行在开发机器上的 Go Agent 和一个 Flutter 客户端组成：Agent 负责长期运行 AI 编码工具、管理项目和会话、读取 Git/文件状态；Flutter App 负责连接 Agent、创建/恢复会话、查看输出、审批操作、浏览变更和文件。

项目的核心目标是让手机端不直接运行 AI CLI，而是通过 HTTP/WebSocket 低流量地控制远程开发环境。

## 功能概览

- 多 Agent 连接管理：客户端可保存 Agent 地址、Token、名称和默认 Provider。
- 项目管理：通过 Agent 添加、查看、更新和删除工作区项目。
- AI 会话：支持创建会话、发送输入、恢复/停止/中断会话，并展示流式事件。
- Provider 扩展：内置 `codex`、`claude`、`aider`。(当前仅完善了codex的支持，其他站位)
- Codex App Server：Codex Provider 使用 app-server stdio 协议，支持线程、转向、审批、fork、compact、rollback 等结构化能力。
- PTY Provider：Claude 和 Aider 通过 PTY 方式运行，作为兼容型 Provider。
- Git 工作区：支持 summary、changes、file diff、stage/unstage/discard、commit、pull、push、log、branches、commit diff。
- 文件浏览：支持目录列表、文本内容读取和原始 blob 读取。
- 实时同步：WebSocket 推送会话事件和 Git 失效通知，客户端使用本地缓存降低重复请求。
- 本地缓存：Flutter 端使用 Drift/SQLite 缓存项目、Provider、会话、Git、目录和文件数据。

## 项目结构

```text
magent/
├── agent/                    # Go Agent 后端运行时
│   ├── cmd/agent/main.go     # CLI 入口：serve / init
│   ├── configs/default.yaml  # 默认配置模板
│   └── internal/
│       ├── api/              # HTTP API、WebSocket、middleware
│       ├── config/           # Viper 配置加载
│       ├── fileservice/      # 文件浏览与读取
│       ├── gitservice/       # Git 状态、diff 和操作
│       ├── project/          # 项目管理
│       ├── provider/         # Provider 抽象和注册表
│       ├── providers/        # codex / claude / aider 实现
│       ├── runner/           # PTY 运行器
│       ├── session/          # 会话管理与持久化
│       ├── storage/          # SQLite 存储
│       ├── sync/             # Bootstrap/config 同步
│       └── ws/               # WebSocket Hub
├── magent_app/               # Flutter 客户端
│   ├── lib/app/              # 应用入口、路由、Shell、生命周期同步
│   ├── lib/core/             # API、模型、Provider、Repository、缓存与同步
│   ├── lib/features/         # agents / projects / sessions / git / settings
│   ├── lib/l10n/             # 中英文本地化
│   └── pubspec.yaml
└── docs/                     # 架构、阶段计划和完成记录
```

## 技术栈

后端：

- Go 1.23
- Gin
- Gorilla WebSocket
- Cobra + Viper
- SQLite（modernc.org/sqlite）

客户端：

- Flutter / Dart SDK `^3.11.5`
- Riverpod
- go_router
- Dio
- web_socket_channel
- Drift + sqlite3_flutter_libs
- flutter_secure_storage

## 环境要求

基础环境：

- Go 1.23 或更高版本
- Flutter SDK 和 Dart SDK
- Git

可选 Provider CLI：

- `codex`：推荐 Provider，Agent 会查找 `codex` 可执行文件并通过 app-server stdio 启动。
- `claude`：PTY Provider，需要本机存在 `claude` 命令。
- `aider`：PTY Provider，需要本机存在 `aider` 命令。

Provider CLI 需要在运行 Agent 的机器上完成登录或 API Key 配置。

## 快速开始

### 1. 启动 Go Agent

```bash
cd agent
go run ./cmd/agent init
go run ./cmd/agent serve
```

`init` 会初始化配置并生成访问 Token。默认配置文件位于：

```text
~/.magent/default.yaml
```

默认服务地址是：

```text
http://127.0.0.1:9000
```

如果需要从手机连接同一局域网内的开发机器，请把配置中的 `server.host` 改为开发机器可访问的地址，例如：

```yaml
server:
  host: "0.0.0.0"
  port: 9000
```

然后重启 Agent，并在 App 中使用开发机器的局域网 IP，例如 `http://192.168.1.100:9000`。

### 2. 启动 Flutter App

```bash
cd magent_app
flutter pub get
flutter run
```

打开 App 后添加 Agent：

- URL：Agent 地址，例如 `http://192.168.1.100:9000`
- Token：`go run ./cmd/agent init` 或首次启动 Agent 时生成的 Token
- Name：自定义显示名称

连接成功后即可进入项目列表，添加项目路径并创建 AI 会话。

## Agent 配置

Agent 使用 Viper 加载配置，优先支持：

- `--config` 指定配置文件
- `~/.magent/default.yaml`
- 当前目录下的 `default.yaml`
- `MAGENT_` 前缀环境变量
- 代码内默认值

常用配置项：

```yaml
log_level: "info"

server:
  host: "127.0.0.1"
  port: 9000
  read_timeout: 30s
  write_timeout: 30s
  rate_limit_per_min: 120

auth:
  tokens:
    - name: "default"
      token: "<your-token>"
      permissions: ["*"]

workspace:
  allowed_dirs: []
  excluded_patterns:
    - ".git"
    - "node_modules"
    - ".venv"
    - "__pycache__"
```

日志级别可以通过命令行覆盖：

```bash
cd agent
go run ./cmd/agent serve --log-level debug
go run ./cmd/agent serve --log-levels codex=debug,gitwatcher=off
```

## API 概览

健康检查不需要鉴权：

```text
GET /healthz
```

业务接口使用 `/api/v1` 前缀，并通过 `Authorization: Bearer <token>` 鉴权：

```text
GET  /api/v1/agent/info
GET  /api/v1/bootstrap
GET  /api/v1/providers
GET  /api/v1/projects
POST /api/v1/projects
POST /api/v1/sessions
GET  /api/v1/sessions/:id/events
GET  /api/v1/projects/:id/git/summary
GET  /api/v1/projects/:id/git/changes
GET  /api/v1/projects/:id/files/dir
GET  /api/v1/ws
```

HTTP API 返回统一结构：

```json
{
  "ok": true,
  "data": {}
}
```

WebSocket 用于会话事件、审批请求和变更通知等实时消息。

## 开发命令

后端：

```bash
cd agent
go build ./...
go test ./...
go run ./cmd/agent serve
```

客户端：

```bash
cd magent_app
flutter pub get
flutter analyze
flutter test
dart format lib test
dart run build_runner build
```

生成代码变更后需要提交对应的 `.g.dart` 文件。

## 文档

- [项目结构说明](docs/project-structure.md)
- [总体计划](docs/plan.md)
- [通信协议计划](docs/plan/communication.md)
- [Codex App Server 集成计划](docs/plan/codex-appserver.md)
- [阶段完成记录](docs/completed)

## 安全注意事项

- 不要提交 Token、数据库文件、secure-storage 内容或机器特定配置。
- `.gitignore` 已忽略 `*.db` 和 `*.db-journal`。
- 日志、截图和测试输出中应隐藏 `Authorization: Bearer <token>`。
- 默认监听 `127.0.0.1`，如果改为 `0.0.0.0`，请只在可信网络中使用，并配置防火墙或反向代理访问控制。

## 当前状态

当前代码已经包含 Go Agent、Flutter 客户端、Codex/Claude/Aider Provider、会话、Git、文件、配置同步和本地缓存等核心模块。更长线的高级能力和阶段规划见 `docs/plan/`。
