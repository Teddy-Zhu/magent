package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

type tokenBucket struct {
	tokens    float64
	maxTokens float64
	refillRate float64
	lastRefill time.Time
	mu        sync.Mutex
}

func newTokenBucket(maxTokens float64, refillRate float64) *tokenBucket {
	return &tokenBucket{
		tokens:     maxTokens,
		maxTokens:  maxTokens,
		refillRate: refillRate,
		lastRefill: time.Now(),
	}
}

func (b *tokenBucket) allow() bool {
	b.mu.Lock()
	defer b.mu.Unlock()

	now := time.Now()
	elapsed := now.Sub(b.lastRefill).Seconds()
	b.tokens += elapsed * b.refillRate
	if b.tokens > b.maxTokens {
		b.tokens = b.maxTokens
	}
	b.lastRefill = now

	if b.tokens >= 1 {
		b.tokens--
		return true
	}
	return false
}

func RateLimit(requestsPerMinute int) gin.HandlerFunc {
	buckets := make(map[string]*tokenBucket)
	var mu sync.Mutex
	refillRate := float64(requestsPerMinute) / 60.0

	return func(c *gin.Context) {
		key := c.ClientIP()

		mu.Lock()
		b, ok := buckets[key]
		if !ok {
			b = newTokenBucket(float64(requestsPerMinute), refillRate)
			buckets[key] = b
		}
		mu.Unlock()

		if !b.allow() {
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"error": "rate limit exceeded",
				"code":  "RATE_LIMITED",
			})
			return
		}
		c.Next()
	}
}
