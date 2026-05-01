# Phase 5 完成对账

## 状态：已完成

## 已完成内容

### Go Agent Git 操作（`agent/internal/gitservice/`）

- [x] `service.go` - `git()` 改为导出 `Git()`
- [x] `summary.go` - Git Summary（版本管理、worktree/index hash）
- [x] `changes.go` - 文件变化检测（numstat 解析）
- [x] `diff.go` - Diff 计算 + 分页 + 缓存
- [x] `watcher.go` - fsnotify 文件监视（500ms debounce）

### Go Agent Session 高级功能

- [x] `session/manager.go` - 新增 `CompactSession` / `RollbackSession`
- [x] `api/session_handler.go` - 新增 `Compact` / `Rollback` 处理方法

### Go Agent 安全中间件（`agent/internal/api/middleware/`）

- [x] `audit.go` - 审计日志中间件
  - 记录所有 API 请求（方法、路径、状态码、耗时）
  - 使用已有 `audit_log` 表

- [x] `ratelimit.go` - 令牌桶限流中间件
  - 按 IP 限流，支持配置 `rate_limit_per_min`
  - 超限返回 429 + `RATE_LIMITED` 错误码

- [x] `compress.go` - gzip 压缩中间件
  - 自动协商 Accept-Encoding
  - sync.Pool 复用 gzip.Writer

### Go Agent 配置扩展

- [x] `config/config.go` - 新增 `RateLimitPerMin` 字段（默认 120/min）

### Go Agent HTTP API（`agent/internal/api/`）

- [x] `git_handler.go` - 完整 Git 操作 API
  - POST /api/git/stage
  - POST /api/git/unstage
  - POST /api/git/discard
  - POST /api/git/commit
  - POST /api/git/push（force push 需确认）
  - GET /api/git/log
  - GET /api/git/branches

- [x] `router.go` - 新增路由
  - POST /api/sessions/:id/compact
  - POST /api/sessions/:id/rollback

### Flutter App Git API（`magent_app/lib/core/api/`）

- [x] `git_api.dart` - 新增方法
  - `push()` - 推送到远程
  - `getLog()` - 获取提交历史
  - `getBranches()` - 获取分支列表

### Flutter App 设置页面（`magent_app/lib/features/settings/`）

- [x] `settings_page.dart` - 设置主页面
  - Agent 管理入口
  - Git 操作入口
  - 缓存管理入口
  - 版本信息

- [x] `cache_settings_page.dart` - 缓存管理页面
  - Git diff / 文件 / 事件缓存大小显示
  - 分类清理 + 全部清理

### Flutter App Git 操作页面（`magent_app/lib/features/git/operations/`）

- [x] `git_commit_push_page.dart` - 提交与推送
  - 提交信息输入
  - Stage all 选项
  - Push / Force Push（带确认弹窗）

- [x] `git_log_page.dart` - 提交历史
  - 分页加载（50 条/页）
  - 显示 hash、作者、时间、消息

- [x] `git_branches_page.dart` - 分支列表
  - 显示当前分支标记
  - 远程/本地分支

### Flutter App 路由更新

- [x] `app/router.dart` - 新增路由
  - /settings
  - /settings/cache
  - /git/operations
  - /git/log
  - /git/branches

### Flutter App Provider

- [x] `core/providers/api_provider.dart` - API 客户端工厂
  - `AppApiClient` 封装 GitApi / SessionApi / FileApi
  - `secureStorageProvider` 提供 AgentStorage
  - `createApiClient()` 工厂方法

## 编译状态

- Go Agent：通过
- Flutter App：通过（analyze 零错误）

## 验收标准

| # | 标准 | 状态 |
|---|---|---|
| 1 | Git stage/unstage/commit 操作正确 | ✅ |
| 2 | Git push 需确认，force push 需额外确认 | ✅ |
| 3 | Git discard 需确认 | ✅ |
| 4 | Session fork 创建新会话 | ✅（Phase 2） |
| 5 | Session compact 压缩历史 | ✅ |
| 6 | Session rollback 回退到指定 turn | ✅ |
| 7 | 审计日志记录所有敏感操作 | ✅ |
| 8 | 限流生效（429 响应） | ✅ |
| 9 | gzip 压缩生效 | ✅ |
| 10 | 设置页面可导航 | ✅ |
| 11 | 缓存管理可清理 | ✅ |
