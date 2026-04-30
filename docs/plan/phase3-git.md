# Phase 3：Git 低流量系统（2 周）

## 目标

实现四层 Git 同步模型，让手机端以最小流量查看 Git 状态和 Diff。

## 前置条件

Phase 1 完成（HTTP Server、SQLite、Project）。

## 产出

- Git Summary API（最轻量状态查询）
- Git Changes API（文件级变化列表）
- Diff 按需加载 + 分页
- Git Watcher + debounce
- Flutter Git 页面 + 本地缓存

---

## 一、四层同步模型

```
请求层        流量         触发时机
─────────────────────────────────────────
Summary      ~200 B       每次打开项目 / WS 推送
Changes      ~50 B/文件    version 变化时
Diff Content  按文件大小    用户点开文件时
Diff 分页     200 行/次     用户滚动时
```

**核心逻辑**：version 不变 = 不请求任何后续数据。

---

## 二、Go Agent：Git Service

### 2.1 目录结构

```
internal/gitservice/
├── service.go       # 主服务（封装 git 命令调用）
├── summary.go       # Summary 计算
├── changes.go       # Changes 计算
├── diff.go          # Diff 计算 + 分页
├── hash.go          # Hash 计算（diff hash, worktree hash, index hash）
└── watcher.go       # fsnotify 监听 + debounce
```

### 2.2 Git Service

```go
// internal/gitservice/service.go

type Service struct {
    db       *storage.SQLite
    watchers map[string]*GitWatcher // projectID → watcher
    mu       sync.RWMutex
}

// 调用系统 git 命令（不用 go-git，行为更一致）
func (s *Service) git(ctx context.Context, dir string, args ...string) ([]byte, error) {
    cmd := exec.CommandContext(ctx, "git", args...)
    cmd.Dir = dir
    return cmd.CombinedOutput()
}
```

### 2.3 Summary 计算

```go
// internal/gitservice/summary.go

type GitSummary struct {
    ProjectID      string `json:"project_id"`
    Head           string `json:"head"`
    Branch         string `json:"branch"`
    Upstream       string `json:"upstream"`
    Ahead          int    `json:"ahead"`
    Behind         int    `json:"behind"`
    WorktreeHash   string `json:"worktree_hash"`
    IndexHash      string `json:"index_hash"`
    ChangedCount   int    `json:"changed_count"`
    StagedCount    int    `json:"staged_count"`
    UnstagedCount  int    `json:"unstaged_count"`
    UntrackedCount int    `json:"untracked_count"`
    Version        int64  `json:"version"`
}

func (s *Service) GetSummary(ctx context.Context, projectID, projectPath string) (*GitSummary, error) {
    // 1. HEAD
    head, _ := s.git(ctx, projectPath, "rev-parse", "HEAD")
    head = strings.TrimSpace(string(head))

    // 2. Branch
    branch, _ := s.git(ctx, projectPath, "rev-parse", "--abbrev-ref", "HEAD")
    branch = strings.TrimSpace(string(branch))

    // 3. Upstream
    upstream, _ := s.git(ctx, projectPath, "rev-parse", "--abbrev-ref", "@{upstream}")
    upstream = strings.TrimSpace(string(upstream))

    // 4. Ahead/Behind
    ahead, behind := 0, 0
    if upstream != "" {
        revList, _ := s.git(ctx, projectPath, "rev-list", "--left-right", "--count", "HEAD...@{upstream}")
        fmt.Sscanf(strings.TrimSpace(string(revList)), "%d\t%d", &ahead, &behind)
    }

    // 5. Status counts
    statusOut, _ := s.git(ctx, projectPath, "status", "--porcelain=v1")
    staged, unstaged, untracked := parseStatusCounts(string(statusOut))

    // 6. Worktree hash（所有 tracked 文件内容 hash 的 hash）
    worktreeHash := s.computeWorktreeHash(ctx, projectPath)

    // 7. Index hash
    indexHash := s.computeIndexHash(ctx, projectPath)

    // 8. Version（从 DB 获取，有变化时 +1）
    version := s.getOrBumpVersion(ctx, projectID, head, worktreeHash, indexHash)

    return &GitSummary{
        ProjectID:      projectID,
        Head:           head,
        Branch:         branch,
        Upstream:       upstream,
        Ahead:          ahead,
        Behind:         behind,
        WorktreeHash:   worktreeHash,
        IndexHash:      indexHash,
        ChangedCount:   staged + unstaged + untracked,
        StagedCount:    staged,
        UnstagedCount:  unstaged,
        UntrackedCount: untracked,
        Version:        version,
    }, nil
}

func parseStatusCounts(status string) (staged, unstaged, untracked int) {
    for _, line := range strings.Split(status, "\n") {
        if len(line) < 2 {
            continue
        }
        x, y := line[0], line[1]
        if x == '?' && y == '?' {
            untracked++
        } else {
            if x != ' ' && x != '?' {
                staged++
            }
            if y != ' ' && y != '?' {
                unstaged++
            }
        }
    }
    return
}

func (s *Service) getOrBumpVersion(ctx context.Context, projectID, head, worktreeHash, indexHash string) int64 {
    // 从 DB 读取当前状态
    current, _ := s.getGitState(ctx, projectID)
    if current != nil && current.Head == head && current.WorktreeHash == worktreeHash && current.IndexHash == indexHash {
        return current.Version
    }
    // 有变化，version + 1
    newVersion := int64(1)
    if current != nil {
        newVersion = current.Version + 1
    }
    s.saveGitState(ctx, projectID, newVersion, head, worktreeHash, indexHash)
    return newVersion
}
```

### 2.4 Changes 计算

```go
// internal/gitservice/changes.go

type FileChange struct {
    Path       string `json:"path"`
    Status     string `json:"status"`     // "modified" | "added" | "deleted" | "renamed"
    Staged     bool   `json:"staged"`
    Additions  int    `json:"additions"`
    Deletions  int    `json:"deletions"`
    Binary     bool   `json:"binary"`
    OldHash    string `json:"old_hash"`
    NewHash    string `json:"new_hash"`
    DiffHash   string `json:"diff_hash"`
    Size       int64  `json:"size"`
}

type ChangesResult struct {
    Version int64        `json:"version"`
    Files   []FileChange `json:"files"`
    Removed []string     `json:"removed"` // 相比 base_version 删除的文件
}

func (s *Service) GetChanges(ctx context.Context, projectID, projectPath string, baseVersion int64) (*ChangesResult, error) {
    // 如果 baseVersion 和当前 version 一致，返回空
    currentState, _ := s.getGitState(ctx, projectID)
    if currentState != nil && currentState.Version == baseVersion {
        return &ChangesResult{Version: baseVersion}, nil
    }

    // 获取 staged 变化
    stagedOut, _ := s.git(ctx, projectPath, "diff", "--cached", "--numstat")
    // 获取 unstaged 变化
    unstagedOut, _ := s.git(ctx, projectPath, "diff", "--numstat")
    // 获取 untracked 文件
    untrackedOut, _ := s.git(ctx, projectPath, "ls-files", "--others", "--exclude-standard")

    var files []FileChange

    // 解析 staged
    for _, line := range parseNumstat(string(stagedOut)) {
        f := line.toFileChange(true)
        f.DiffHash = ComputeDiffHash(f.Path, f.OldHash, f.NewHash, "staged")
        files = append(files, f)
    }

    // 解析 unstaged
    for _, line := range parseNumstat(string(unstagedOut)) {
        f := line.toFileChange(false)
        f.DiffHash = ComputeDiffHash(f.Path, f.OldHash, f.NewHash, "unstaged")
        files = append(files, f)
    }

    // 解析 untracked
    for _, path := range strings.Split(strings.TrimSpace(string(untrackedOut)), "\n") {
        if path != "" {
            files = append(files, FileChange{
                Path:   path,
                Status: "untracked",
            })
        }
    }

    return &ChangesResult{
        Version: currentState.Version,
        Files:   files,
    }, nil
}
```

### 2.5 Diff 计算 + 分页

```go
// internal/gitservice/diff.go

type DiffResult struct {
    Path       string     `json:"path"`
    DiffHash   string     `json:"diff_hash"`
    Encoding   string     `json:"encoding"`
    Binary     bool       `json:"binary"`
    Offset     int        `json:"offset"`
    Limit      int        `json:"limit"`
    TotalLines int        `json:"total_lines"`
    Lines      []DiffLine `json:"lines"`
}

type DiffLine struct {
    Type     string `json:"type"` // "add" | "del" | "context"
    Content  string `json:"content"`
    OldLine  int    `json:"old_line,omitempty"`
    NewLine  int    `json:"new_line,omitempty"`
}

func (s *Service) GetFileDiff(ctx context.Context, projectPath, filePath, diffHash string, offset, limit int) (*DiffResult, error) {
    // 先查缓存
    cached := s.getDiffCache(ctx, filePath, diffHash)
    if cached != nil {
        return s.paginateDiff(cached, offset, limit), nil
    }

    // 计算 diff
    out, _ := s.git(ctx, projectPath, "diff", "--", filePath)
    lines := parseDiffOutput(string(out))

    // 缓存完整 diff
    s.saveDiffCache(ctx, filePath, diffHash, lines)

    return s.paginateDiff(lines, offset, limit), nil
}

func (s *Service) paginateDiff(lines []DiffLine, offset, limit int) *DiffResult {
    total := len(lines)
    if offset >= total {
        return &DiffResult{Lines: []DiffLine{}}
    }
    end := offset + limit
    if end > total {
        end = total
    }
    return &DiffResult{
        Offset:     offset,
        Limit:      limit,
        TotalLines: total,
        Lines:      lines[offset:end],
    }
}

func parseDiffOutput(diff string) []DiffLine {
    var lines []DiffLine
    oldLine, newLine := 0, 0
    for _, raw := range strings.Split(diff, "\n") {
        if strings.HasPrefix(raw, "@@") {
            // 解析 @@ -a,b +c,d @@
            fmt.Sscanf(raw, "@@ -%d,%d +%d,%d", &oldLine, _, &newLine, _)
            continue
        }
        if strings.HasPrefix(raw, "+") {
            lines = append(lines, DiffLine{Type: "add", Content: raw[1:], NewLine: newLine})
            newLine++
        } else if strings.HasPrefix(raw, "-") {
            lines = append(lines, DiffLine{Type: "del", Content: raw[1:], OldLine: oldLine})
            oldLine++
        } else if strings.HasPrefix(raw, " ") {
            lines = append(lines, DiffLine{Type: "context", Content: raw[1:], OldLine: oldLine, NewLine: newLine})
            oldLine++
            newLine++
        }
    }
    return lines
}
```

### 2.6 Diff Hash 计算

```go
// internal/gitservice/hash.go

func ComputeDiffHash(path, oldHash, newHash, mode string) string {
    h := sha256.New()
    h.Write([]byte(path))
    h.Write([]byte(oldHash))
    h.Write([]byte(newHash))
    h.Write([]byte(mode))
    return "diff_" + hex.EncodeToString(h.Sum(nil))[:16]
}

func (s *Service) computeWorktreeHash(ctx context.Context, projectPath string) string {
    // git ls-files -s | sha256
    out, _ := s.git(ctx, projectPath, "ls-files", "-s")
    h := sha256.Sum256(out)
    return "wt_" + hex.EncodeToString(h[:])[:16]
}

func (s *Service) computeIndexHash(ctx context.Context, projectPath string) string {
    // .git/index 文件 hash
    indexBytes, _ := os.ReadFile(filepath.Join(projectPath, ".git", "index"))
    h := sha256.Sum256(indexBytes)
    return "idx_" + hex.EncodeToString(h[:])[:16]
}
```

### 2.7 Git Watcher

```go
// internal/gitservice/watcher.go

type GitWatcher struct {
    projectID   string
    projectPath string
    service     *Service
    fsWatcher   *fsnotify.Watcher
    debounce    time.Duration
    timers      map[string]*time.Timer
    mu          sync.Mutex
    onChange    func(summary *GitSummary)
}

func NewGitWatcher(projectID, projectPath string, service *Service, onChange func(*GitSummary)) (*GitWatcher, error) {
    fsWatcher, err := fsnotify.NewWatcher()
    if err != nil {
        return nil, err
    }

    // 监听 .git 目录关键文件
    fsWatcher.Add(filepath.Join(projectPath, ".git", "index"))
    fsWatcher.Add(filepath.Join(projectPath, ".git", "HEAD"))
    fsWatcher.Add(filepath.Join(projectPath, ".git", "refs"))

    // 可选：监听工作目录文件变化
    // fsWatcher.Add(projectPath)

    w := &GitWatcher{
        projectID:   projectID,
        projectPath: projectPath,
        service:     service,
        fsWatcher:   fsWatcher,
        debounce:    500 * time.Millisecond,
        timers:      make(map[string]*time.Timer),
        onChange:    onChange,
    }

    go w.loop()
    return w, nil
}

func (w *GitWatcher) loop() {
    for {
        select {
        case event := <-w.fsWatcher.Events:
            w.mu.Lock()
            if timer, ok := w.timers[event.Name]; ok {
                timer.Stop()
            }
            w.timers[event.Name] = time.AfterFunc(w.debounce, func() {
                w.refresh()
            })
            w.mu.Unlock()
        case err := <-w.fsWatcher.Errors:
            log.Printf("git watcher error: %v", err)
        }
    }
}

func (w *GitWatcher) refresh() {
    ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
    defer cancel()

    summary, err := w.service.GetSummary(ctx, w.projectID, w.projectPath)
    if err != nil {
        return
    }

    if w.onChange != nil {
        w.onChange(summary)
    }
}

func (w *GitWatcher) Close() {
    w.fsWatcher.Close()
}
```

### 2.8 HTTP API

```go
// internal/api/handlers/git.go

// GET /api/git/summary?project_id=p1
func (h *GitHandler) Summary(c *gin.Context) {
    projectID := c.Query("project_id")
    project, _ := h.projectMgr.Get(c, projectID)
    summary, _ := h.gitService.GetSummary(c, projectID, project.Path)
    c.JSON(200, summary)
}

// GET /api/git/changes?project_id=p1&base_version=41
func (h *GitHandler) Changes(c *gin.Context) {
    projectID := c.Query("project_id")
    baseVersion, _ := strconv.ParseInt(c.Query("base_version"), 10, 64)
    project, _ := h.projectMgr.Get(c, projectID)
    changes, _ := h.gitService.GetChanges(c, projectID, project.Path, baseVersion)
    c.JSON(200, changes)
}

// GET /api/git/diff/file?project_id=p1&path=internal/api/ws.go&diff_hash=diff_abc&offset=0&limit=200
func (h *GitHandler) FileDiff(c *gin.Context) {
    projectID := c.Query("project_id")
    path := c.Query("path")
    diffHash := c.Query("diff_hash")
    offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))
    limit, _ := strconv.Atoi(c.DefaultQuery("limit", "200"))
    project, _ := h.projectMgr.Get(c, projectID)
    diff, _ := h.gitService.GetFileDiff(c, project.Path, path, diffHash, offset, limit)
    c.JSON(200, diff)
}

// POST /api/git/stage
func (h *GitHandler) Stage(c *gin.Context) {
    var req struct {
        ProjectID string   `json:"project_id"`
        Paths     []string `json:"paths"`
    }
    c.ShouldBindJSON(&req)
    project, _ := h.projectMgr.Get(c, req.ProjectID)
    for _, path := range req.Paths {
        h.gitService.git(c, project.Path, "add", path)
    }
    c.JSON(200, gin.H{"ok": true})
}

// POST /api/git/unstage
func (h *GitHandler) Unstage(c *gin.Context) {}

// POST /api/git/discard
func (h *GitHandler) Discard(c *gin.Context) {}

// POST /api/git/commit
func (h *GitHandler) Commit(c *gin.Context) {}

// POST /api/git/push
func (h *GitHandler) Push(c *gin.Context) {}
```

---

## 三、Flutter：Git 页面

### 3.1 Git 状态页面

```dart
// features/git/status/git_status_page.dart

class GitStatusPage extends ConsumerWidget {
  final String projectId;

  // 数据流：
  // 1. 打开页面 → GET /api/git/summary
  // 2. 检查本地 version
  //    - 相同 → 显示本地缓存
  //    - 不同 → GET /api/git/changes
  // 3. WebSocket git.changed 事件 → 重新拉 summary

  // UI：
  // - 分支名 + ahead/behind
  // - 变更文件数量 badge
  // - 文件变化列表（点击进入 Diff 页面）
  // - 操作按钮：stage all / commit / push
}
```

### 3.2 文件变化列表

```dart
// features/git/changes/changes_list_page.dart

class ChangesListPage extends ConsumerWidget {
  final String projectId;

  // 列表项：
  // - 文件图标（M/A/D/R）
  // - 文件路径
  // - +N -M 数字
  // - staged/unstaged 标记
  // - 点击 → 进入 Diff 页面

  // 长按操作：
  // - Stage
  // - Unstage
  // - Discard（需确认）
}
```

### 3.3 Diff 查看页面

```dart
// features/git/diff/diff_view_page.dart

class DiffViewPage extends ConsumerStatefulWidget {
  final String projectId;
  final String filePath;
  final String diffHash;

  // 数据流：
  // 1. 检查本地 diff_cache 有 diffHash
  //    - 有 → 直接渲染
  //    - 无 → GET /api/git/diff/file?offset=0&limit=200
  // 2. 滚动到底部 → 加载更多（offset += 200）
  // 3. 本地缓存完整 diff

  // UI：
  // - 文件路径标题
  // - Diff 行列表（虚拟滚动）
  //   - add: 绿色背景
  //   - del: 红色背景
  //   - context: 灰色
  // - 行号显示
}
```

### 3.4 本地 SQLite 缓存

```dart
// core/cache/git_cache.dart

class GitCache {
  final DriftDatabase _db;

  // Git 状态缓存
  Future<GitSummary?> getCachedSummary(String projectId) async {}
  Future<void> cacheSummary(GitSummary summary) async {}

  // 文件变化缓存
  Future<List<FileChange>> getCachedChanges(String projectId) async {}
  Future<void> cacheChanges(String projectId, List<FileChange> changes) async {}

  // Diff 缓存（按 diffHash）
  Future<String?> getCachedDiff(String projectId, String path, String diffHash) async {}
  Future<void> cacheDiff(String projectId, String path, String diffHash, String content) async {}

  // 清理过期缓存
  Future<void> cleanup({Duration maxAge = const Duration(days: 7)}) async {}
}
```

---

## 四、实施步骤

### Week 1：Go Git Service

| 天 | 任务 |
|---|---|
| D1 | GitService 基础（git 命令封装）+ Summary 计算 |
| D2 | Status 解析 + WorktreeHash/IndexHash 计算 |
| D3 | Version 管理（DB 读写 + bump 逻辑） |
| D4 | Changes 计算（numstat 解析 + untracked） |
| D5 | Diff 计算 + 分页 |
| D6 | Diff Hash 计算 + Diff 缓存 |
| D7 | Git Watcher（fsnotify + debounce） |

### Week 2：HTTP API + Flutter

| 天 | 任务 |
|---|---|
| D8 | Git HTTP API（summary/changes/diff/stage/unstage/commit） |
| D9 | 联调测试 Git API |
| D10-11 | Flutter：Git 状态页面 + 文件变化列表 |
| D12-13 | Flutter：Diff 查看页面（分页加载 + 虚拟滚动） |
| D14 | Flutter：本地缓存 + 端到端测试 |

---

## 五、验收标准

1. GET /api/git/summary 返回正确状态，version 正确递增
2. GET /api/git/changes 只在 version 变化时返回新数据
3. GET /api/git/diff/file 支持分页（offset/limit），大 diff 不会一次返回
4. Diff Hash 相同时，Flutter 直接使用缓存不请求网络
5. Git Watcher 在 Codex 修改文件后 500ms 内触发 summary 更新
6. WebSocket git.changed 事件正确推送到 Flutter
7. 打开项目的总流量 < 1KB（version 未变化时接近 0）
