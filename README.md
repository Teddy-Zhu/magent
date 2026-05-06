# Magent

<p align="center">
  <strong>📱 用手机远程驾驶你的 AI Coding 工具</strong>
</p>

<p align="center">
  <a href="https://github.com/Teddy-Zhu/magent/stargazers"><img src="https://img.shields.io/github/stars/Teddy-Zhu/magent?style=flat&logo=github" alt="Stars"></a>
  <a href="https://github.com/Teddy-Zhu/magent/issues"><img src="https://img.shields.io/github/issues/Teddy-Zhu/magent" alt="Issues"></a>
  <a href="https://github.com/Teddy-Zhu/magent/pulls"><img src="https://img.shields.io/github/issues-pr/Teddy-Zhu/magent" alt="Pull Requests"></a>
  <a href="https://github.com/Teddy-Zhu/magent/commits"><img src="https://img.shields.io/github/last-commit/Teddy-Zhu/magent" alt="Last Commit"></a>
</p>

<p align="center">
  <strong>🖥️ Agent (Go)</strong><br/>
  <a href="https://github.com/Teddy-Zhu/magent/releases?q=magent-agent"><img src="https://img.shields.io/github/v/release/Teddy-Zhu/magent?filter=magent-agent-*&label=agent%20release&color=00ADD8&logo=go" alt="Agent Release"></a>
  <a href="https://github.com/Teddy-Zhu/magent/actions/workflows/release-agent.yml"><img src="https://img.shields.io/github/actions/workflow/status/Teddy-Zhu/magent/release-agent.yml?label=agent%20build&logo=githubactions" alt="Agent Build"></a>
  <img src="https://img.shields.io/badge/Go-1.23%2B-00ADD8?logo=go&logoColor=white" alt="Go">
  <img src="https://img.shields.io/badge/Linux-amd64%20%7C%20arm64-FCC624?logo=linux&logoColor=black" alt="Linux">
</p>

<p align="center">
  <strong>📱 App (Flutter)</strong><br/>
  <a href="https://github.com/Teddy-Zhu/magent/releases?q=magent-android"><img src="https://img.shields.io/github/v/release/Teddy-Zhu/magent?filter=magent-android-*&label=android%20release&color=3DDC84&logo=android&logoColor=white" alt="Android Release"></a>
  <a href="https://github.com/Teddy-Zhu/magent/releases?q=magent-ios"><img src="https://img.shields.io/github/v/release/Teddy-Zhu/magent?filter=magent-ios-*&label=ios%20release&color=000000&logo=apple&logoColor=white" alt="iOS Release"></a>
  <a href="https://github.com/Teddy-Zhu/magent/actions/workflows/release-android.yml"><img src="https://img.shields.io/github/actions/workflow/status/Teddy-Zhu/magent/release-android.yml?label=android%20build&logo=githubactions" alt="Android Build"></a>
  <a href="https://github.com/Teddy-Zhu/magent/actions/workflows/release-ios.yml"><img src="https://img.shields.io/github/actions/workflow/status/Teddy-Zhu/magent/release-ios.yml?label=ios%20build&logo=githubactions" alt="iOS Build"></a>
  <img src="https://img.shields.io/badge/Flutter-3.11%2B-02569B?logo=flutter&logoColor=white" alt="Flutter">
</p>

Magent 是一个 **远程 AI Code 控制台** 项目。它由一个运行在开发机器上的 **Go Agent** 和一个 **Flutter 客户端** 组成：

- 🖥️ **Agent**：在开发机上长期运行 AI 编码工具（Codex/Claude/Aider），托管项目和会话，读取 Git/文件状态。
- 📱 **Flutter App**：在手机或平板上连接 Agent，创建/恢复会话、查看输出、审批操作、浏览变更和文件。

> 核心目标：**让手机端不直接运行 AI CLI**，而是通过 HTTP / WebSocket 以低流量方式控制远程开发环境，把开发机的算力、SSH Key、登录凭证留在它该在的地方。

---

## 📖 目录

- [✨ 特性](#-特性)
- [🎯 适用场景](#-适用场景)
- [🏗️ 架构设计](#️-架构设计)
- [🚀 快速开始](#-快速开始)
- [📦 Agent 编译与安装](#-agent-编译与安装)
- [⚙️ Agent 配置](#️-agent-配置)
- [📡 API 概览](#-api-概览)
- [🛠️ 开发指南](#️-开发指南)
- [🗺️ 路线图](#️-路线图)
- [❓ 常见问题](#-常见问题)
- [🔒 安全注意事项](#-安全注意事项)
- [🤝 贡献](#-贡献)
- [📄 许可证](#-许可证)
- [🙏 致谢](#-致谢)

---

## ✨ 特性

| 模块 | 能力 |
| --- | --- |
| 🔌 多 Agent 连接管理 | 客户端可保存多个 Agent 的地址、Token、名称和默认 Provider |
| 📂 项目管理 | 通过 Agent 添加、查看、更新和删除工作区项目 |
| 🤖 AI 会话 | 创建、发送输入、恢复 / 停止 / 中断会话，流式事件展示 |
| 🧩 Provider 扩展 | 内置 `codex`、`claude`、`aider`（当前仅完善 codex 支持，其他为占位） |
| ⚡ Codex App Server | 使用 app-server stdio 协议，支持线程、转向、审批、fork、compact、rollback 等结构化能力 |
| 🖧 PTY Provider | Claude / Aider 通过 PTY 方式运行，作为兼容型 Provider |
| 🌳 Git 工作区 | summary、changes、file diff、stage / unstage / discard、commit、pull、push、log、branches、commit diff |
| 📁 文件浏览 | 目录列表、文本内容读取、原始 blob 读取 |
| 🔄 实时同步 | WebSocket 推送会话事件和 Git 失效通知 |
| 💾 本地缓存 | Flutter 端使用 Drift / SQLite 缓存项目、Provider、会话、Git、目录和文件数据 |
| 🔐 鉴权 & 限流 | Token Bearer 鉴权 + 每分钟速率限制 + WebSocket 连接配额 |
| 📦 跨平台发布 | GitHub Actions 自动构建 Linux amd64 / arm64 Agent、Android、iOS 客户端 |

---

## 🎯 适用场景

- 📲 **离开电脑也想推进任务**：通勤、出差、躺在沙发上，让 AI 在你台式机上继续干活。
- 🔋 **节省手机算力 / 流量**：AI 推理和大文件处理留在开发机，App 只接收增量事件。
- 🔑 **凭证不落手机**：API Key、Git SSH Key、登录态都在开发机上，不需要拷到移动端。
- 🧪 **多机器并行 AI 编码**：在 App 中同时连接多台开发机，分别跑不同任务。
- 🛂 **结构化审批流**：在外面也能查看 AI 想执行的命令并决定是否放行。

---

## 🏗️ 架构设计

```text
┌────────────────────────┐         ┌─────────────────────────────────────────┐
│      Flutter App       │         │             Go Agent (server)           │
│ ────────────────────── │         │ ─────────────────────────────────────── │
│  Riverpod / GoRouter   │  HTTP   │   Gin Router  ─►  Auth / Rate Limit     │
│  Dio + WebSocket       │ ◄────►  │   ┌───────────────┬──────────────────┐  │
│  Drift (SQLite cache)  │   WS    │   │ Project Mgr   │  File / Git Svc  │  │
│  flutter_secure_storage│         │   │ Session Mgr   │  WS Hub (heartbt)│  │
│                        │         │   └──────┬────────┴────────┬─────────┘  │
└────────────────────────┘         │          ▼                 ▼            │
                                   │   ┌───────────────┐ ┌─────────────────┐ │
                                   │   │  Provider     │ │   SQLite (WAL)  │ │
                                   │   │  Registry     │ │  10 张表持久化  │ │
                                   │   └──────┬────────┘ └─────────────────┘ │
                                   │          ▼                              │
                                   │  ┌───────────┬───────────┬───────────┐  │
                                   │  │  Codex    │  Claude   │  Aider    │  │
                                   │  │ (stdio    │  (PTY)    │  (PTY)    │  │
                                   │  │  JSON-RPC)│           │           │  │
                                   │  └───────────┴───────────┴───────────┘  │
                                   └─────────────────────────────────────────┘
                                                     │
                                                     ▼
                                           ┌──────────────────┐
                                           │  开发机文件 / Git │
                                           └──────────────────┘
```

**通信约定**

- HTTP API：项目 / 会话 CRUD、文件读取、Git 查询、配置同步等查询类接口。
- WebSocket：会话事件流、审批请求、Git 失效通知；30s ping / 60s pong；每 token 最多 5 连接。
- 鉴权：`Authorization: Bearer <token>`。
- 压缩：gzip / zstd 自动协商。
- 统一响应：`{ "ok": true, "data": {...} }`。

---

## 📁 项目结构

```text
magent/
├── go.mod                    # Go module: github.com/Teddy-Zhu/magent
├── go.sum
├── agent/                    # Go Agent 后端运行时
│   ├── cmd/magent/main.go    # CLI 入口：serve / 服务管理 / version
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
│       ├── sync/             # Bootstrap / config 同步
│       └── ws/               # WebSocket Hub
├── magent_app/               # Flutter 客户端
│   ├── lib/app/              # 应用入口、路由、Shell、生命周期同步
│   ├── lib/core/             # API、模型、Provider、Repository、缓存与同步
│   ├── lib/features/         # agents / projects / sessions / git / settings
│   ├── lib/l10n/             # 中英文本地化
│   └── pubspec.yaml
├── docs/                     # 架构、阶段计划和完成记录
└── .github/workflows/        # Agent / Android / iOS Release 流水线
```

---

## 🧱 技术栈

**后端 (Agent)**

- Go 1.23
- [Gin](https://github.com/gin-gonic/gin) HTTP 框架
- [Gorilla WebSocket](https://github.com/gorilla/websocket)
- [Cobra](https://github.com/spf13/cobra) + [Viper](https://github.com/spf13/viper)
- SQLite ([modernc.org/sqlite](https://pkg.go.dev/modernc.org/sqlite))，WAL 模式，单写连接

**客户端 (App)**

- Flutter / Dart SDK `^3.11.5`
- [Riverpod](https://pub.dev/packages/flutter_riverpod) 状态管理
- [go_router](https://pub.dev/packages/go_router) 声明式路由
- [Dio](https://pub.dev/packages/dio) HTTP 客户端
- [web_socket_channel](https://pub.dev/packages/web_socket_channel)
- [Drift](https://pub.dev/packages/drift) + sqlite3_flutter_libs 本地缓存
- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) 安全存储

---

## 📋 环境要求

**基础环境**

- Go **1.23** 或更高版本
- Flutter SDK 和 Dart SDK
- Git

**可选 Provider CLI**（在 Agent 运行机器上安装并完成登录或 API Key 配置）

| Provider | 状态 | 说明 |
| --- | --- | --- |
| `codex` | ✅ 推荐 | 通过 app-server stdio 启动，结构化能力最完整 |
| `claude` | 🟡 占位 | PTY Provider，需要本机存在 `claude` 命令 |
| `aider` | 🟡 占位 | PTY Provider，需要本机存在 `aider` 命令 |

---

## 🚀 快速开始

### 1. 编译并启动 Go Agent

```bash
# 首次启动会自动生成配置和默认 Token
go run ./agent/cmd/magent serve
```

如果配置文件不存在，`serve` 会自动初始化配置并生成访问 Token。默认配置文件位于：

```text
~/.magent/default.yaml
```

默认服务地址是：

```text
http://127.0.0.1:9000
```

如果需要从手机连接同一局域网内的开发机器，请把配置中的 `server.host` 改为开发机器可访问的地址：

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

| 字段 | 说明 |
| --- | --- |
| **URL** | Agent 地址，例如 `http://192.168.1.100:9000` |
| **Token** | `~/.magent/default.yaml` 中 `auth.tokens[0].token` 的值 |
| **Name** | 自定义显示名称 |

连接成功后即可进入项目列表，添加项目路径并创建 AI 会话。

---

## 📦 Agent 编译与安装

### 通过 `go install` 安装

```bash
go install github.com/Teddy-Zhu/magent/agent/cmd/magent@latest
magent version
```

安装指定版本：

```bash
go install github.com/Teddy-Zhu/magent/agent/cmd/magent@v1.0.0
```

仓库使用根目录 Go module，module 路径为 `github.com/Teddy-Zhu/magent`。命令包位于 `agent/cmd/magent`，因此完整安装路径是 `github.com/Teddy-Zhu/magent/agent/cmd/magent`；安装后的二进制名由最后一级目录决定，为 `magent`。

> 💡 发布可安装版本时需要推送仓库根 semver tag，例如 `v1.0.0`：
>
> ```bash
> git tag v1.0.0
> git push origin v1.0.0
> ```
>
> Go 版本解析使用 `v1.0.0` 这类 semver tag。GitHub Release 工作流里用于区分产物的 `magent-agent-v1.0.0`、`magent-android-v1.0.0`、`magent-ios-v1.0.0` 不是 Go module 版本号。

`go install` 会把二进制安装到 `GOBIN`，未设置时默认是 `$(go env GOPATH)/bin`。请确保该目录在 `PATH` 中：

```bash
export PATH="$(go env GOPATH)/bin:${PATH}"
```

### 本机编译

```bash
go build -o magent ./agent/cmd/magent
./magent version
```

### 带版本信息编译

```bash
VERSION=v1.0.0
BUILD_TIME=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
GIT_COMMIT=$(git rev-parse --short=12 HEAD)

go build \
  -trimpath \
  -ldflags "-s -w -X main.version=${VERSION} -X main.buildTime=${BUILD_TIME} -X main.gitCommit=${GIT_COMMIT}" \
  -o magent \
  ./agent/cmd/magent

./magent version
```

### Linux 发布包编译示例

```bash
VERSION=v1.0.0
BUILD_TIME=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
GIT_COMMIT=$(git rev-parse --short=12 HEAD)

GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build \
  -trimpath \
  -ldflags "-s -w -X main.version=${VERSION} -X main.buildTime=${BUILD_TIME} -X main.gitCommit=${GIT_COMMIT}" \
  -o dist/magent \
  ./agent/cmd/magent

tar -C dist -czf "magent-${VERSION}-linux-amd64.tar.gz" magent
```

GitHub Actions 中的 Agent Release 目前会自动构建 Linux **amd64** 和 **arm64** 两个包，并通过独立工作流构建 Android、iOS 客户端。

---

## 💻 Agent 使用

### 启动 / 调试

```bash
# 启动；首次运行自动生成 ~/.magent/default.yaml
./magent serve

# 指定配置文件
./magent serve --config /path/to/default.yaml

# 覆盖监听地址、端口或 token
./magent serve --host 0.0.0.0 --port 9000 --token "<your-token>"

# 全局调试日志
./magent serve --log-level debug

# 按模块控制日志
./magent serve --log-levels codex=debug,gitwatcher=off

# 查看版本信息
./magent version
```

### 系统服务管理

```bash
# 安装为系统服务；首次安装会自动初始化配置
./magent install

# 安装时固定配置文件和监听参数
./magent install --config /path/to/default.yaml --host 0.0.0.0 --port 9000

# 管理服务
./magent start
./magent stop
./magent restart
./magent uninstall
```

### 自检

```bash
# 健康检查（无需鉴权）
curl http://127.0.0.1:9000/healthz

# 鉴权接口验证
TOKEN="<your-token>"
curl -H "Authorization: Bearer ${TOKEN}" http://127.0.0.1:9000/api/v1/agent/info
```

> 添加项目和创建会话建议通过 Flutter App 操作。Agent 运行机器上需要提前安装并登录对应 Provider CLI；目前推荐使用 `codex`，`claude` 和 `aider` 仍是 PTY 兼容占位能力。

---

## ⚙️ Agent 配置

Agent 使用 Viper 加载配置，并在配置文件不存在时自动生成。运行时配置按以下优先级生效：

1. 命令行参数：`--host`、`--port`、`--token`
2. `MAGENT_` 前缀环境变量
3. `--config` 指定的配置文件，或默认搜索到的配置文件
4. 代码内默认值

默认配置文件搜索顺序是 `~/.magent/default.yaml`、当前目录下的 `default.yaml`。两个文件都不存在时，会创建 `~/.magent/default.yaml`。

### 常用配置项

```yaml
log_level: "info"

server:
  host: "127.0.0.1"        # 监听地址；外网访问改为 0.0.0.0
  port: 9000
  read_timeout: 30s
  write_timeout: 30s
  rate_limit_per_min: 120  # 每分钟速率限制

auth:
  tokens:
    - name: "default"
      token: "<your-token>"
      permissions: ["*"]    # 权限标签，预留多角色

workspace:
  allowed_dirs: []          # 允许 Agent 访问的项目根目录白名单（空表示不限制）
  excluded_patterns:        # 文件浏览 / Git 状态忽略模式
    - ".git"
    - "node_modules"
    - ".venv"
    - "__pycache__"
```

### 通过命令行覆盖

```bash
go run ./agent/cmd/magent serve --host 0.0.0.0 --port 9000 --token "<your-token>"
go run ./agent/cmd/magent serve --log-level debug
go run ./agent/cmd/magent serve --log-levels codex=debug,gitwatcher=off
```

### 通过环境变量覆盖

环境变量使用 `MAGENT_` 前缀，嵌套字段以 `_` 连接，例如：

```bash
MAGENT_HOST=0.0.0.0 MAGENT_PORT=9000 MAGENT_TOKEN="<your-token>" ./magent serve
MAGENT_SERVER_HOST=0.0.0.0 MAGENT_SERVER_PORT=9000 ./magent serve
```

---

## 📡 API 概览

健康检查不需要鉴权：

```text
GET /healthz
```

业务接口使用 `/api/v1` 前缀，并通过 `Authorization: Bearer <token>` 鉴权：

### Agent / Bootstrap

```text
GET  /api/v1/agent/info          # Agent 版本、Provider 列表、能力声明
GET  /api/v1/bootstrap            # 客户端初次同步用配置（带 hash）
GET  /api/v1/providers            # Provider 列表与能力
```

### 项目

```text
GET    /api/v1/projects
POST   /api/v1/projects
GET    /api/v1/projects/:id
PATCH  /api/v1/projects/:id
DELETE /api/v1/projects/:id
```

### 会话

```text
POST /api/v1/sessions                       # 创建会话
GET  /api/v1/sessions/:id                   # 会话详情
GET  /api/v1/sessions/:id/events            # 历史事件回放
POST /api/v1/sessions/:id/input             # 发送输入
POST /api/v1/sessions/:id/interrupt         # 中断当前 turn
POST /api/v1/sessions/:id/stop              # 停止会话
POST /api/v1/sessions/:id/resume            # 恢复会话
POST /api/v1/sessions/:id/fork              # 分叉会话
```

### Git

```text
GET  /api/v1/projects/:id/git/summary       # 当前分支、HEAD、ahead/behind
GET  /api/v1/projects/:id/git/changes       # 变更文件列表
GET  /api/v1/projects/:id/git/diff          # 文件级 diff
POST /api/v1/projects/:id/git/stage
POST /api/v1/projects/:id/git/unstage
POST /api/v1/projects/:id/git/discard
POST /api/v1/projects/:id/git/commit
POST /api/v1/projects/:id/git/pull
POST /api/v1/projects/:id/git/push
GET  /api/v1/projects/:id/git/log
GET  /api/v1/projects/:id/git/branches
GET  /api/v1/projects/:id/git/commit-diff
```

### 文件

```text
GET /api/v1/projects/:id/files/dir          # 目录列表
GET /api/v1/projects/:id/files/text         # 文本内容读取
GET /api/v1/projects/:id/files/blob         # 原始 blob
```

### WebSocket

```text
GET /api/v1/ws                              # 实时事件 / 审批 / 失效通知
```

### 统一响应格式

```json
{
  "ok": true,
  "data": {}
}
```

错误响应：

```json
{
  "ok": false,
  "error": {
    "code": "INVALID_TOKEN",
    "message": "token is invalid or expired"
  }
}
```

---

## 🛠️ 开发指南

### 后端

```bash
go build ./agent/...                                # 编译
go test ./agent/...                                 # 测试
go run ./agent/cmd/magent serve                     # 本地运行
```

### 客户端

```bash
cd magent_app
flutter pub get
flutter analyze                                     # 静态分析
flutter test
dart format lib test                                # 格式化
dart run build_runner build                         # freezed / drift 代码生成
```

> 生成代码变更后需要提交对应的 `.g.dart`、`.freezed.dart` 等文件。

### 工程规范

- **统一响应**：使用 `response.go` 的 `OK / Fail / NotModified`，禁止裸 `c.JSON()`。
- **健康检查**：`GET /healthz` 无需鉴权。
- **结构化日志**：zap + request_id。
- **配置**：Viper 环境变量覆盖（前缀 `MAGENT_`）。
- **Flutter 模型**：使用 freezed + json_serializable 代码生成。
- **WebSocket**：每 token 最多 5 连接，30s ping / 60s pong 超时断开。
- **Git 命令**：所有 git 命令必须通过 `gitservice.Service.Git()` 执行，已内置 `-c core.quotepath=false`（中文路径）和 `-c log.showSignature=false`（跳过 GPG）。

---

## 🗺️ 路线图

| 阶段 | 状态 | 说明 |
| --- | --- | --- |
| Phase 1 — 基础框架 | ✅ 已完成 | HTTP / WS、SQLite、Project CRUD、鉴权 |
| Phase 2 — Codex + Session | ✅ 已完成 | Provider、JSON-RPC、审批代理、会话生命周期 |
| Phase 3 — Git 同步 | ✅ 已完成 | Summary / Changes / Diff + Watcher |
| Phase 4 — 文件浏览 | ✅ 已完成 | 目录列表 + 文件读取 + 缓存 |
| Phase 5 — 操作 + 产品化 | ✅ 已完成 | Git 操作 + Session 高级功能 + 中间件 + 设置页 |
| Phase 6 — Provider 扩展 | ✅ 已完成 | PTY Runner + Claude / Aider Provider + 动态 UI |
| Phase 7 — 高级功能 | 🚧 规划中 | 见 [`docs/plan/phase7-advanced.md`](docs/plan/phase7-advanced.md) |

完整阶段记录见 [`docs/completed/`](docs/completed/) 与 [`docs/plan/`](docs/plan/)。

---

## ❓ 常见问题

<details>
<summary><strong>Q: 为什么手机端不直接跑 AI CLI？</strong></summary>

AI CLI 通常需要较强 CPU、长连接、大量本地工具调用，并且要持有 API Key、SSH Key、Git 凭证等敏感信息。把它留在开发机上能：节省手机算力 / 流量；避免凭证拷贝；保留完整的本地工具链；支持长时间运行任务而不被手机系统杀进程。

</details>

<details>
<summary><strong>Q: 中文文件名在 Git 接口里显示成 <code>\277\253</code> 怎么办？</strong></summary>

Magent 已经在 `gitservice.Service.Git()` 里强制加了 `-c core.quotepath=false`。如果你新增 git 命令绕开了这个封装，需要手动带上该参数，否则会被 git 转义成八进制。

</details>

<details>
<summary><strong>Q: 一个 Token 能开几个 WebSocket？</strong></summary>

每个 Token 最多 5 个 WebSocket 连接，30s ping / 60s pong 超时即断开。多设备同时使用时建议为每台设备生成独立 Token。

</details>

<details>
<summary><strong>Q: 断线后会话还能恢复吗？</strong></summary>

可以。Agent 把会话事件持久化到 SQLite，客户端重连后会回放最多 1000 条历史事件；超过则提示全量刷新。

</details>

<details>
<summary><strong>Q: 现在能用哪些 Provider？</strong></summary>

目前仅 `codex` 是完整能力（通过 app-server stdio 协议，支持线程、审批、fork、compact、rollback）。`claude` 和 `aider` 已经接入 PTY Runner，可以跑起来但只是兼容性占位，能力有限。

</details>

<details>
<summary><strong>Q: 我能放公网吗？</strong></summary>

不建议把 Agent 直接暴露到公网。默认监听 `127.0.0.1`，改成 `0.0.0.0` 后请确保只在可信网络中使用，并配合防火墙、反向代理或 Tailscale / WireGuard 等组网工具。

</details>

---

## 🔒 安全注意事项

- ❌ 不要提交 Token、数据库文件、secure-storage 内容或机器特定配置。
- ✅ `.gitignore` 已忽略 `*.db` 和 `*.db-journal`。
- 🙈 日志、截图和测试输出中应隐藏 `Authorization: Bearer <token>`。
- 🛡️ 默认监听 `127.0.0.1`；如果改为 `0.0.0.0`，请只在可信网络中使用，并配置防火墙或反向代理访问控制。
- 🗝️ 建议为每台客户端设备分配独立 Token，便于单独吊销。

---

## 🤝 贡献

欢迎以下形式的贡献：

- 🐛 [提交 Bug](https://github.com/Teddy-Zhu/magent/issues/new) — 请附复现步骤、Agent / App 版本、相关日志
- 💡 [功能建议](https://github.com/Teddy-Zhu/magent/issues/new) — 描述使用场景，越具体越好
- 🔧 提交 Pull Request — fork 仓库 → 创建分支 → 修改并通过 `go test ./agent/...` 与 `flutter analyze` → 提交 PR
- 📝 改进文档 — 即使是错别字也很有价值

提交前请确保：

1. Go 代码通过 `go build ./agent/...` 与 `go vet ./agent/...`。
2. Flutter 代码通过 `flutter analyze`，并已运行 `dart format lib test`。
3. 涉及代码生成的改动同时提交 `.g.dart` / `.freezed.dart`。
4. PR 描述清晰说明改动动机与影响范围。

---

## 📚 文档

- 📐 [项目结构说明](docs/project-structure.md)
- 🗂️ [总体计划](docs/plan.md)
- 📡 [通信协议计划](docs/plan/communication.md)
- 🤖 [Codex App Server 集成计划](docs/plan/codex-appserver.md)
- ✅ [阶段完成记录](docs/completed)

---

## 📄 许可证

本项目当前仓库许可证为 MIT [LICENSE](LICENSE)

---

## 🙏 致谢

Magent 站在以下优秀项目的肩膀上：

- [Codex](https://github.com/openai/codex) — 提供 app-server stdio 协议
- [Claude Code](https://www.anthropic.com/) / [Aider](https://github.com/Aider-AI/aider) — PTY Provider 兼容目标
- [Gin](https://github.com/gin-gonic/gin)、[Cobra](https://github.com/spf13/cobra)、[Viper](https://github.com/spf13/viper)、[Gorilla WebSocket](https://github.com/gorilla/websocket)、[modernc.org/sqlite](https://pkg.go.dev/modernc.org/sqlite)
- [Flutter](https://flutter.dev)、[Riverpod](https://riverpod.dev)、[go_router](https://pub.dev/packages/go_router)、[Dio](https://pub.dev/packages/dio)、[Drift](https://drift.simonbinder.eu/)

---

## 📍 当前状态

当前代码已经包含 Go Agent、Flutter 客户端、Codex / Claude / Aider Provider、会话、Git、文件、配置同步和本地缓存等核心模块。更长线的高级能力和阶段规划见 [`docs/plan/`](docs/plan/)。

如果觉得这个项目对你有帮助，欢迎点一颗 ⭐ Star 支持！
