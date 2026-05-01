package api

import (
	"github.com/gin-gonic/gin"
	"github.com/magent/agent/internal/provider"
)

type ProviderHandler struct {
	registry *provider.Registry
}

func NewProviderHandler(registry *provider.Registry) *ProviderHandler {
	return &ProviderHandler{registry: registry}
}

func (h *ProviderHandler) List(c *gin.Context) {
	infos := h.registry.List()
	OK(c, infos)
}

func (h *ProviderHandler) Get(c *gin.Context) {
	name := c.Param("name")
	p, err := h.registry.Get(name)
	if err != nil {
		Fail(c, 404, ErrNotFound, err.Error())
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
	p, err := h.registry.Get(name)
	if err != nil {
		Fail(c, 404, ErrNotFound, err.Error())
		return
	}
	OK(c, p.Capabilities())
}

func (h *ProviderHandler) Config(c *gin.Context) {
	name := c.Param("name")
	p, err := h.registry.Get(name)
	if err != nil {
		Fail(c, 404, ErrNotFound, err.Error())
		return
	}
	OK(c, p.Config())
}
