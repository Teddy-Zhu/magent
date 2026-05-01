package api

import (
	"net/http"

	"github.com/gin-gonic/gin"
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
)

func OK(c *gin.Context, data any) {
	c.JSON(http.StatusOK, gin.H{"ok": true, "data": data})
}

func Fail(c *gin.Context, httpCode int, errCode, msg string) {
	c.JSON(httpCode, gin.H{
		"ok":    false,
		"error": gin.H{"code": errCode, "message": msg},
	})
}

func NotModified(c *gin.Context) {
	c.Status(http.StatusNotModified)
}
