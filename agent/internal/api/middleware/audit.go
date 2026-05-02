package middleware

import (
	"fmt"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/Teddy-Zhu/magent/agent/internal/storage"
)

type AuditLogger struct {
	db *storage.SQLite
}

func NewAuditLogger(db *storage.SQLite) *AuditLogger {
	return &AuditLogger{db: db}
}

func (l *AuditLogger) Log(sessionID, action, target, detail, result string) {
	l.db.DB().Exec(
		`INSERT INTO audit_log (session_id, action, target, detail, result, created_at) VALUES (?, ?, ?, ?, ?, ?)`,
		sessionID, action, target, detail, result, time.Now().Unix(),
	)
}

func AuditMiddleware(logger *AuditLogger) gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()

		tokenName, _ := c.Get("token_name")
		sessionID := ""
		if sid, ok := c.Get("session_id"); ok {
			sessionID = fmt.Sprintf("%v", sid)
		}

		logger.Log(
			sessionID,
			c.Request.Method,
			c.Request.URL.Path,
			fmt.Sprintf("status=%d token=%v ip=%s", c.Writer.Status(), tokenName, c.ClientIP()),
			fmt.Sprintf("duration=%s", time.Since(start)),
		)
	}
}
