package api

import (
	"github.com/gin-gonic/gin"
)

func (s *Server) handleListProjects(c *gin.Context) {
	projects, err := s.projectMgr.List(c.Request.Context())
	if err != nil {
		Fail(c, 500, "INTERNAL_ERROR", err.Error())
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
		Fail(c, 400, "INVALID_REQUEST", err.Error())
		return
	}

	project, err := s.projectMgr.Create(c.Request.Context(), req.Name, req.Path)
	if err != nil {
		Fail(c, 400, "CREATE_FAILED", err.Error())
		return
	}
	OK(c, project)
}

func (s *Server) handleGetProject(c *gin.Context) {
	id := c.Param("id")
	project, err := s.projectMgr.Get(c.Request.Context(), id)
	if err != nil {
		Fail(c, 500, "INTERNAL_ERROR", err.Error())
		return
	}
	if project == nil {
		Fail(c, 404, ErrNotFound, "project not found")
		return
	}
	OK(c, project)
}

func (s *Server) handleUpdateProject(c *gin.Context) {
	id := c.Param("id")
	project, err := s.projectMgr.Get(c.Request.Context(), id)
	if err != nil {
		Fail(c, 500, "INTERNAL_ERROR", err.Error())
		return
	}
	if project == nil {
		Fail(c, 404, ErrNotFound, "project not found")
		return
	}

	var req struct {
		Name            string `json:"name"`
		Path            string `json:"path"`
		DefaultProvider string `json:"default_provider"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, 400, "INVALID_REQUEST", err.Error())
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
		Fail(c, 500, "UPDATE_FAILED", err.Error())
		return
	}
	OK(c, project)
}

func (s *Server) handleDeleteProject(c *gin.Context) {
	id := c.Param("id")
	if err := s.projectMgr.Delete(c.Request.Context(), id); err != nil {
		Fail(c, 500, "DELETE_FAILED", err.Error())
		return
	}
	OK(c, nil)
}
