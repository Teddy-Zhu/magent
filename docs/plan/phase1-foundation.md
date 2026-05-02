# Phase 1：基础框架（2 周）

## 目标

搭建 Go Agent 骨架和 Flutter App 骨架，实现基本的连接、认证、项目管理能力。

## 前置条件

无。

## 产出

- Go Agent 可启动 HTTP/WS 服务，支持 Token 鉴权
- Flutter App 可连接 Agent，查看/创建项目
- 健康检查端点、统一响应格式、WebSocket 心跳

---

## 一、Go Agent

### 1.1 项目结构初始化

```
agent/
├── cmd/magent/main.go            # 入口
├── internal/
│   ├── api/
│   │   ├── server.go            # HTTP + WS 服务器
│   │   ├── router.go            # 路由注册
│   │   ├── response.go          # 统一响应工具（OK/Fail/NotModified）
│   │   └── middleware/
│   │       ├── auth.go          # Token 鉴权
│   │       └── cors.go          # CORS（gin-contrib/cors）
│   ├── config/
│   │   └── config.go            # 配置结构 + 加载
│   ├── project/
│   │   ├── manager.go           # 项目 CRUD
│   │   └── models.go            # 项目模型
│   ├── storage/
│   │   ├── sqlite.go            # SQLite 初始化（WAL + SetMaxOpenConns(1)）
│   │   └── migrations.go        # Schema 迁移
│   └── ws/
│       ├── hub.go               # WebSocket 连接管理 + 心跳
│       └── client.go            # 单个客户端
├── configs/
│   └── default.yaml             # 默认配置
├── go.mod
└── go.sum
```

### 1.2 配置系统

```yaml
# configs/default.yaml
server:
  host: "127.0.0.1"
  port: 9000

auth:
  tokens:
    - name: "default"
      token: ""  # 首次启动自动生成

workspace:
  allowed_dirs: []
```

实现要点：
- 使用 `spf13/viper` 加载 YAML
- 支持环境变量覆盖 `MAGENT_SERVER_PORT` 等
- Token 为空时自动生成并写入配置文件
- 提供 `magent init` 命令初始化配置

```go
// internal/config/config.go
type Config struct {
    Server    ServerConfig    `mapstructure:"server"`
    Auth      AuthConfig      `mapstructure:"auth"`
    Workspace WorkspaceConfig `mapstructure:"workspace"`
}

type ServerConfig struct {
    Host         string        `mapstructure:"host"`
    Port         int           `mapstructure:"port"`
    ReadTimeout  time.Duration `mapstructure:"read_timeout"`
    WriteTimeout time.Duration `mapstructure:"write_timeout"`
}

type AuthConfig struct {
    Tokens []TokenConfig `mapstructure:"tokens"`
}

type TokenConfig struct {
    Name        string   `mapstructure:"name"`
    Token       string   `mapstructure:"token"`
    Permissions []string `mapstructure:"permissions"`
}

type WorkspaceConfig struct {
    AllowedDirs     []string `mapstructure:"allowed_dirs"`
    ExcludedPattern []string `mapstructure:"excluded_patterns"`
}
```

### 1.3 HTTP Server

```go
// internal/api/server.go
type Server struct {
    cfg       *config.Config
    router    *gin.Engine
    wsHub     *ws.Hub
    store     *storage.SQLite
    projectMgr *project.Manager
}

func (s *Server) Start(ctx context.Context) error {
    s.router = gin.New()
    s.router.Use(gin.Recovery())
    s.router.Use(middleware.CORS())
    s.router.Use(middleware.Auth(s.cfg.Auth))

    s.registerRoutes()

    addr := fmt.Sprintf("%s:%d", s.cfg.Server.Host, s.cfg.Server.Port)
    srv := &http.Server{
        Addr:         addr,
        Handler:      s.router,
        ReadTimeout:  s.cfg.Server.ReadTimeout,
        WriteTimeout: s.cfg.Server.WriteTimeout,
    }

    return srv.ListenAndServe()
}
```

### 1.4 Token 鉴权中间件

```go
// internal/api/middleware/auth.go
func Auth(cfg config.AuthConfig) gin.HandlerFunc {
    return func(c *gin.Context) {
        // 从 Header 或 Query 取 token
        token := c.GetHeader("Authorization")
        if token == "" {
            token = c.Query("token")
        }
        // 去掉 "Bearer " 前缀
        token = strings.TrimPrefix(token, "Bearer ")

        // 验证
        for _, t := range cfg.Tokens {
            if t.Token == token {
                c.Set("token_name", t.Name)
                c.Set("permissions", t.Permissions)
                c.Next()
                return
            }
        }

        c.AbortWithStatusJSON(401, gin.H{"error": "unauthorized"})
    }
}
```

### 1.5 统一响应工具

```go
// internal/api/response.go

func OK(c *gin.Context, data any) {
    c.JSON(200, gin.H{"ok": true, "data": data})
}

func Fail(c *gin.Context, httpCode int, errCode, msg string) {
    c.JSON(httpCode, gin.H{
        "ok":    false,
        "error": gin.H{"code": errCode, "message": msg},
    })
}

func NotModified(c *gin.Context) {
    c.Status(304)
}

// 错误码常量
const (
    ErrUnauthorized     = "UNAUTHORIZED"
    ErrNotFound         = "NOT_FOUND"
    ErrPathTraversal    = "PATH_TRAVERSAL"
    ErrProviderNotFound = "PROVIDER_NOT_FOUND"
    ErrSessionNotFound  = "SESSION_NOT_FOUND"
    ErrGitError         = "GIT_ERROR"
    ErrRateLimited      = "RATE_LIMITED"
    ErrConfirmRequired  = "CONFIRM_REQUIRED"
)
```

### 1.6 健康检查

```go
// GET /healthz（无需鉴权）
func (s *Server) handleHealthz(c *gin.Context) {
    c.JSON(200, gin.H{
        "status":  "ok",
        "version": version,
        "uptime":  time.Since(startTime).String(),
    })
}

// 在 router.go 中注册（不经过 Auth 中间件）
s.router.GET("/healthz", s.handleHealthz)
```

### 1.7 WebSocket Hub（含心跳）

```go
// internal/ws/hub.go

type Hub struct {
    clients     map[*Client]bool
    register    chan *Client
    unregister  chan *Client
    broadcast   chan []byte
    mu          sync.RWMutex
    maxPerToken int // 每个 token 最多连接数
}

func NewHub() *Hub {
    return &Hub{
        clients:     make(map[*Client]bool),
        register:    make(chan *Client),
        unregister:  make(chan *Client),
        broadcast:   make(chan []byte, 256),
        maxPerToken: 5,
    }
}

// 连接数限制检查
func (h *Hub) canRegister(tokenName string) bool {
    h.mu.RLock()
    defer h.mu.RUnlock()
    count := 0
    for c := range h.clients {
        if c.tokenName == tokenName {
            count++
        }
    }
    return count < h.maxPerToken
}

func (h *Hub) Run(ctx context.Context) {
    for {
        select {
        case client := <-h.register:
            h.mu.Lock()
            h.clients[client] = true
            h.mu.Unlock()
        case client := <-h.unregister:
            h.mu.Lock()
            delete(h.clients, client)
            h.mu.Unlock()
        case msg := <-h.broadcast:
            h.mu.RLock()
            for client := range h.clients {
                client.Send(msg)
            }
            h.mu.RUnlock()
        case <-ctx.Done():
            return
        }
    }
}

// Broadcast 向所有客户端广播事件
func (h *Hub) Broadcast(event any) {
    data, _ := json.Marshal(event)
    h.broadcast <- data
}

// SendTo 向指定客户端发送
func (h *Hub) SendTo(tokenName string, event any) {
    // 根据 tokenName 找到对应客户端
}
```

### 1.8 WebSocket 客户端（含心跳）

```go
// internal/ws/client.go

type Client struct {
    hub       *Hub
    conn      *websocket.Conn
    send      chan []byte
    tokenName string
    lastPong  time.Time
}

const (
    writeWait      = 10 * time.Second
    pongWait       = 60 * time.Second
    pingPeriod     = 30 * time.Second  // 必须 < pongWait
    maxMessageSize = 1 << 20           // 1MB
)

func (c *Client) readPump() {
    defer func() {
        c.hub.unregister <- c
        c.conn.Close()
    }()
    c.conn.SetReadLimit(maxMessageSize)
    c.conn.SetReadDeadline(time.Now().Add(pongWait))
    c.conn.SetPongHandler(func(string) error {
        c.lastPong = time.Now()
        c.conn.SetReadDeadline(time.Now().Add(pongWait))
        return nil
    })
    for {
        _, _, err := c.conn.ReadMessage()
        if err != nil {
            break
        }
        // 客户端消息处理（如 session.attach）
    }
}

func (c *Client) writePump() {
    ticker := time.NewTicker(pingPeriod)
    defer func() {
        ticker.Stop()
        c.conn.Close()
    }()
    for {
        select {
        case msg, ok := <-c.send:
            c.conn.SetWriteDeadline(time.Now().Add(writeWait))
            if !ok {
                c.conn.WriteMessage(websocket.CloseMessage, []byte{})
                return
            }
            c.conn.WriteMessage(websocket.TextMessage, msg)
        case <-ticker.C:
            c.conn.SetWriteDeadline(time.Now().Add(writeWait))
            if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
                return
            }
        }
    }
}
```

### 1.9 SQLite 初始化 + 迁移

```go
// internal/storage/sqlite.go
type SQLite struct {
    db *sql.DB
}

func Open(path string) (*SQLite, error) {
    db, err := sql.Open("sqlite", path+"?_journal_mode=WAL&_busy_timeout=5000")
    if err != nil {
        return nil, err
    }
    // SQLite 单写者：限制连接数避免并发写入冲突
    db.SetMaxOpenConns(1)
    s := &SQLite{db: db}
    if err := s.migrate(); err != nil {
        return nil, err
    }
    return s, nil
}

func (s *SQLite) migrate() error {
    // Phase 1 Schema
    _, err := s.db.Exec(`
        CREATE TABLE IF NOT EXISTS projects (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            path TEXT NOT NULL,
            default_provider TEXT DEFAULT 'codex',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS sessions (
            id TEXT PRIMARY KEY,
            provider_id TEXT NOT NULL,
            thread_id TEXT,
            project_id TEXT NOT NULL,
            title TEXT,
            workdir TEXT,
            status TEXT NOT NULL,
            runner_type TEXT NOT NULL,
            model TEXT,
            approval_mode TEXT,
            sandbox_mode TEXT,
            config TEXT,
            last_seq INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            exited_at INTEGER
        );

        CREATE TABLE IF NOT EXISTS session_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL,
            seq INTEGER NOT NULL,
            type TEXT NOT NULL,
            payload BLOB,
            created_at INTEGER NOT NULL,
            UNIQUE(session_id, seq)
        );
        CREATE INDEX IF NOT EXISTS idx_events_session_seq
            ON session_events(session_id, seq);

        CREATE TABLE IF NOT EXISTS git_state (
            project_id TEXT PRIMARY KEY,
            version INTEGER NOT NULL,
            head TEXT,
            branch TEXT,
            upstream TEXT,
            ahead INTEGER DEFAULT 0,
            behind INTEGER DEFAULT 0,
            worktree_hash TEXT,
            index_hash TEXT,
            changed_count INTEGER DEFAULT 0,
            staged_count INTEGER DEFAULT 0,
            unstaged_count INTEGER DEFAULT 0,
            untracked_count INTEGER DEFAULT 0,
            updated_at INTEGER NOT NULL
        );

        CREATE TABLE IF NOT EXISTS git_file_changes (
            project_id TEXT NOT NULL,
            path TEXT NOT NULL,
            version INTEGER NOT NULL,
            status TEXT NOT NULL,
            staged INTEGER DEFAULT 0,
            additions INTEGER DEFAULT 0,
            deletions INTEGER DEFAULT 0,
            binary INTEGER DEFAULT 0,
            old_hash TEXT,
            new_hash TEXT,
            diff_hash TEXT,
            size INTEGER,
            PRIMARY KEY(project_id, path, version)
        );

        CREATE TABLE IF NOT EXISTS git_diff_cache (
            project_id TEXT NOT NULL,
            path TEXT NOT NULL,
            diff_hash TEXT NOT NULL,
            content TEXT,
            total_lines INTEGER,
            created_at INTEGER NOT NULL,
            PRIMARY KEY(project_id, path, diff_hash)
        );

        CREATE TABLE IF NOT EXISTS file_cache (
            project_id TEXT NOT NULL,
            path TEXT NOT NULL,
            hash TEXT NOT NULL,
            size INTEGER,
            mtime INTEGER,
            content BLOB,
            created_at INTEGER NOT NULL,
            PRIMARY KEY(project_id, path, hash)
        );

        CREATE TABLE IF NOT EXISTS dir_cache (
            project_id TEXT NOT NULL,
            path TEXT NOT NULL,
            hash TEXT NOT NULL,
            items TEXT,
            created_at INTEGER NOT NULL,
            PRIMARY KEY(project_id, path)
        );

        CREATE TABLE IF NOT EXISTS audit_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT,
            action TEXT NOT NULL,
            target TEXT,
            detail TEXT,
            result TEXT,
            created_at INTEGER NOT NULL
        );

        -- 基础配置同步缓存（Flutter bootstrap 用）
        CREATE TABLE IF NOT EXISTS bootstrap_cache (
            id INTEGER PRIMARY KEY CHECK (id = 1),  -- 只有一行
            config_hash TEXT NOT NULL,
            data BLOB NOT NULL,
            updated_at INTEGER NOT NULL
        );
    `)
    return err
}
```

### 1.7 Project Manager

```go
// internal/project/manager.go
type Manager struct {
    store *storage.SQLite
}

type Project struct {
    ID              string    `json:"id"`
    Name            string    `json:"name"`
    Path            string    `json:"path"`
    DefaultProvider string    `json:"default_provider"`
    CreatedAt       time.Time `json:"created_at"`
    UpdatedAt       time.Time `json:"updated_at"`
}

func (m *Manager) Create(ctx context.Context, name, path string) (*Project, error) {
    // 验证路径在白名单内
    if err := m.validatePath(path); err != nil {
        return nil, err
    }
    // 验证路径存在且是 git 仓库
    // ...
}

func (m *Manager) List(ctx context.Context) ([]Project, error) {}
func (m *Manager) Get(ctx context.Context, id string) (*Project, error) {}
func (m *Manager) Update(ctx context.Context, p *Project) error {}
func (m *Manager) Delete(ctx context.Context, id string) error {}

func (m *Manager) validatePath(path string) error {
    cleaned := filepath.Clean(path)
    if strings.Contains(cleaned, "..") {
        return ErrPathTraversal
    }
    resolved, err := filepath.EvalSymlinks(cleaned)
    if err != nil {
        return err
    }
    // 检查白名单
    // ...
}
```

### 1.8 HTTP 路由注册

```go
// internal/api/router.go
func (s *Server) registerRoutes() {
    api := s.router.Group("/api")
    api.Use(middleware.Auth(s.cfg.Auth))

    // Agent
    api.GET("/agent/info", s.handleAgentInfo)

    // Projects
    api.GET("/projects", s.handleListProjects)
    api.POST("/projects", s.handleCreateProject)
    api.GET("/projects/:id", s.handleGetProject)
    api.PUT("/projects/:id", s.handleUpdateProject)
    api.DELETE("/projects/:id", s.handleDeleteProject)

    // WebSocket
    api.GET("/ws", s.handleWebSocket)
}
```

---

## 二、Flutter App

### 2.1 项目结构

```
lib/
├── app/
│   ├── app.dart               # MaterialApp 入口
│   ├── router.dart            # GoRouter 路由
│   └── theme.dart             # 主题
├── core/
│   ├── api/
│   │   ├── api_client.dart    # Dio HTTP 客户端
│   │   ├── ws_client.dart     # WebSocket 客户端
│   │   └── interceptors.dart  # Token 拦截器
│   ├── storage/
│   │   ├── database.dart      # Drift 数据库
│   │   └── secure_storage.dart # Token 安全存储
│   └── models/
│       ├── agent.dart
│       └── project.dart
├── features/
│   ├── agents/
│   │   ├── connect/
│   │   │   └── agent_connect_page.dart
│   │   └── list/
│   │       └── agent_list_page.dart
│   └── projects/
│       ├── list/
│       │   └── project_list_page.dart
│       └── detail/
│           └── project_detail_page.dart
└── shared/
    ├── widgets/
    │   ├── loading_indicator.dart
    │   └── error_widget.dart
    └── utils/
        └── formatters.dart
```

### 2.2 API 客户端

```dart
// core/api/api_client.dart
class ApiClient {
  late final Dio _dio;
  final String baseUrl;
  final String token;

  ApiClient({required this.baseUrl, required this.token}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: {'Authorization': 'Bearer $token'},
    ));
    _dio.interceptors.add(LogInterceptor());
  }

  // Projects
  Future<List<Project>> listProjects() async {
    final resp = await _dio.get('/api/projects');
    return (resp.data as List).map((j) => Project.fromJson(j)).toList();
  }

  Future<Project> createProject(String name, String path) async {
    final resp = await _dio.post('/api/projects', data: {'name': name, 'path': path});
    return Project.fromJson(resp.data);
  }

  // ...
}
```

### 2.3 WebSocket 客户端

```dart
// core/api/ws_client.dart
class WsClient {
  final String url;
  final String token;
  WebSocketChannel? _channel;
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _eventController.stream;

  WsClient({required this.url, required this.token});

  void connect() {
    _channel = WebSocketChannel.connect(
      Uri.parse('$url/api/ws?token=$token'),
    );
    _channel!.stream.listen(
      (data) {
        final event = jsonDecode(data as String);
        _eventController.add(event);
      },
      onDone: () {
        // 自动重连
        Future.delayed(Duration(seconds: 2), connect);
      },
    );
  }

  void send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  void dispose() {
    _channel?.sink.close();
    _eventController.close();
  }
}
```

### 2.4 安全存储

```dart
// core/storage/secure_storage.dart
class AgentStorage {
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<void> saveAgent(String id, String url, String token, String name) async {
    await _storage.write(key: 'agent_${id}_url', value: url);
    await _storage.write(key: 'agent_${id}_token', value: token);
    await _storage.write(key: 'agent_${id}_name', value: name);
  }

  Future<List<AgentInfo>> loadAgents() async {
    final all = await _storage.readAll();
    // 解析 agent_* 前缀的 key
    // ...
  }

  Future<void> deleteAgent(String id) async {
    await _storage.delete(key: 'agent_${id}_url');
    await _storage.delete(key: 'agent_${id}_token');
    await _storage.delete(key: 'agent_${id}_name');
  }
}
```

Agent 信息存入 Drift DB（加密字段存 token），`flutter_secure_storage` 只存一个主加密密钥。
```

### 2.5 本地数据库（Drift）

```dart
// core/storage/database.dart

// 所有缓存表定义
@DriftDatabase(tables: [
  Agents,           // Agent 连接信息（token 加密存储）
  BootstrapCache,   // 基础配置缓存（config_hash + data）
  GitProjectState,  // Git 项目状态缓存
  GitFileChanges,   // Git 文件变化缓存
  GitDiffCache,     // Git Diff 缓存
  FileCache,        // 文件内容缓存
  DirCache,         // 目录缓存
  SessionState,     // 会话状态（last_seq）
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

// Agent 连接信息（token 加密存储，替代 flutter_secure_storage 扁平 KV）
class Agents extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get baseUrl => text()();
  TextColumn get encryptedToken => text()();  // 主密钥加密后的 token
  TextColumn get status => text().withDefault(const Constant('offline'))();
  DateTimeColumn get lastSeen => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

// 基础配置缓存表
class BootstrapCache extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get configHash => text()();
  TextColumn get data => text()();  // JSON
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}
```

使用 `freezed` + `json_serializable` 生成所有数据模型（Session、Project、GitSummary、FileChange 等）的 `fromJson`/`toJson`/`copyWith`/`==`。运行 `dart run build_runner build` 生成。

### 2.6 路由

```dart
// app/router.dart
final router = GoRouter(
  routes: [
    GoRoute(path: '/', redirect: (_) => '/agents'),
    GoRoute(
      path: '/agents',
      builder: (_, __) => AgentListPage(),
      routes: [
        GoRoute(path: 'connect', builder: (_, __) => AgentConnectPage()),
      ],
    ),
    GoRoute(
      path: '/projects',
      builder: (_, __) => ProjectListPage(),
      routes: [
        GoRoute(path: ':id', builder: (_, state) => ProjectDetailPage(
          projectId: state.pathParameters['id']!,
        )),
      ],
    ),
  ],
);
```

### 2.6 Agent 连接页面

```dart
// features/agents/connect/agent_connect_page.dart
class AgentConnectPage extends StatefulWidget {
  // 输入项：
  // - Agent 名称（可选，默认 "My Agent"）
  // - Agent URL（如 http://192.168.1.100:9000）
  // - Token
  //
  // 点击连接后：
  // 1. 调用 GET /api/agent/info 验证连接
  // 2. 成功则保存到 SecureStorage
  // 3. 跳转到项目列表
}
```

---

## 三、实施步骤

### 第 1 天：Go 项目初始化
- [ ] `go mod init`，安装依赖
- [ ] 配置系统（viper 加载 YAML）
- [ ] `cmd/magent/main.go` 入口（cobra 命令）

### 第 2 天：SQLite + 项目模型
- [ ] SQLite 初始化 + 迁移
- [ ] Project 模型 + Manager CRUD

### 第 3 天：HTTP Server + Auth
- [ ] Gin Server 初始化
- [ ] Token 鉴权中间件
- [ ] CORS 中间件
- [ ] Project CRUD API

### 第 4 天：WebSocket Hub
- [ ] Hub 实现（register/unregister/broadcast）
- [ ] Client 实现（read/write pump）
- [ ] WS 连接端点 + Token 验证

### 第 5 天：Agent Info + 路由完善
- [ ] GET /api/agent/info（版本、能力、状态）
- [ ] 完善所有路由注册
- [ ] 基础测试

### 第 6-7 天：Flutter 项目初始化
- [ ] `flutter create`，配置依赖
- [ ] 安全存储封装
- [ ] API 客户端封装
- [ ] WebSocket 客户端封装

### 第 8-9 天：Flutter 页面
- [ ] 主题系统（亮/暗）
- [ ] 路由配置
- [ ] Agent 连接页面
- [ ] Agent 列表页面

### 第 10 天：Flutter 项目页面
- [ ] 项目列表页面
- [ ] 项目详情页面（占位）
- [ ] 端到端联调

---

## 四、验收标准

1. `magent serve` 启动 Agent，监听 127.0.0.1:9000
2. `curl -H "Authorization: Bearer <token>" http://localhost:9000/api/agent/info` 返回 JSON
3. Flutter 输入 URL + Token 可连接 Agent
4. Flutter 可创建/查看/删除项目
5. WebSocket 连接可建立，收发消息正常
6. 重启 Agent 后数据不丢失（SQLite 持久化）
