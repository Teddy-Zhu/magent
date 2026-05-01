# Phase 3 完成对账

## 状态：已完成

## 已完成内容

### Go Agent Git Service（`agent/internal/gitservice/`）

- [x] `service.go` - Git Service 主服务
  - git 命令封装
  - Watcher 管理

- [x] `summary.go` - Summary 计算
  - HEAD / Branch / Upstream
  - Ahead / Behind
  - WorktreeHash / IndexHash
  - Status counts（staged / unstaged / untracked）
  - Version 管理（变化时 +1）

- [x] `changes.go` - Changes 计算
  - numstat 解析
  - untracked 文件列表
  - DiffHash 计算

- [x] `diff.go` - Diff 计算 + 分页
  - Diff 输出解析
  - 分页支持（offset/limit）
  - Diff 缓存

- [x] `watcher.go` - Git Watcher
  - fsnotify 监听 .git 目录
  - 500ms debounce

### HTTP API（`agent/internal/api/`）

- [x] `git_handler.go` - Git API
  - GET /api/git/summary?project_id=xxx
  - GET /api/git/changes?project_id=xxx&base_version=0
  - GET /api/git/diff/file?project_id=xxx&path=xxx&diff_hash=xxx&offset=0&limit=200

### Flutter App（`magent_app/`）

- [x] `core/api/git_api.dart` - Git API 客户端
  - getSummary / getChanges / getFileDiff
  - stage / unstage / discard / commit

- [x] `features/git/status/git_status_page.dart` - Git 状态页面
  - Summary 卡片（分支、ahead/behind）
  - 文件变化列表
  - Stage/Unstage 操作

- [x] `features/git/diff/diff_view_page.dart` - Diff 查看页面
  - Diff 行渲染（add/del/context）
  - 行号显示
  - 分页加载

## 编译状态

- Go Agent：通过
- Flutter App：通过

## 验收标准

1. GET /api/git/summary 返回正确状态，version 正确递增
2. GET /api/git/changes 只在 version 变化时返回新数据
3. GET /api/git/diff/file 支持分页（offset/limit）
4. Git Watcher 在文件变化后 500ms 内触发更新
5. 打开项目的总流量 < 1KB（version 未变化时接近 0）
