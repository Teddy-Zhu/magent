package middleware

import (
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/Teddy-Zhu/magent/agent/internal/config"
	"github.com/Teddy-Zhu/magent/agent/internal/log"
)

func Auth(cfg config.AuthConfig) gin.HandlerFunc {
	return func(c *gin.Context) {
		token := c.GetHeader("Authorization")
		if token == "" {
			token = c.Query("token")
		}
		token = strings.TrimPrefix(token, "Bearer ")

		for _, t := range cfg.Tokens {
			if t.Token == token {
				c.Set("token_name", t.Name)
				c.Set("permissions", t.Permissions)
				log.Debug("auth", "token=%s ip=%s path=%s", t.Name, c.ClientIP(), c.Request.URL.Path)
				c.Next()
				return
			}
		}

		log.Warn("auth", "unauthorized ip=%s path=%s", c.ClientIP(), c.Request.URL.Path)
		c.AbortWithStatusJSON(401, gin.H{"error": "unauthorized"})
	}
}
