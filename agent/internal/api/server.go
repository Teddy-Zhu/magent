package api

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/Teddy-Zhu/magent/agent/internal/api/middleware"
	"github.com/Teddy-Zhu/magent/agent/internal/config"
	"github.com/Teddy-Zhu/magent/agent/internal/fileservice"
	"github.com/Teddy-Zhu/magent/agent/internal/gitservice"
	"github.com/Teddy-Zhu/magent/agent/internal/log"
	"github.com/Teddy-Zhu/magent/agent/internal/project"
	"github.com/Teddy-Zhu/magent/agent/internal/provider"
	"github.com/Teddy-Zhu/magent/agent/internal/providers/aider"
	"github.com/Teddy-Zhu/magent/agent/internal/providers/claude"
	"github.com/Teddy-Zhu/magent/agent/internal/providers/codex"
	"github.com/Teddy-Zhu/magent/agent/internal/session"
	"github.com/Teddy-Zhu/magent/agent/internal/storage"
	syncpkg "github.com/Teddy-Zhu/magent/agent/internal/sync"
	"github.com/Teddy-Zhu/magent/agent/internal/ws"
	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

var (
	buildInfo = BuildInfo{
		Version:   "unknown",
		BuildTime: "unknown",
		GitCommit: "unknown",
	}
	startTime = time.Now()
)

type BuildInfo struct {
	Version   string `json:"version"`
	BuildTime string `json:"build_time"`
	GitCommit string `json:"git_commit"`
}

func SetBuildInfo(info BuildInfo) {
	if info.Version == "" {
		info.Version = "unknown"
	}
	if info.BuildTime == "" {
		info.BuildTime = "unknown"
	}
	if info.GitCommit == "" {
		info.GitCommit = "unknown"
	}
	buildInfo = info
}

type Server struct {
	cfg             *config.Config
	router          *gin.Engine
	wsHub           *ws.Hub
	store           *storage.SQLite
	projectMgr      *project.Manager
	registry        *provider.Registry
	gitService      *gitservice.Service
	sessionHandler  *SessionHandler
	gitHandler      *GitHandler
	fileHandler     *FileHandler
	syncHandler     *SyncHandler
	providerHandler *ProviderHandler
	auditLogger     *middleware.AuditLogger
	upgrader        websocket.Upgrader
}

func NewServer(cfg *config.Config, store *storage.SQLite) *Server {
	log.Debug("server", "initializing hub")
	hub := ws.NewHub()
	projectMgr := project.NewManager(store, cfg.Workspace.AllowedDirs, cfg.Workspace.ExcludedPattern)

	registry := provider.NewRegistry()
	codexProvider := codex.New(codex.CodexConfig{}, hub, store)
	registry.Register("codex", codexProvider)
	log.Debug("server", "registered provider: codex")
	registry.Register("claude", claude.New())
	log.Debug("server", "registered provider: claude")
	registry.Register("aider", aider.New())
	log.Debug("server", "registered provider: aider")

	sessionStore := session.NewSessionStore(store)
	sessionMgr := session.NewManager(sessionStore, registry, hub)

	configService := syncpkg.NewConfigService(registry, cfg, store, projectMgr, syncpkg.BuildInfo{
		Version:   buildInfo.Version,
		BuildTime: buildInfo.BuildTime,
		GitCommit: buildInfo.GitCommit,
	})

	gitService := gitservice.NewService(store)
	fileService := fileservice.NewService(store, cfg.Workspace.ExcludedPattern)

	auditLogger := middleware.NewAuditLogger(store)

	return &Server{
		cfg:             cfg,
		wsHub:           hub,
		store:           store,
		projectMgr:      projectMgr,
		registry:        registry,
		gitService:      gitService,
		sessionHandler:  NewSessionHandler(sessionMgr, projectMgr),
		gitHandler:      NewGitHandler(gitService, projectMgr, registry),
		fileHandler:     NewFileHandler(fileService, projectMgr),
		syncHandler:     NewSyncHandler(configService),
		providerHandler: NewProviderHandler(registry, projectMgr),
		auditLogger:     auditLogger,
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				return true
			},
			EnableCompression: true,
		},
	}
}

func (s *Server) Start(ctx context.Context) error {
	s.router = gin.New()
	s.router.Use(gin.Recovery())
	s.router.Use(middleware.CORS())
	s.router.Use(middleware.Compress())
	s.router.Use(middleware.RateLimit(s.cfg.Server.RateLimitPerMin))
	s.router.Use(middleware.AuditMiddleware(s.auditLogger))

	s.router.GET("/healthz", s.handleHealthz)

	v1 := s.router.Group("/api/v1")
	v1.Use(middleware.Auth(s.cfg.Auth))
	s.registerV1Routes(v1)

	go s.wsHub.Run(ctx)

	addr := fmt.Sprintf("%s:%d", s.cfg.Server.Host, s.cfg.Server.Port)
	srv := &http.Server{
		Addr:         addr,
		Handler:      s.router,
		ReadTimeout:  s.cfg.Server.ReadTimeout,
		WriteTimeout: s.cfg.Server.WriteTimeout,
	}

	log.Info("server", "listening on %s", addr)

	go func() {
		<-ctx.Done()
		srv.Close()
	}()

	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		return err
	}
	return nil
}

func (s *Server) handleHealthz(c *gin.Context) {
	log.Debug("api", "healthz check from %s", c.ClientIP())
	c.JSON(200, gin.H{
		"status":     "ok",
		"version":    buildInfo.Version,
		"build_time": buildInfo.BuildTime,
		"git_commit": buildInfo.GitCommit,
		"uptime":     time.Since(startTime).String(),
	})
}
