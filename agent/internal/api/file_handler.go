package api

import (
	"encoding/base64"
	"mime"
	"os"
	"path/filepath"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/magent/agent/internal/fileservice"
	"github.com/magent/agent/internal/project"
)

type FileHandler struct {
	fileService *fileservice.Service
	projectMgr  *project.Manager
}

func NewFileHandler(fileService *fileservice.Service, projectMgr *project.Manager) *FileHandler {
	return &FileHandler{
		fileService: fileService,
		projectMgr:  projectMgr,
	}
}

func (h *FileHandler) ListDir(c *gin.Context) {
	projectID := c.Query("project_id")
	path := c.DefaultQuery("path", ".")
	knownHash := c.Query("known_hash")

	project, err := h.projectMgr.Get(c.Request.Context(), projectID)
	if err != nil || project == nil {
		Fail(c, 404, ErrNotFound, "project not found")
		return
	}

	result, status, err := h.fileService.ListDir(c.Request.Context(), projectID, project.Path, path, knownHash)
	if status == 304 {
		NotModified(c)
		return
	}
	if err != nil {
		Fail(c, status, "FILE_ERROR", err.Error())
		return
	}

	OK(c, result)
}

func (h *FileHandler) ReadFile(c *gin.Context) {
	projectID := c.Query("project_id")
	path := c.Query("path")
	knownHash := c.Query("known_hash")
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "1000"))

	project, err := h.projectMgr.Get(c.Request.Context(), projectID)
	if err != nil || project == nil {
		Fail(c, 404, ErrNotFound, "project not found")
		return
	}

	result, status, err := h.fileService.ReadFile(c.Request.Context(), project.Path, path, knownHash, offset, limit)
	if status == 304 {
		NotModified(c)
		return
	}
	if err != nil {
		Fail(c, status, "FILE_ERROR", err.Error())
		return
	}

	OK(c, result)
}

func (h *FileHandler) RawFile(c *gin.Context) {
	projectID := c.Query("project_id")
	path := c.Query("path")

	project, err := h.projectMgr.Get(c.Request.Context(), projectID)
	if err != nil || project == nil {
		Fail(c, 404, ErrNotFound, "project not found")
		return
	}

	fullPath := filepath.Join(project.Path, path)
	ext := filepath.Ext(fullPath)
	mimeType := mime.TypeByExtension(ext)
	if mimeType == "" {
		mimeType = "application/octet-stream"
	}

	data, err := os.ReadFile(fullPath)
	if err != nil {
		Fail(c, 500, "FILE_ERROR", err.Error())
		return
	}

	// For images and binary files, return base64
	if isBinaryFile(ext) {
		OK(c, gin.H{
			"path":     path,
			"mime":     mimeType,
			"encoding": "base64",
			"data":     base64.StdEncoding.EncodeToString(data),
			"size":     len(data),
		})
		return
	}

	// For text files, return as string
	OK(c, gin.H{
		"path":     path,
		"mime":     mimeType,
		"encoding": "text",
		"data":     string(data),
		"size":     len(data),
	})
}

func isBinaryFile(ext string) bool {
	switch ext {
	case ".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp", ".ico", ".svg",
		".pdf", ".zip", ".tar", ".gz", ".bz2", ".xz", ".7z", ".rar",
		".exe", ".dll", ".so", ".dylib", ".bin", ".dat",
		".mp3", ".mp4", ".avi", ".mov", ".mkv", ".wav", ".flac",
		".ttf", ".otf", ".woff", ".woff2", ".eot":
		return true
	default:
		return false
	}
}
