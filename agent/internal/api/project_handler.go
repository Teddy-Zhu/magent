package api

import (
	"github.com/gin-gonic/gin"
)

func (s *Server) handleListProjects(c *gin.Context) {
	projects, err := s.projectMgr.List(c.Request.Context())
	if err != nil {
		Fail(c, 500, ErrInternalError, err.Error())
		return
	}
	OK(c, projects)
}

func (s *Server) handleCreateProject(c *gin.Context) {
	var req struct {
		Name string `json:"name" binding:"required"`
		Path string `json:"path" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, 400, ErrInvalidRequest, err.Error())
		return
	}

	project, err := s.projectMgr.Create(c.Request.Context(), req.Name, req.Path)
	if err != nil {
		Fail(c, 400, ErrInvalidRequest, err.Error())
		return
	}
	s.startGitWatcher(*project)
	s.syncHandler.configService.MarkDirty()
	OK(c, project)
}

func (s *Server) handleGetProject(c *gin.Context) {
	project, ok := getProject(c, s.projectMgr, c.Param("id"))
	if !ok {
		return
	}
	OK(c, project)
}

func (s *Server) handleUpdateProject(c *gin.Context) {
	project, ok := getProject(c, s.projectMgr, c.Param("id"))
	if !ok {
		return
	}

	var req struct {
		Name            string `json:"name"`
		Path            string `json:"path"`
		DefaultProvider string `json:"default_provider"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, 400, ErrInvalidRequest, err.Error())
		return
	}

	if req.Name != "" {
		project.Name = req.Name
	}
	if req.Path != "" {
		project.Path = req.Path
	}
	if req.DefaultProvider != "" {
		project.DefaultProvider = req.DefaultProvider
	}

	if err := s.projectMgr.Update(c.Request.Context(), project); err != nil {
		Fail(c, 500, ErrInternalError, err.Error())
		return
	}
	s.restartGitWatcher(*project)
	s.syncHandler.configService.MarkDirty()
	OK(c, project)
}

func (s *Server) handleDeleteProject(c *gin.Context) {
	project, ok := getProject(c, s.projectMgr, c.Param("id"))
	if !ok {
		return
	}
	if err := s.projectMgr.Delete(c.Request.Context(), project.ID); err != nil {
		Fail(c, 500, ErrInternalError, err.Error())
		return
	}
	s.stopGitWatcher(project.ID)
	s.syncHandler.configService.MarkDirty()
	OK(c, nil)
}
