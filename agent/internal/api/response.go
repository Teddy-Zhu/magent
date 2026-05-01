package api

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/magent/agent/internal/project"
	"github.com/magent/agent/internal/provider"
)

// 错误码常量
const (
	ErrUnauthorized     = "UNAUTHORIZED"
	ErrNotFound         = "NOT_FOUND"
	ErrPathTraversal    = "PATH_TRAVERSAL"
	ErrProviderNotFound = "PROVIDER_NOT_FOUND"
	ErrSessionNotFound  = "SESSION_NOT_FOUND"
	ErrGitError         = "GIT_ERROR"
	ErrRateLimited      = "RATE_LIMITED"
	ErrConfirmRequired  = "CONFIRM_REQUIRED"
	ErrInvalidRequest   = "INVALID_REQUEST"
	ErrInternalError    = "INTERNAL_ERROR"
	ErrFileError        = "FILE_ERROR"
)

func OK(c *gin.Context, data any) {
	c.JSON(http.StatusOK, gin.H{"data": data})
}

func Fail(c *gin.Context, httpCode int, errCode, msg string) {
	c.JSON(httpCode, gin.H{
		"error": gin.H{"code": errCode, "message": msg},
	})
}

func NotModified(c *gin.Context) {
	c.Status(http.StatusNotModified)
}

// requireQuery validates that a required query parameter is non-empty.
// Returns the value and true if valid, or sends a 400 response and returns "", false.
func requireQuery(c *gin.Context, key string) (string, bool) {
	v := c.Query(key)
	if v == "" {
		Fail(c, 400, ErrInvalidRequest, key+" is required")
		return "", false
	}
	return v, true
}

// getProject retrieves a project by ID, sending appropriate error responses.
// Returns the project and true if found, or sends 404/500 and returns nil, false.
func getProject(c *gin.Context, mgr *project.Manager, projectID string) (*project.Project, bool) {
	p, err := mgr.Get(c.Request.Context(), projectID)
	if err != nil {
		Fail(c, 500, ErrInternalError, err.Error())
		return nil, false
	}
	if p == nil {
		Fail(c, 404, ErrNotFound, "project not found")
		return nil, false
	}
	return p, true
}

// requireProject is a convenience: validates project_id query param and fetches the project.
func requireProject(c *gin.Context, mgr *project.Manager) (*project.Project, bool) {
	projectID, ok := requireQuery(c, "project_id")
	if !ok {
		return nil, false
	}
	return getProject(c, mgr, projectID)
}

// getProvider retrieves a provider by name, sending appropriate error responses.
func getProvider(c *gin.Context, registry *provider.Registry, name string) (provider.Provider, bool) {
	p, err := registry.Get(name)
	if err != nil {
		Fail(c, 404, ErrProviderNotFound, err.Error())
		return nil, false
	}
	return p, true
}
