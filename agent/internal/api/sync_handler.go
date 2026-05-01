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
	c.JSON(200, result)
}

func (h *SyncHandler) Bootstrap(c *gin.Context) {
	localHash := c.Query("local_hash")
	data, status, err := h.configService.Bootstrap(c.Request.Context(), localHash)
	if status == 304 {
		c.Status(304)
		return
	}
	if err != nil {
		c.JSON(500, gin.H{"error": err.Error()})
		return
	}
	c.JSON(200, data)
}
