# Phase 5：操作能力 + 产品化（2 周）

## 目标

完善 Git 操作、Session 高级功能、安全加固、性能优化、产品化打磨。

## 前置条件

Phase 1-4 完成。

## 产出

- Git 完整操作（stage/unstage/commit/push/discard/log/branches）
- Session fork/compact/rollback
- 审计日志
- 限流 + 压缩
- 设置页面
- 错误处理 + 性能优化

---

## 一、Git 操作补全

### 1.1 Commit

```go
// POST /api/git/commit
func (h *GitHandler) Commit(c *gin.Context) {
    var req struct {
        ProjectID string `json:"project_id"`
        Message   string `json:"message"`
        All       bool   `json:"all"` // -a 参数
    }
    c.ShouldBindJSON(&req)

    if strings.TrimSpace(req.Message) == "" {
        c.JSON(400, gin.H{"error": "commit message required"})
        return
    }

    project, _ := h.projectMgr.Get(c, req.ProjectID)

    args := []string{"commit", "-m", req.Message}
    if req.All {
        args = append(args, "-a")
    }

    out, err := h.gitService.git(c, project.Path, args...)
    if err != nil {
        c.JSON(500, gin.H{"error": string(out)})
        return
    }

    c.JSON(200, gin.H{"ok": true, "output": string(out)})
}
```

### 1.2 Push

```go
// POST /api/git/push（需要确认）
func (h *GitHandler) Push(c *gin.Context) {
    var req struct {
        ProjectID string `json:"project_id"`
        Remote    string `json:"remote"`   // 默认 "origin"
        Branch    string `json:"branch"`   // 默认当前分支
        Force     bool   `json:"force"`    // --force-with-lease
    }
    c.ShouldBindJSON(&req)

    // 安全检查
    if req.Force {
        // force push 需要额外确认
        if c.GetHeader("X-Confirm-Force") != "true" {
            c.JSON(400, gin.H{"error": "force push requires confirmation", "code": "CONFIRM_REQUIRED"})
            return
        }
    }

    project, _ := h.projectMgr.Get(c, req.ProjectID)

    remote := req.Remote
    if remote == "" {
        remote = "origin"
    }
    branch := req.Branch
    if branch == "" {
        branch = "HEAD"
    }

    args := []string{"push", remote, branch}
    if req.Force {
        args = append(args, "--force-with-lease")
    }

    out, err := h.gitService.git(c, project.Path, args...)
    if err != nil {
        c.JSON(500, gin.H{"error": string(out)})
        return
    }

    c.JSON(200, gin.H{"ok": true, "output": string(out)})
}
```

### 1.3 Discard

```go
// POST /api/git/discard（需确认）
func (h *GitHandler) Discard(c *gin.Context) {
    var req struct {
        ProjectID string   `json:"project_id"`
        Paths     []string `json:"paths"`
        Staged    bool     `json:"staged"` // 是否也丢弃 staged
    }
    c.ShouldBindJSON(&req)

    project, _ := h.projectMgr.Get(c, req.ProjectID)

    for _, path := range req.Paths {
        if req.Staged {
            // 先 unstage
            h.gitService.git(c, project.Path, "reset", "HEAD", "--", path)
        }
        // 丢弃工作区变更
        h.gitService.git(c, project.Path, "checkout", "--", path)
    }

    c.JSON(200, gin.H{"ok": true})
}
```

### 1.4 Log

```go
// GET /api/git/log?project_id=p1&limit=50&offset=0
func (h *GitHandler) Log(c *gin.Context) {
    projectID := c.Query("project_id")
    limit := c.DefaultQuery("limit", "50")
    offset := c.DefaultQuery("offset", "0")
    project, _ := h.projectMgr.Get(c, projectID)

    format := "%H|%an|%ae|%at|%s"
    out, _ := h.gitService.git(c, project.Path,
        "log", fmt.Sprintf("-%s", limit), fmt.Sprintf("--skip=%s", offset),
        fmt.Sprintf("--format=%s", format))

    var commits []GitCommit
    for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
        parts := strings.SplitN(line, "|", 5)
        if len(parts) == 5 {
            timestamp, _ := strconv.ParseInt(parts[3], 10, 64)
            commits = append(commits, GitCommit{
                Hash:      parts[0],
                Author:    parts[1],
                Email:     parts[2],
                Timestamp: time.Unix(timestamp, 0),
                Message:   parts[4],
            })
        }
    }

    c.JSON(200, gin.H{"commits": commits})
}
```

### 1.5 Branches

```go
// GET /api/git/branches?project_id=p1
func (h *GitHandler) Branches(c *gin.Context) {
    projectID := c.Query("project_id")
    project, _ := h.projectMgr.Get(c, projectID)

    out, _ := h.gitService.git(c, project.Path, "branch", "-a", "--format=%(refname:short)|%(HEAD)")

    var branches []Branch
    for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
        parts := strings.SplitN(line, "|", 2)
        if len(parts) == 2 {
            branches = append(branches, Branch{
                Name:    parts[0],
                Current: parts[1] == "*",
            })
        }
    }

    c.JSON(200, gin.H{"branches": branches})
}
```

---

## 二、Session 高级功能

### 2.1 Session 输入 API

```go
// POST /api/sessions/:id/input
func (h *SessionHandler) SendInput(c *gin.Context) {
    sessionID := c.Param("id")
    var req struct {
        Input string `json:"input"`
    }
    c.ShouldBindJSON(&req)

    session, _ := h.manager.GetSession(sessionID)
    p, _ := h.registry.Get(session.ProviderID)

    if err := p.SendInput(c, sessionID, req.Input); err != nil {
        c.JSON(500, gin.H{"error": err.Error()})
        return
    }

    c.JSON(200, gin.H{"ok": true})
}
```

### 2.2 Session 中断

```go
// POST /api/sessions/:id/interrupt
func (h *SessionHandler) Interrupt(c *gin.Context) {
    sessionID := c.Param("id")
    session, _ := h.manager.GetSession(sessionID)
    p, _ := h.registry.Get(session.ProviderID)
    p.InterruptSession(c, sessionID)
    c.JSON(200, gin.H{"ok": true})
}
```

### 2.3 Session Fork

```go
// POST /api/sessions/:id/fork
func (h *SessionHandler) Fork(c *gin.Context) {
    newSession, err := h.manager.ForkSession(c, c.Param("id"))
    c.JSON(200, newSession)
}
```

### 2.4 Session Compact

```go
// POST /api/sessions/:id/compact
func (h *SessionHandler) Compact(c *gin.Context) {
    session, _ := h.manager.GetSession(c.Param("id"))
    p, _ := h.registry.Get(session.ProviderID)
    p.CompactSession(c, session.ID)
    c.JSON(200, gin.H{"ok": true})
}
```

### 2.5 Session Rollback

```go
// POST /api/sessions/:id/rollback
func (h *SessionHandler) Rollback(c *gin.Context) {
    var req struct {
        Turns int `json:"turns"`
    }
    c.ShouldBindJSON(&req)
    session, _ := h.manager.GetSession(c.Param("id"))
    p, _ := h.registry.Get(session.ProviderID)
    p.RollbackSession(c, session.ID, req.Turns)
    c.JSON(200, gin.H{"ok": true})
}
```

---

## 三、安全加固

### 3.1 审计日志

```go
// internal/security/audit.go

type AuditLogger struct {
    db *storage.SQLite
}

type AuditEntry struct {
    ID        int64     `json:"id"`
    SessionID string    `json:"session_id,omitempty"`
    Action    string    `json:"action"`
    Target    string    `json:"target"`
    Detail    string    `json:"detail"`
    Result    string    `json:"result"`
    CreatedAt time.Time `json:"created_at"`
}

func (l *AuditLogger) Log(sessionID, action, target, detail, result string) {
    l.db.Exec(`INSERT INTO audit_log (session_id, action, target, detail, result, created_at) VALUES (?, ?, ?, ?, ?, ?)`,
        sessionID, action, target, detail, result, time.Now().Unix())
}

// 在中间件中使用
func AuditMiddleware(audit *AuditLogger) gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        c.Next()
        audit.Log(
            c.GetString("session_id"),
            c.Request.Method,
            c.Request.URL.Path,
            fmt.Sprintf("status=%d", c.Writer.Status()),
            fmt.Sprintf("duration=%s", time.Since(start)),
        )
    }
}
```

### 3.2 限流

```go
// internal/api/middleware/ratelimit.go

func RateLimit(requestsPerMinute int) gin.HandlerFunc {
    limiter := rate.NewLimiter(rate.Every(time.Minute/time.Duration(requestsPerMinute)), requestsPerMinute)
    return func(c *gin.Context) {
        if !limiter.Allow() {
            c.AbortWithStatusJSON(429, gin.H{"error": "rate limit exceeded"})
            return
        }
        c.Next()
    }
}
```

### 3.3 压缩

```go
// internal/api/middleware/compress.go

func Compress() gin.HandlerFunc {
    return func(c *gin.Context) {
        encoding := c.GetHeader("Accept-Encoding")
        if strings.Contains(encoding, "zstd") {
            c.Header("Content-Encoding", "zstd")
            // 使用 zstd writer
        } else if strings.Contains(encoding, "gzip") {
            c.Header("Content-Encoding", "gzip")
            c.Writer = gzip.NewWriter(c.Writer)
        }
        c.Next()
    }
}
```

---

## 四、Flutter 设置页面

### 4.1 设置页面结构

```dart
// features/settings/settings_page.dart

class SettingsPage extends StatelessWidget {
  // 分组：
  // 1. Agent 连接
  //    - 已连接 Agent 列表
  //    - 添加/编辑/删除
  // 2. Codex 配置
  //    - 默认模型
  //    - 默认审批策略
  //    - 默认沙箱模式
  // 3. 缓存管理
  //    - Git 缓存大小
  //    - 文件缓存大小
  //    - 会话缓存大小
  //    - 清理按钮
  // 4. 关于
  //    - 版本号
  //    - 开源许可
}
```

### 4.2 Codex 配置页面

```dart
// features/settings/codex_config_page.dart

class CodexConfigPage extends ConsumerStatefulWidget {
  // 可配置项：
  // - 模型选择（从 GET /api/providers/codex/models 获取列表）
  // - 审批策略（untrusted / on-request / never）
  // - 沙箱模式（read-only / workspace-write / danger-full-access）
  // - Web 搜索开关
  // - 推理努力度（low / medium / high）

  // 保存：PUT /api/codex/config
}
```

### 4.3 缓存管理页面

```dart
// features/settings/cache_settings_page.dart

class CacheSettingsPage extends ConsumerStatefulWidget {
  // 显示：
  // - 各类缓存占用大小
  // - 缓存条目数量
  // - 最后清理时间

  // 操作：
  // - 清理 Git diff 缓存
  // - 清理文件缓存
  // - 清理会话事件缓存（保留最近 N 天）
  // - 全部清理
}
```

---

## 五、错误处理 + 性能优化

### 5.1 Go 错误处理

```go
// 统一错误响应
type APIError struct {
    Code    string `json:"code"`
    Message string `json:"message"`
    Detail  string `json:"detail,omitempty"`
}

// 错误码
const (
    ErrCodeUnauthorized     = "UNAUTHORIZED"
    ErrCodeNotFound         = "NOT_FOUND"
    ErrCodePathTraversal    = "PATH_TRAVERSAL"
    ErrCodeProviderNotFound = "PROVIDER_NOT_FOUND"
    ErrCodeSessionNotFound  = "SESSION_NOT_FOUND"
    ErrCodeGitError         = "GIT_ERROR"
    ErrCodeRateLimited      = "RATE_LIMITED"
    ErrCodeConfirmRequired  = "CONFIRM_REQUIRED"
)
```

### 5.2 Flutter 性能优化

```dart
// 1. 虚拟列表（大列表性能）
// 使用 ListView.builder 自动虚拟化

// 2. 懒加载（文件树展开时才加载子目录）

// 3. 图片/大文件延迟加载

// 4. WebSocket 消息批处理
// 50ms 内的消息合并处理，避免频繁 setState

// 5. 缓存预热
// App 启动时预加载最近使用的项目 Git 状态
```

---

## 六、实施步骤

### Week 1

| 天 | 任务 |
|---|---|
| D1 | Git commit/push/discard API |
| D2 | Git log/branches API |
| D3 | Session input/interrupt/fork/compact/rollback API |
| D4 | 审计日志 + 限流 + 压缩中间件 |
| D5 | 错误处理统一 + API 文档补全 |

### Week 2

| 天 | 任务 |
|---|---|
| D6-7 | Flutter：Git 操作页面（commit/push/log/branches） |
| D8 | Flutter：设置页面结构 |
| D9 | Flutter：Codex 配置页面 + 缓存管理页面 |
| D10 | Flutter：错误处理 + 重试机制 |
| D11-12 | 性能优化 + 端到端测试 |
| D13-14 | Bug 修复 + UI 打磨 |

---

## 七、验收标准

1. Git stage/unstage/commit 操作正确
2. Git push 需确认，force push 需额外确认
3. Git discard 需确认，操作后文件恢复
4. Session fork 创建新会话，共享历史
5. Session compact 压缩历史，减少 token 使用
6. Session rollback 回退到指定 turn
7. 审计日志记录所有敏感操作
8. 限流生效（429 响应）
9. gzip/zstd 压缩生效
10. 设置页面可修改 Codex 配置
11. 缓存管理可清理各类缓存
