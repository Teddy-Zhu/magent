# Phase 4：文件低流量系统（1.5 周）

## 目标

实现分层文件树加载、文件 hash 缓存、分页读取，让手机端高效浏览项目文件。

## 前置条件

Phase 1 完成（HTTP Server、SQLite、Project）。

## 产出

- 文件树分层加载 API
- 目录/文件 hash 缓存
- 文件内容按行/按字节分页读取
- Flutter 文件浏览器 + 代码高亮

---

## 一、设计要点

1. **不一次返回整个文件树**——目录多时流量爆炸
2. **目录 hash 判断变化**——hash 不变 = 不返回内容
3. **文件 hash 判断是否需要重新下载**
4. **大文件分页读取**——按行或按字节

---

## 二、Go Agent：File Service

### 2.1 目录结构

```
internal/fileservice/
├── service.go       # 主服务
├── tree.go          # 目录列表 + hash
├── reader.go        # 文件读取 + 分页
└── hash.go          # hash 计算
```

### 2.2 目录列表

```go
// internal/fileservice/tree.go

type DirEntry struct {
    Name  string `json:"name"`
    Type  string `json:"type"` // "dir" | "file"
    Size  int64  `json:"size,omitempty"`
    Mtime int64  `json:"mtime"`
    Hash  string `json:"hash,omitempty"` // 文件 hash
}

type DirListResult struct {
    Path    string     `json:"path"`
    Version string     `json:"version"` // 目录 hash
    Items   []DirEntry `json:"items"`
}

func (s *Service) ListDir(ctx context.Context, projectID, projectPath, relPath, knownHash string) (*DirListResult, int, error) {
    fullPath := filepath.Join(projectPath, relPath)

    // 路径安全检查
    if err := s.pathGuard.Validate(fullPath, projectPath); err != nil {
        return nil, 403, err
    }

    // 读取目录
    entries, err := os.ReadDir(fullPath)
    if err != nil {
        return nil, 404, err
    }

    // 过滤排除项
    entries = s.filterExcluded(entries)

    // 构建结果
    var items []DirEntry
    for _, e := range entries {
        info, _ := e.Info()
        item := DirEntry{
            Name:  e.Name(),
            Mtime: info.ModTime().Unix(),
        }
        if e.IsDir() {
            item.Type = "dir"
        } else {
            item.Type = "file"
            item.Size = info.Size()
            item.Hash = s.fileHash(filepath.Join(fullPath, e.Name()), info)
        }
        items = append(items, item)
    }

    // 计算目录 hash
    dirHash := s.computeDirHash(items)

    // 如果 knownHash 匹配，返回 304
    if knownHash != "" && knownHash == dirHash {
        return nil, 304, nil
    }

    return &DirListResult{
        Path:    relPath,
        Version: dirHash,
        Items:   items,
    }, 200, nil
}

func (s *Service) filterExcluded(entries []os.DirEntry) []os.DirEntry {
    excluded := map[string]bool{
        ".git":            true,
        "node_modules":    true,
        "__pycache__":     true,
        ".venv":           true,
        "vendor":          true,
        ".idea":           true,
        ".vscode":         true,
    }
    var result []os.DirEntry
    for _, e := range entries {
        if !excluded[e.Name()] {
            result = append(result, e)
        }
    }
    return result
}
```

### 2.3 目录 Hash

```go
// internal/fileservice/hash.go

func (s *Service) computeDirHash(items []DirEntry) string {
    h := sha256.New()
    // 按名称排序确保一致性
    sort.Slice(items, func(i, j int) bool { return items[i].Name < items[j].Name })
    for _, item := range items {
        h.Write([]byte(item.Name))
        h.Write([]byte(item.Type))
        h.Write([]byte(strconv.FormatInt(item.Size, 10)))
        h.Write([]byte(strconv.FormatInt(item.Mtime, 10)))
        if item.Hash != "" {
            h.Write([]byte(item.Hash))
        }
    }
    return "dir_" + hex.EncodeToString(h.Sum(nil))[:16]
}

func (s *Service) fileHash(path string, info os.FileInfo) string {
    // 小文件（<1MB）：内容 hash
    // 大文件：mtime + size hash
    if info.Size() < 1024*1024 {
        content, _ := os.ReadFile(path)
        h := sha256.Sum256(content)
        return "f_" + hex.EncodeToString(h[:])[:16]
    }
    h := sha256.New()
    h.Write([]byte(path))
    h.Write([]byte(strconv.FormatInt(info.Size(), 10)))
    h.Write([]byte(strconv.FormatInt(info.ModTime().Unix(), 10)))
    return "f_" + hex.EncodeToString(h.Sum(nil))[:16]
}
```

### 2.4 文件读取

```go
// internal/fileservice/reader.go

type FileContent struct {
    Path     string `json:"path"`
    Hash     string `json:"hash"`
    Size     int64  `json:"size"`
    Encoding string `json:"encoding"`
    Content  string `json:"content"`
}

type FileLines struct {
    Path       string   `json:"path"`
    Hash       string   `json:"hash"`
    Start      int      `json:"start"`
    Limit      int      `json:"limit"`
    TotalLines int      `json:"total_lines"`
    Lines      []string `json:"lines"`
}

type FileRange struct {
    Path   string `json:"path"`
    Hash   string `json:"hash"`
    Offset int64  `json:"offset"`
    Limit  int64  `json:"limit"`
    Total  int64  `json:"total"`
    Data   string `json:"data"` // base64 或 utf-8
}

// 完整读取（小文件，带 hash 校验）
func (s *Service) ReadFile(ctx context.Context, projectID, projectPath, relPath, knownHash string) (*FileContent, int, error) {
    fullPath := filepath.Join(projectPath, relPath)
    if err := s.pathGuard.Validate(fullPath, projectPath); err != nil {
        return nil, 403, err
    }

    info, err := os.Stat(fullPath)
    if err != nil {
        return nil, 404, err
    }

    hash := s.fileHash(fullPath, info)

    // hash 匹配，不需要重新读取
    if knownHash != "" && knownHash == hash {
        return nil, 304, nil
    }

    // 限制大小（<10MB）
    if info.Size() > 10*1024*1024 {
        return nil, 413, fmt.Errorf("file too large, use line/range API")
    }

    content, err := os.ReadFile(fullPath)
    if err != nil {
        return nil, 500, err
    }

    encoding := "utf-8"
    if !isUTF8(content) {
        encoding = "binary"
    }

    return &FileContent{
        Path:     relPath,
        Hash:     hash,
        Size:     info.Size(),
        Encoding: encoding,
        Content:  string(content),
    }, 200, nil
}

// 按行分页读取
func (s *Service) ReadFileLines(ctx context.Context, projectPath, relPath string, start, limit int) (*FileLines, error) {
    fullPath := filepath.Join(projectPath, relPath)
    file, err := os.Open(fullPath)
    if err != nil {
        return nil, err
    }
    defer file.Close()

    scanner := bufio.NewScanner(file)
    var lines []string
    lineNum := 0
    totalLines := 0

    for scanner.Scan() {
        totalLines++
        lineNum++
        if lineNum >= start && lineNum < start+limit {
            lines = append(lines, scanner.Text())
        }
        if lineNum >= start+limit {
            // 继续计数但不收集
        }
    }

    return &FileLines{
        Path:       relPath,
        Start:      start,
        Limit:      limit,
        TotalLines: totalLines,
        Lines:      lines,
    }, nil
}

// 按字节范围读取
func (s *Service) ReadFileRange(ctx context.Context, projectPath, relPath string, offset, limit int64) (*FileRange, error) {
    fullPath := filepath.Join(projectPath, relPath)
    file, err := os.Open(fullPath)
    if err != nil {
        return nil, err
    }
    defer file.Close()

    info, _ := file.Stat()
    buf := make([]byte, limit)
    n, _ := file.ReadAt(buf, offset)

    return &FileRange{
        Path:   relPath,
        Offset: offset,
        Limit:  limit,
        Total:  info.Size(),
        Data:   string(buf[:n]),
    }, nil
}
```

### 2.5 文件写入

```go
func (s *Service) WriteFile(ctx context.Context, projectPath, relPath string, content []byte) error {
    fullPath := filepath.Join(projectPath, relPath)
    if err := s.pathGuard.Validate(fullPath, projectPath); err != nil {
        return err
    }
    return os.WriteFile(fullPath, content, 0644)
}

func (s *Service) CreateFile(ctx context.Context, projectPath, relPath string, isDir bool) error {
    fullPath := filepath.Join(projectPath, relPath)
    if err := s.pathGuard.Validate(fullPath, projectPath); err != nil {
        return err
    }
    if isDir {
        return os.MkdirAll(fullPath, 0755)
    }
    return os.WriteFile(fullPath, []byte{}, 0644)
}

func (s *Service) DeleteFile(ctx context.Context, projectPath, relPath string) error {
    fullPath := filepath.Join(projectPath, relPath)
    if err := s.pathGuard.Validate(fullPath, projectPath); err != nil {
        return err
    }
    return os.RemoveAll(fullPath)
}

func (s *Service) RenameFile(ctx context.Context, projectPath, oldPath, newPath string) error {
    fullOld := filepath.Join(projectPath, oldPath)
    fullNew := filepath.Join(projectPath, newPath)
    if err := s.pathGuard.Validate(fullOld, projectPath); err != nil {
        return err
    }
    if err := s.pathGuard.Validate(fullNew, projectPath); err != nil {
        return err
    }
    return os.Rename(fullOld, fullNew)
}
```

### 2.6 HTTP API

```go
// internal/api/handlers/file.go

// GET /api/files/list?project_id=p1&path=internal&known_hash=abc
func (h *FileHandler) List(c *gin.Context) {
    projectID := c.Query("project_id")
    path := c.Query("path")
    knownHash := c.Query("known_hash")
    project, _ := h.projectMgr.Get(c, projectID)

    result, status, err := h.fileService.ListDir(c, projectID, project.Path, path, knownHash)
    if status == 304 {
        c.Status(304)
        return
    }
    c.JSON(200, result)
}

// GET /api/files/read?project_id=p1&path=main.go&hash=abc
func (h *FileHandler) Read(c *gin.Context) {
    projectID := c.Query("project_id")
    path := c.Query("path")
    hash := c.Query("hash")
    project, _ := h.projectMgr.Get(c, projectID)

    result, status, err := h.fileService.ReadFile(c, projectID, project.Path, path, hash)
    if status == 304 {
        c.Status(304)
        return
    }
    c.JSON(200, result)
}

// GET /api/files/read/lines?project_id=p1&path=x&start=1&limit=200
func (h *FileHandler) ReadLines(c *gin.Context) {}

// GET /api/files/read/range?project_id=p1&path=x&offset=0&limit=65536
func (h *FileHandler) ReadRange(c *gin.Context) {}

// POST /api/files/write
func (h *FileHandler) Write(c *gin.Context) {}

// POST /api/files/create
func (h *FileHandler) Create(c *gin.Context) {}

// POST /api/files/delete
func (h *FileHandler) Delete(c *gin.Context) {}

// POST /api/files/rename
func (h *FileHandler) Rename(c *gin.Context) {}
```

---

## 三、Flutter：文件浏览器

### 3.1 文件树页面

```dart
// features/files/tree/file_tree_page.dart

class FileTreePage extends ConsumerStatefulWidget {
  final String projectId;

  // 数据流：
  // 1. 初始：GET /api/files/list?path=（根目录）
  // 2. 点击目录：GET /api/files/list?path=xxx（懒加载）
  // 3. 每次请求带 known_hash，304 则用缓存
  // 4. WebSocket file.changed → 清除对应目录缓存，重新加载

  // UI：
  // - 树形列表，目录可展开/折叠
  // - 目录图标（📁）+ 文件图标（根据扩展名）
  // - 文件大小 + 修改时间
  // - 点击文件 → 进入代码查看页面
  // - 长按 → 操作菜单（重命名/删除）
}

// 文件图标映射
String getFileIcon(String name) {
  final ext = name.split('.').last.toLowerCase();
  switch (ext) {
    case 'go': return '🐹';
    case 'dart': return '🎯';
    case 'js': case 'ts': return '📜';
    case 'py': return '🐍';
    case 'md': return '📝';
    case 'json': case 'yaml': case 'toml': return '⚙️';
    case 'png': case 'jpg': case 'gif': return '🖼️';
    default: return '📄';
  }
}
```

### 3.2 代码查看页面

```dart
// features/files/viewer/code_viewer_page.dart

class CodeViewerPage extends ConsumerStatefulWidget {
  final String projectId;
  final String filePath;
  final String? fileHash;

  // 数据流：
  // 1. GET /api/files/read?path=x&hash=abc
  //    - 304 → 用本地缓存
  //    - 200 → 显示内容，缓存到本地
  // 2. 大文件（>1MB）→ 使用 lines API 分页加载
  // 3. 滚动到底 → 加载更多行

  // UI：
  // - 文件名标题
  // - 语法高亮（根据扩展名选择语言）
  // - 行号显示
  // - 搜索功能
  // - 编辑按钮（Phase 5）
}
```

### 3.3 本地缓存

```dart
// core/cache/file_cache.dart

class FileCache {
  final DriftDatabase _db;

  // 目录缓存
  Future<DirListResult?> getCachedDir(String projectId, String path) async {}
  Future<void> cacheDir(String projectId, String path, DirListResult result) async {}

  // 文件内容缓存（按 hash）
  Future<String?> getCachedFile(String projectId, String path, String hash) async {}
  Future<void> cacheFile(String projectId, String path, String hash, String content) async {}

  // 清理
  Future<void> cleanup({int maxSizeMB = 100}) async {}
}
```

---

## 四、路径安全防护

```go
// internal/security/path_guard.go

type PathGuard struct {
    allowedDirs []string
}

func (g *PathGuard) Validate(target, projectRoot string) error {
    // 1. 清理路径
    cleaned := filepath.Clean(target)

    // 2. 检查 ..
    if strings.Contains(cleaned, "..") {
        return fmt.Errorf("path traversal detected")
    }

    // 3. 解析符号链接
    resolved, err := filepath.EvalSymlinks(cleaned)
    if err != nil {
        // 文件不存在时用 Clean 后的路径
        resolved = cleaned
    }

    // 4. 确保在项目根目录内
    if !strings.HasPrefix(resolved, projectRoot) {
        return fmt.Errorf("path outside project root")
    }

    // 5. 确保在允许的工作空间目录内
    for _, dir := range g.allowedDirs {
        if strings.HasPrefix(resolved, dir) {
            return nil
        }
    }

    return fmt.Errorf("path outside allowed workspace")
}
```

---

## 五、实施步骤

### Week 1 前半：Go File Service

| 天 | 任务 |
|---|---|
| D1 | FileService 基础 + 目录列表 + 目录 hash |
| D2 | 文件 hash 计算 + 304 缓存逻辑 |
| D3 | 文件完整读取 + 按行分页 + 按字节分页 |
| D4 | 文件写入/创建/删除/重命名 + 路径安全防护 |

### Week 1 后半 + Week 2 前半：HTTP API + Flutter

| 天 | 任务 |
|---|---|
| D5 | File HTTP API 全部端点 |
| D6-7 | Flutter：文件树页面（懒加载 + 展开折叠） |
| D8-9 | Flutter：代码查看页面（语法高亮 + 分页加载） |
| D10 | Flutter：本地缓存 + 联调测试 |

---

## 六、验收标准

1. GET /api/files/list 分层返回目录内容，不返回 .git/node_modules 等
2. known_hash 匹配时返回 304，Flutter 使用缓存
3. 文件 hash 未变化时不重新下载内容
4. 大文件（>10MB）通过 lines/range API 分页读取
5. 路径穿越攻击被拦截（../、符号链接）
6. 文件树展开流畅，不阻塞 UI
7. 代码高亮正确（至少支持 Go/Dart/JS/Python/Markdown）
