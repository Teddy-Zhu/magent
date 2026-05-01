package api

import (
	"github.com/gin-gonic/gin"
	"github.com/magent/agent/internal/log"
	"github.com/magent/agent/internal/ws"
)

func (s *Server) registerRoutes(api *gin.RouterGroup) {
	// Agent
	api.GET("/agent/info", s.handleAgentInfo)

	// Providers
	api.GET("/providers", s.providerHandler.List)
	api.GET("/providers/:name", s.providerHandler.Get)
	api.GET("/providers/:name/capabilities", s.providerHandler.Capabilities)
	api.GET("/providers/:name/config", s.providerHandler.Config)

	// Projects
	api.GET("/projects", s.handleListProjects)
	api.POST("/projects", s.handleCreateProject)
	api.GET("/projects/:id", s.handleGetProject)
	api.PUT("/projects/:id", s.handleUpdateProject)
	api.DELETE("/projects/:id", s.handleDeleteProject)

	// Sessions
	api.POST("/sessions", s.sessionHandler.Create)
	api.GET("/sessions", s.sessionHandler.List)
	api.GET("/sessions/:id", s.sessionHandler.Get)
	api.POST("/sessions/:id/input", s.sessionHandler.SendInput)
	api.POST("/sessions/:id/interrupt", s.sessionHandler.Interrupt)
	api.POST("/sessions/:id/stop", s.sessionHandler.Stop)
	api.POST("/sessions/:id/fork", s.sessionHandler.Fork)
	api.POST("/sessions/:id/compact", s.sessionHandler.Compact)
	api.POST("/sessions/:id/rollback", s.sessionHandler.Rollback)
	api.GET("/sessions/:id/events", s.sessionHandler.GetEvents)

	// Git
	api.GET("/git/summary", s.gitHandler.Summary)
	api.GET("/git/changes", s.gitHandler.Changes)
	api.GET("/git/diff/file", s.gitHandler.FileDiff)
	api.POST("/git/stage", s.gitHandler.Stage)
	api.POST("/git/unstage", s.gitHandler.Unstage)
	api.POST("/git/discard", s.gitHandler.Discard)
	api.POST("/git/commit", s.gitHandler.Commit)
	api.POST("/git/commit/suggest", s.gitHandler.SuggestCommitMessage)
	api.POST("/git/push", s.gitHandler.Push)
	api.GET("/git/log", s.gitHandler.Log)
	api.GET("/git/branches", s.gitHandler.Branches)
	api.GET("/git/commit/files", s.gitHandler.CommitFiles)
	api.GET("/git/commit/file-diff", s.gitHandler.CommitFileDiff)

	// Files
	api.GET("/files/list", s.fileHandler.ListDir)
	api.GET("/files/read", s.fileHandler.ReadFile)
	api.GET("/files/raw", s.fileHandler.RawFile)

	// Directory Browser (for project creation)
	api.GET("/dirs/list", s.handleListDirs)
	api.GET("/dirs/home", s.handleGetHomeDir)

	// Sync
	api.GET("/sync/check", s.syncHandler.Check)
	api.GET("/sync/bootstrap", s.syncHandler.Bootstrap)

	// WebSocket
	api.GET("/ws", s.handleWebSocket)
}

func (s *Server) handleAgentInfo(c *gin.Context) {
	OK(c, gin.H{
		"version":      version,
		"uptime":       s.wsHub.ClientCount(),
		"connected":    s.wsHub.ClientCount(),
		"capabilities": []string{"codex", "git", "file"},
	})
}

func (s *Server) handleWebSocket(c *gin.Context) {
	tokenName, _ := c.Get("token_name")

	conn, err := s.upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Error("ws", "upgrade failed: %v", err)
		return
	}

	client := ws.NewClient(s.wsHub, conn, tokenName.(string))
	s.wsHub.AddClient(client)
	log.Info("ws", "client connected token=%s ip=%s total=%d", tokenName, c.ClientIP(), s.wsHub.ClientCount())

	go client.WritePump()
	go client.ReadPump()
}
