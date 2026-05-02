# 仓库指南

## 项目结构与模块组织

本仓库包含两个主要子项目。`agent/` 是 Go 后端运行时，包含 `cmd/magent/main.go`、`internal/api`、`internal/session`、`internal/gitservice`、`internal/providers` 以及 SQLite 存储。Go module 位于仓库根目录，module 路径为 `github.com/Teddy-Zhu/magent`。`magent_app/` 是 Flutter 客户端，应用初始化代码位于 `lib/app`，可复用的 API/存储代码位于 `lib/core`，功能页面位于 `lib/features`，共享组件位于 `lib/shared`，本地化文件位于 `lib/l10n`。规划和架构说明位于 `docs/`。

## 构建、测试与开发命令

- `go build ./agent/...`：编译 Go agent。
- `go run ./agent/cmd/magent serve`：在本地运行后端服务。
- `go run ./agent/cmd/magent init`：初始化本地配置和 token 数据。
- `go test ./agent/...`：运行 Go 包测试。
- `cd magent_app && flutter pub get`：安装 Flutter 依赖。
- `cd magent_app && flutter run`：运行移动端/桌面端应用。
- `cd magent_app && flutter analyze`：使用项目 lint 规则运行 Dart 静态分析。
- `cd magent_app && flutter test`：运行 Flutter 测试。
- `cd magent_app && dart run build_runner build`：重新生成 Drift/序列化输出。

## 编码风格与命名约定

Go 代码使用 `gofmt` 格式化；包名保持简短且小写。后端代码应放在匹配的 `agent/internal/<domain>` 包下，并使用 `internal/api/response.go` 中的共享 API 响应辅助函数。后端新增 Git 命令时，应通过 `gitservice.Service.Git()` 执行，以确保应用必要的 Git 配置。

Dart 代码遵循 `magent_app/analysis_options.yaml` 中的 `flutter_lints`，并在提交前运行 `dart format`。文件名使用 `snake_case.dart`，组件/类使用 `PascalCase`，Riverpod provider 放在 `lib/core/providers` 或所属功能模块中。

## 测试指南

Go 测试应以 `*_test.go` 命名并放在对应包旁边。Flutter 测试应放在 `magent_app/test` 中，并使用 `_test.dart` 文件名。请为 API handler、session/provider 行为、数据解析以及用户可见的 Flutter 工作流添加聚焦测试。目前没有文档化的覆盖率阈值。

## 提交与拉取请求指南

近期历史使用 `feat:`、`docs:` 等约定式前缀；提交标题应使用祈使语气并限定范围，例如 `feat: add provider settings page`。拉取请求应描述变更内容，列出已运行的验证命令，链接相关 issue 或文档，并在涉及 UI 变更时附上截图。生成代码更新和迁移需要特别说明。

## 安全与配置提示

不要提交本地 token、数据库文件或机器特定配置。后端配置基于 Viper，并支持 `MAGENT_` 环境变量前缀。日志、测试和截图中都应将 `Authorization: Bearer <token>` 值以及 secure-storage 内容视为敏感信息。
