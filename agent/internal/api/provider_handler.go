package api

import (
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/magent/agent/internal/log"
	"github.com/magent/agent/internal/project"
	"github.com/magent/agent/internal/provider"
	"github.com/magent/agent/internal/providers/codex"
)

type ProviderHandler struct {
	registry   *provider.Registry
	projectMgr *project.Manager
}

func NewProviderHandler(registry *provider.Registry, projectMgr *project.Manager) *ProviderHandler {
	return &ProviderHandler{registry: registry, projectMgr: projectMgr}
}

func (h *ProviderHandler) List(c *gin.Context) {
	infos := h.registry.List()
	OK(c, infos)
}

func (h *ProviderHandler) Get(c *gin.Context) {
	name := c.Param("name")
	p, ok := getProvider(c, h.registry, name)
	if !ok {
		return
	}

	info, err := p.Detect(c.Request.Context())
	if err != nil {
		OK(c, gin.H{
			"name":   p.Name(),
			"status": "unavailable",
			"error":  err.Error(),
		})
		return
	}
	OK(c, info)
}

func (h *ProviderHandler) Capabilities(c *gin.Context) {
	name := c.Param("name")
	p, ok := getProvider(c, h.registry, name)
	if !ok {
		return
	}
	OK(c, p.Capabilities())
}

func (h *ProviderHandler) Config(c *gin.Context) {
	name := c.Param("name")
	p, ok := getProvider(c, h.registry, name)
	if !ok {
		return
	}
	OK(c, p.Config())
}

func (h *ProviderHandler) Threads(c *gin.Context) {
	name := c.Param("name")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))

	p, ok := getProvider(c, h.registry, name)
	if !ok {
		return
	}

	// Only codex provider supports thread listing
	cp, ok := p.(*codex.CodexProvider)
	if !ok {
		Fail(c, 400, ErrInvalidRequest, "provider does not support thread listing")
		return
	}

	var cwd string
	projectID := c.Query("project_id")
	if projectID != "" {
		if proj, err := h.projectMgr.Get(c.Request.Context(), projectID); err == nil && proj != nil {
			cwd = proj.Path
		}
	}

	log.Debug("api", "listing threads provider=%s cwd=%s limit=%d", name, cwd, limit)
	threads, err := cp.ListThreadInfos(c.Request.Context(), cwd, limit)
	if err != nil {
		log.Error("api", "list threads failed: %v", err)
		Fail(c, 500, ErrProviderNotFound, err.Error())
		return
	}

	OK(c, threads)
}
