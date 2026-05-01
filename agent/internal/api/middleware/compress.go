package middleware

import (
	"compress/gzip"
	"io"
	"strings"
	"sync"

	"github.com/gin-gonic/gin"
)

var gzipPool = sync.Pool{
	New: func() any {
		w, _ := gzip.NewWriterLevel(nil, gzip.DefaultCompression)
		return w
	},
}

type gzipWriter struct {
	gin.ResponseWriter
	writer io.Writer
}

func (w *gzipWriter) Write(b []byte) (int, error) {
	return w.writer.Write(b)
}

func Compress() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Skip WebSocket upgrades - gorilla/websocket handles its own compression
		if strings.Contains(c.GetHeader("Connection"), "Upgrade") {
			c.Next()
			return
		}

		encoding := c.GetHeader("Accept-Encoding")
		if strings.Contains(encoding, "gzip") {
			gz := gzipPool.Get().(*gzip.Writer)
			gz.Reset(c.Writer)
			defer func() {
				gz.Close()
				gzipPool.Put(gz)
			}()

			c.Header("Content-Encoding", "gzip")
			c.Header("Vary", "Accept-Encoding")
			c.Writer = &gzipWriter{ResponseWriter: c.Writer, writer: gz}
		}

		c.Next()
	}
}
