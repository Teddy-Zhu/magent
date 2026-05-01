package api

import (
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/magent/agent/internal/log"
	"github.com/magent/agent/internal/project"
	"github.com/magent/agent/internal/provider"
	"github.com/magent/agent/internal/session"
)

type SessionHandler struct {
	manager    *session.Manager
	projectMgr *project.Manager
}

func NewSessionHandler(manager *session.Manager, projectMgr *project.Manager) *SessionHandler {
	return &SessionHandler{manager: manager, projectMgr: projectMgr}
}

func (h *SessionHandler) Create(c *gin.Context) {
	var req session.CreateSessionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, 400, ErrInvalidRequest, err.Error())
		return
	}

	// Fill workdir from project if not provided
	if req.Workdir == "" && req.ProjectID != "" {
		proj, err := h.projectMgr.Get(c.Request.Context(), req.ProjectID)
		if err == nil && proj != nil {
			req.Workdir = proj.Path
		}
	}

	log.Info("session", "create provider=%s project=%s model=%s workdir=%s", req.ProviderName(), req.ProjectID, req.Model, req.Workdir)
	sess, err := h.manager.CreateSession(c.Request.Context(), req)
	if err != nil {
		log.Error("session", "create failed: %v", err)
		Fail(c, 500, ErrInvalidRequest, err.Error())
		return
	}
	log.Info("session", "created id=%s provider=%s", sess.ID, sess.ProviderID)
	OK(c, sess)
}

func (h *SessionHandler) Get(c *gin.Context) {
	id := c.Param("id")
	log.Debug("session", "get id=%s", id)
	sess, err := h.manager.GetSession(c.Request.Context(), id)
	if err != nil {
		log.Error("session", "get id=%s error: %v", id, err)
		Fail(c, 500, ErrInternalError, err.Error())
		return
	}
	if sess == nil {
		log.Debug("session", "get id=%s not found", id)
		Fail(c, 404, ErrNotFound, "session not found")
		return
	}
	log.Debug("session", "get id=%s status=%s provider=%s", id, sess.Status, sess.ProviderID)
	OK(c, sess)
}

func (h *SessionHandler) List(c *gin.Context) {
	projectID := c.Query("project_id")
	if projectID == "" {
		Fail(c, 400, ErrInvalidRequest, "project_id required")
		return
	}

	// Get project to determine provider and workdir
	var providerName, workdir string
	proj, err := h.projectMgr.Get(c.Request.Context(), projectID)
	if err == nil && proj != nil {
		providerName = proj.DefaultProvider
		workdir = proj.Path
	}

	sessions, err := h.manager.ListSessions(c.Request.Context(), projectID, providerName, workdir)
	if err != nil {
		Fail(c, 500, ErrInternalError, err.Error())
		return
	}
	OK(c, sessions)
}

func (h *SessionHandler) ListChanges(c *gin.Context) {
	projectID := c.Param("id")
	if projectID == "" {
		Fail(c, 400, ErrInvalidRequest, "project id required")
		return
	}

	var providerName, workdir string
	proj, err := h.projectMgr.Get(c.Request.Context(), projectID)
	if err == nil && proj != nil {
		providerName = proj.DefaultProvider
		workdir = proj.Path
	}

	sessions, err := h.manager.ListSessions(c.Request.Context(), projectID, providerName, workdir)
	if err != nil {
		Fail(c, 500, ErrInternalError, err.Error())
		return
	}

	OK(c, gin.H{
		"project_id": projectID,
		"upserts":    sessions,
		"deletes":    []string{},
		"has_more":   false,
	})
}

func (h *SessionHandler) Resume(c *gin.Context) {
	id := c.Param("id")
	log.Info("session", "resume id=%s", id)
	if err := h.manager.ResumeSession(c.Request.Context(), id); err != nil {
		log.Error("session", "resume failed id=%s: %v", id, err)
		if isSessionNotFound(err) {
			Fail(c, 404, "SESSION_NOT_FOUND", err.Error())
		} else {
			Fail(c, 500, ErrInternalError, err.Error())
		}
		return
	}
	OK(c, nil)
}

func (h *SessionHandler) SendInput(c *gin.Context) {
	id := c.Param("id")
	var req struct {
		Input string               `json:"input" binding:"required"`
		Items []provider.InputItem `json:"items"`
		Mode  string               `json:"mode"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, 400, ErrInvalidRequest, err.Error())
		return
	}
	req.Mode = provider.NormalizeSendInputMode(req.Mode)
	if !provider.IsSendInputMode(req.Mode) {
		Fail(c, 400, ErrInvalidRequest, "invalid send input mode")
		return
	}

	log.Debug("session", "input id=%s len=%d mode=%s", id, len(req.Input), req.Mode)
	if err := h.manager.SendInput(c.Request.Context(), id, provider.SendInputRequest{
		Input: req.Input,
		Items: req.Items,
		Mode:  req.Mode,
	}); err != nil {
		log.Error("session", "send input failed id=%s: %v", id, err)
		// Return 404 if session not found so client can handle it
		if isSessionNotFound(err) {
			Fail(c, 404, "SESSION_NOT_FOUND", err.Error())
		} else {
			Fail(c, 500, ErrInternalError, err.Error())
		}
		return
	}
	OK(c, nil)
}

func (h *SessionHandler) Interrupt(c *gin.Context) {
	id := c.Param("id")
	log.Info("session", "interrupt id=%s", id)
	if err := h.manager.InterruptSession(c.Request.Context(), id); err != nil {
		log.Warn("session", "interrupt failed id=%s: %v", id, err)
		// Not a server error — session may be stopped or not in memory
		Fail(c, 409, "SESSION_NOT_RUNNING", err.Error())
		return
	}
	OK(c, nil)
}

func (h *SessionHandler) Stop(c *gin.Context) {
	id := c.Param("id")
	log.Info("session", "stop id=%s", id)
	if err := h.manager.StopSession(c.Request.Context(), id); err != nil {
		log.Error("session", "stop failed id=%s: %v", id, err)
		Fail(c, 500, ErrInternalError, err.Error())
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
		Fail(c, 500, ErrInternalError, err.Error())
		return
	}
	log.Info("session", "forked %s -> %s", id, sess.ID)
	OK(c, sess)
}

func (h *SessionHandler) GetEvents(c *gin.Context) {
	id := c.Param("id")
	cursor := c.Query("cursor")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "500"))

	page, err := h.manager.GetEvents(c.Request.Context(), id, cursor, limit)
	if err != nil {
		log.Error("session", "getEvents id=%s error: %v", id, err)
		Fail(c, 500, ErrInternalError, err.Error())
		return
	}

	log.Debug("session", "getEvents id=%s cursor=%s returned=%d", id, cursor, len(page.Events))
	OK(c, gin.H{
		"session_id": page.SessionID,
		"cursor":     page.Cursor,
		"has_more":   page.HasMore,
		"events":     eventsToAPIEvents(page.Events, cursor),
	})
}

func (h *SessionHandler) GetItems(c *gin.Context) {
	id := c.Param("id")
	cursor := c.Query("cursor")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "200"))

	page, err := h.manager.GetItems(c.Request.Context(), id, cursor, limit)
	if err != nil {
		log.Error("session", "getItems id=%s error: %v", id, err)
		Fail(c, 500, ErrInternalError, err.Error())
		return
	}

	OK(c, gin.H{
		"session_id": id,
		"cursor":     page.Cursor,
		"has_more":   page.HasMore,
		"items":      itemsToAPIItems(page.Items),
	})
}

func eventsToAPIEvents(events []provider.ProviderEvent, cursor string) []gin.H {
	items := make([]gin.H, 0, len(events))
	for i, event := range events {
		eventCursor := event.Cursor
		if eventCursor == "" {
			eventCursor = strconv.Itoa(i + 1)
		}
		items = append(items, gin.H{
			"cursor":     eventCursor,
			"type":       event.Type,
			"item_id":    event.ItemID,
			"turn_id":    event.TurnID,
			"data":       event.Payload,
			"created_at": event.Timestamp.Unix(),
		})
	}
	return items
}

func itemsToAPIItems(items []provider.SessionItem) []gin.H {
	result := make([]gin.H, 0, len(items))
	for _, item := range items {
		result = append(result, gin.H{
			"cursor":     item.Cursor,
			"item_id":    item.ItemID,
			"turn_id":    item.TurnID,
			"index":      item.Index,
			"type":       item.Type,
			"status":     item.Status,
			"role":       item.Role,
			"summary":    item.Summary,
			"content":    item.Content,
			"created_at": item.CreatedAt.Unix(),
			"updated_at": item.UpdatedAt.Unix(),
		})
	}
	return result
}

func (h *SessionHandler) Compact(c *gin.Context) {
	id := c.Param("id")
	if err := h.manager.CompactSession(c.Request.Context(), id); err != nil {
		Fail(c, 500, ErrInternalError, err.Error())
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
		Fail(c, 400, ErrInvalidRequest, err.Error())
		return
	}
	if req.Turns <= 0 {
		req.Turns = 1
	}
	if err := h.manager.RollbackSession(c.Request.Context(), id, req.Turns); err != nil {
		Fail(c, 500, ErrInternalError, err.Error())
		return
	}
	OK(c, nil)
}

func (h *SessionHandler) ResolveApproval(c *gin.Context) {
	id := c.Param("id")
	approvalID := c.Param("approval_id")
	var req struct {
		Decision any    `json:"decision"`
		Action   string `json:"action"`
		Message  string `json:"message"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, 400, ErrInvalidRequest, err.Error())
		return
	}
	var rawDecision any
	action := ""
	switch decision := req.Decision.(type) {
	case string:
		action = decision
	case map[string]any:
		rawDecision = decision
		for key := range decision {
			action = key
			break
		}
	}
	if action == "" {
		action = req.Action
	}
	if rawDecision == nil {
		rawDecision = req.Decision
	}
	if action == "" {
		Fail(c, 400, ErrInvalidRequest, "decision is required")
		return
	}
	if err := h.manager.ResolveApproval(c.Request.Context(), id, approvalID, provider.ApprovalDecision{
		Action:  action,
		Message: req.Message,
		Raw:     rawDecision,
	}); err != nil {
		if isSessionNotFound(err) {
			Fail(c, 404, ErrNotFound, err.Error())
		} else {
			Fail(c, 500, ErrInternalError, err.Error())
		}
		return
	}
	OK(c, nil)
}

func isSessionNotFound(err error) bool {
	msg := err.Error()
	return strings.Contains(msg, "not found") || strings.Contains(msg, "not active")
}
