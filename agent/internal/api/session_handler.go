package api

import (
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/magent/agent/internal/log"
	"github.com/magent/agent/internal/session"
)

type SessionHandler struct {
	manager *session.Manager
}

func NewSessionHandler(manager *session.Manager) *SessionHandler {
	return &SessionHandler{manager: manager}
}

func (h *SessionHandler) Create(c *gin.Context) {
	var req session.CreateSessionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, 400, "INVALID_REQUEST", err.Error())
		return
	}

	log.Info("session", "create provider=%s project=%s model=%s", req.Provider, req.ProjectID, req.Model)
	sess, err := h.manager.CreateSession(c.Request.Context(), req)
	if err != nil {
		log.Error("session", "create failed: %v", err)
		Fail(c, 500, "CREATE_FAILED", err.Error())
		return
	}
	log.Info("session", "created id=%s provider=%s", sess.ID, sess.ProviderID)
	OK(c, sess)
}

func (h *SessionHandler) Get(c *gin.Context) {
	id := c.Param("id")
	sess, err := h.manager.GetSession(id)
	if err != nil {
		Fail(c, 500, "INTERNAL_ERROR", err.Error())
		return
	}
	if sess == nil {
		Fail(c, 404, ErrNotFound, "session not found")
		return
	}
	OK(c, sess)
}

func (h *SessionHandler) List(c *gin.Context) {
	projectID := c.Query("project_id")
	if projectID == "" {
		Fail(c, 400, "INVALID_REQUEST", "project_id required")
		return
	}

	sessions, err := h.manager.ListSessions(projectID)
	if err != nil {
		Fail(c, 500, "INTERNAL_ERROR", err.Error())
		return
	}
	OK(c, sessions)
}

func (h *SessionHandler) SendInput(c *gin.Context) {
	id := c.Param("id")
	var req struct {
		Input string `json:"input" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, 400, "INVALID_REQUEST", err.Error())
		return
	}

	log.Debug("session", "input id=%s len=%d", id, len(req.Input))
	if err := h.manager.SendInput(c.Request.Context(), id, req.Input); err != nil {
		log.Error("session", "send input failed id=%s: %v", id, err)
		Fail(c, 500, "SEND_FAILED", err.Error())
		return
	}
	OK(c, nil)
}

func (h *SessionHandler) Interrupt(c *gin.Context) {
	id := c.Param("id")
	if err := h.manager.InterruptSession(c.Request.Context(), id); err != nil {
		Fail(c, 500, "INTERRUPT_FAILED", err.Error())
		return
	}
	OK(c, nil)
}

func (h *SessionHandler) Stop(c *gin.Context) {
	id := c.Param("id")
	log.Info("session", "stop id=%s", id)
	if err := h.manager.StopSession(c.Request.Context(), id); err != nil {
		log.Error("session", "stop failed id=%s: %v", id, err)
		Fail(c, 500, "STOP_FAILED", err.Error())
		return
	}
	log.Info("session", "stopped id=%s", id)
	OK(c, nil)
}

func (h *SessionHandler) Fork(c *gin.Context) {
	id := c.Param("id")
	log.Info("session", "fork id=%s", id)
	sess, err := h.manager.ForkSession(c.Request.Context(), id)
	if err != nil {
		log.Error("session", "fork failed id=%s: %v", id, err)
		Fail(c, 500, "FORK_FAILED", err.Error())
		return
	}
	log.Info("session", "forked %s -> %s", id, sess.ID)
	OK(c, sess)
}

func (h *SessionHandler) GetEvents(c *gin.Context) {
	id := c.Param("id")
	afterSeqStr := c.DefaultQuery("after_seq", "0")
	limitStr := c.DefaultQuery("limit", "100")

	afterSeq, _ := strconv.ParseInt(afterSeqStr, 10, 64)
	limit, _ := strconv.Atoi(limitStr)
	if limit <= 0 || limit > 1000 {
		limit = 100
	}

	events, err := h.manager.GetEventsAfterSeq(id, afterSeq, limit)
	if err != nil {
		Fail(c, 500, "INTERNAL_ERROR", err.Error())
		return
	}
	OK(c, events)
}

func (h *SessionHandler) Compact(c *gin.Context) {
	id := c.Param("id")
	if err := h.manager.CompactSession(c.Request.Context(), id); err != nil {
		Fail(c, 500, "COMPACT_FAILED", err.Error())
		return
	}
	OK(c, nil)
}

func (h *SessionHandler) Rollback(c *gin.Context) {
	id := c.Param("id")
	var req struct {
		Turns int `json:"turns"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, 400, "INVALID_REQUEST", err.Error())
		return
	}
	if req.Turns <= 0 {
		req.Turns = 1
	}
	if err := h.manager.RollbackSession(c.Request.Context(), id, req.Turns); err != nil {
		Fail(c, 500, "ROLLBACK_FAILED", err.Error())
		return
	}
	OK(c, nil)
}
