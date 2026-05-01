package api

import (
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/gin-gonic/gin"
)

type DirEntry struct {
	Name  string `json:"name"`
	Path  string `json:"path"`
	IsDir bool   `json:"is_dir"`
}

func (s *Server) handleListDirs(c *gin.Context) {
	path := c.DefaultQuery("path", "")

	if path == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			Fail(c, 500, "INTERNAL_ERROR", err.Error())
			return
		}
		path = home
	}

	cleaned := filepath.Clean(path)
	if strings.Contains(cleaned, "..") {
		Fail(c, 400, "INVALID_PATH", "path traversal not allowed")
		return
	}

	info, err := os.Stat(cleaned)
	if err != nil {
		Fail(c, 404, "NOT_FOUND", "path not found")
		return
	}
	if !info.IsDir() {
		Fail(c, 400, "NOT_DIR", "path is not a directory")
		return
	}

	entries, err := os.ReadDir(cleaned)
	if err != nil {
		Fail(c, 500, "READ_ERROR", err.Error())
		return
	}

	var dirs []DirEntry
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		if strings.HasPrefix(entry.Name(), ".") {
			continue
		}
		dirs = append(dirs, DirEntry{
			Name:  entry.Name(),
			Path:  filepath.Join(cleaned, entry.Name()),
			IsDir: true,
		})
	}

	sort.Slice(dirs, func(i, j int) bool {
		return strings.ToLower(dirs[i].Name) < strings.ToLower(dirs[j].Name)
	})

	OK(c, gin.H{
		"path":     cleaned,
		"parent":   filepath.Dir(cleaned),
		"entries":  dirs,
	})
}

func (s *Server) handleGetHomeDir(c *gin.Context) {
	home, err := os.UserHomeDir()
	if err != nil {
		Fail(c, 500, "INTERNAL_ERROR", err.Error())
		return
	}
	OK(c, gin.H{"path": home})
}
