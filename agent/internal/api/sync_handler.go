package api

import (
	"github.com/gin-gonic/gin"
	"github.com/magent/agent/internal/sync"
)

type SyncHandler struct {
	configService *sync.ConfigService
}

func NewSyncHandler(configService *sync.ConfigService) *SyncHandler {
	return &SyncHandler{configService: configService}
}

func (h *SyncHandler) Check(c *gin.Context) {
	result := h.configService.Check()
	OK(c, result)
}

func (h *SyncHandler) Bootstrap(c *gin.Context) {
	localHash := c.GetHeader("If-None-Match")
	data, status, err := h.configService.Bootstrap(c.Request.Context(), localHash)
	if status == 304 {
		NotModified(c)
		return
	}
	if err != nil {
		Fail(c, 500, ErrInternalError, err.Error())
		return
	}
	if check := h.configService.Check(); check.ConfigHash != "" {
		c.Header("ETag", check.ConfigHash)
	}
	OK(c, data)
}

func (h *SyncHandler) RefreshBootstrap(c *gin.Context) {
	if err := h.configService.Refresh(c.Request.Context()); err != nil {
		Fail(c, 500, ErrInternalError, err.Error())
		return
	}
	data, _, err := h.configService.Bootstrap(c.Request.Context(), "")
	if err != nil {
		Fail(c, 500, ErrInternalError, err.Error())
		return
	}
	if check := h.configService.Check(); check.ConfigHash != "" {
		c.Header("ETag", check.ConfigHash)
	}
	OK(c, data)
}
