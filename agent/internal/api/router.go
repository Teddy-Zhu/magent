package api

import (
	"github.com/Teddy-Zhu/magent/agent/internal/log"
	"github.com/Teddy-Zhu/magent/agent/internal/ws"
	"github.com/gin-gonic/gin"
)

func (s *Server) registerV1Routes(api *gin.RouterGroup) {
	api.GET("/agent/info", s.handleAgentInfo)
	api.GET("/bootstrap", s.syncHandler.Bootstrap)
	api.POST("/bootstrap/refresh", s.syncHandler.RefreshBootstrap)

	api.GET("/providers", s.providerHandler.List)
	api.GET("/providers/:name", s.providerHandler.Get)
	api.GET("/providers/:name/capabilities", s.providerHandler.Capabilities)
	api.GET("/providers/:name/config", s.providerHandler.Config)
	api.GET("/providers/:name/threads", s.providerHandler.Threads)

	api.GET("/projects", s.handleListProjects)
	api.POST("/projects", s.handleCreateProject)
	api.GET("/projects/:id", s.handleGetProject)
	api.PUT("/projects/:id", s.handleUpdateProject)
	api.DELETE("/projects/:id", s.handleDeleteProject)
	api.GET("/projects/:id/sessions/changes", s.sessionHandler.ListChanges)
	api.GET("/projects/:id/git/summary", s.gitHandler.SummaryForProject)
	api.GET("/projects/:id/git/changes", s.gitHandler.ChangesForProject)
	api.GET("/projects/:id/git/diff/file", s.gitHandler.FileDiffForProject)
	api.POST("/projects/:id/git/stage", s.gitHandler.StageForProject)
	api.POST("/projects/:id/git/unstage", s.gitHandler.UnstageForProject)
	api.POST("/projects/:id/git/discard", s.gitHandler.DiscardForProject)
	api.POST("/projects/:id/git/commit", s.gitHandler.CommitForProject)
	api.POST("/projects/:id/git/commit/suggest", s.gitHandler.SuggestCommitMessageForProject)
	api.POST("/projects/:id/git/pull", s.gitHandler.PullForProject)
	api.POST("/projects/:id/git/push", s.gitHandler.PushForProject)
	api.GET("/projects/:id/git/log", s.gitHandler.LogForProject)
	api.GET("/projects/:id/git/branches", s.gitHandler.BranchesForProject)
	api.GET("/projects/:id/git/commit/files", s.gitHandler.CommitFilesForProject)
	api.GET("/projects/:id/git/commit/file-diff", s.gitHandler.CommitFileDiffForProject)
	api.GET("/projects/:id/files/dir", s.fileHandler.ListDirForProject)
	api.GET("/projects/:id/files/content", s.fileHandler.ReadFileForProject)
	api.GET("/projects/:id/files/blob", s.fileHandler.RawFileForProject)
	api.GET("/dirs/list", s.handleListDirs)
	api.GET("/dirs/home", s.handleGetHomeDir)

	api.POST("/sessions", s.sessionHandler.Create)
	api.GET("/sessions", s.sessionHandler.List)
	api.GET("/sessions/:id", s.sessionHandler.Get)
	api.DELETE("/sessions/:id", s.sessionHandler.Delete)
	api.POST("/sessions/:id/archive", s.sessionHandler.Archive)
	api.POST("/sessions/:id/unarchive", s.sessionHandler.Unarchive)
	api.POST("/sessions/:id/resume", s.sessionHandler.Resume)
	api.POST("/sessions/:id/input", s.sessionHandler.SendInput)
	api.POST("/sessions/:id/interrupt", s.sessionHandler.Interrupt)
	api.POST("/sessions/:id/stop", s.sessionHandler.Stop)
	api.POST("/sessions/:id/fork", s.sessionHandler.Fork)
	api.POST("/sessions/:id/compact", s.sessionHandler.Compact)
	api.POST("/sessions/:id/rollback", s.sessionHandler.Rollback)
	api.GET("/sessions/:id/events", s.sessionHandler.GetEvents)
	api.GET("/sessions/:id/items", s.sessionHandler.GetItems)
	api.GET("/sessions/:id/items/changes", s.sessionHandler.GetItemChanges)
	api.POST("/sessions/:id/approvals/:approval_id", s.sessionHandler.ResolveApproval)

	api.GET("/ws", s.handleWebSocket)
}

func (s *Server) handleAgentInfo(c *gin.Context) {
	OK(c, gin.H{
		"version":      buildInfo.Version,
		"build_time":   buildInfo.BuildTime,
		"git_commit":   buildInfo.GitCommit,
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
