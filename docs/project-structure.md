# 项目结构说明

## 目录布局

```
magent/
├── go.mod                    # Go module: github.com/Teddy-Zhu/magent
├── go.sum
├── agent/                    # Go Agent 后端
│   ├── cmd/magent/main.go     # 入口
│   ├── internal/
│   │   ├── api/              # HTTP API + WebSocket
│   │   │   ├── server.go     # 服务器
│   │   │   ├── router.go     # 路由
│   │   │   ├── response.go   # 响应工具
│   │   │   ├── middleware/   # 中间件（auth/cors/audit/ratelimit/compress）
│   │   │   ├── session_handler.go
│   │   │   ├── git_handler.go
│   │   │   ├── file_handler.go
│   │   │   └── sync_handler.go
│   │   ├── codex/            # Codex Provider
│   │   ├── providers/        # Claude/Aider Provider (PTY 模式)
│   │   ├── runner/           # PTY 进程运行器
│   │   ├── config/           # 配置系统
│   │   ├── fileservice/      # 文件服务
│   │   ├── gitservice/       # Git 服务
│   │   ├── project/          # 项目管理
│   │   ├── protocol/         # JSON-RPC 2.0
│   │   ├── provider/         # Provider 接口
│   │   ├── session/          # Session 管理
│   │   ├── storage/          # SQLite 存储
│   │   ├── sync/             # 配置同步
│   │   └── ws/               # WebSocket Hub
│   └── configs/default.yaml
│
├── magent_app/               # Flutter App
│   ├── lib/
│   │   ├── app/              # 应用入口、路由、主题
│   │   ├── core/
│   │   │   ├── api/          # API 客户端
│   │   │   │   ├── api_client.dart
│   │   │   │   ├── ws_client.dart
│   │   │   │   ├── session_api.dart
│   │   │   │   ├── git_api.dart
│   │   │   │   └── file_api.dart
│   │   │   ├── models/       # 数据模型
│   │   │   ├── providers/    # Riverpod Provider
│   │   │   ├── storage/      # 安全存储
│   │   │   └── sync/         # 配置同步
│   │   ├── features/
│   │   │   ├── agents/       # Agent 管理
│   │   │   ├── projects/     # 项目管理
│   │   │   ├── sessions/     # 会话管理
│   │   │   ├── git/          # Git 操作（status/diff/operations）
│   │   │   ├── files/        # 文件浏览
│   │   │   └── settings/     # 设置页面
│   │   └── shared/           # 共享组件
│   └── pubspec.yaml
│
└── docs/                     # 文档
    ├── plan.md               # 总体计划
    ├── plan/                 # 各阶段详细计划
    ├── completed/            # 完成对账
    └── project-structure.md  # 项目结构说明
```

## 子项目说明

| 子项目 | 目录 | 技术栈 | 说明 |
|--------|------|--------|------|
| Go Agent | `agent/` | Go + Gin + SQLite | 后端服务，负责 AI 运行时管理 |
| Flutter App | `magent_app/` | Flutter + Dart | 手机端 App，远程控制台 |

## 开发命令

### Go Agent

```bash
# 编译
go build ./agent/...

# 运行
go run ./agent/cmd/magent serve

# 安装为系统服务
go run ./agent/cmd/magent install
```

### Flutter App

```bash
# 安装依赖
cd magent_app && flutter pub get

# 运行
cd magent_app && flutter run

# 代码分析
cd magent_app && flutter analyze
```

## 已完成阶段

| 阶段 | 状态 | 说明 |
|------|------|------|
| Phase 1 | 已完成 | 基础框架（HTTP/WS/SQLite/Auth） |
| Phase 2 | 已完成 | Codex Provider + Session 系统 |
| Phase 3 | 已完成 | Git 低流量系统 |
| Phase 4 | 已完成 | 文件低流量系统 |
| Phase 5 | 已完成 | 操作能力 + 产品化 |
| Phase 6 | 已完成 | Provider 扩展 (Claude/Aider) |
| Phase 7 | 待开始 | 高级功能 |
