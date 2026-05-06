package api

import (
	"encoding/base64"
	"mime"
	"path/filepath"
	"strconv"

	"github.com/Teddy-Zhu/magent/agent/internal/fileservice"
	"github.com/Teddy-Zhu/magent/agent/internal/project"
	"github.com/gin-gonic/gin"
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

func (h *FileHandler) ListDirForProject(c *gin.Context) {
	project, ok := getProject(c, h.projectMgr, c.Param("id"))
	if !ok {
		return
	}
	path := c.DefaultQuery("path", ".")
	knownHash := c.Query("known_hash")
	if knownHash == "" {
		knownHash = c.GetHeader("If-None-Match")
	}

	result, status, err := h.fileService.ListDir(c.Request.Context(), project.ID, project.Path, path, knownHash)
	if status == 304 {
		NotModified(c)
		return
	}
	if err != nil {
		Fail(c, status, ErrFileError, err.Error())
		return
	}
	c.Header("ETag", result.Hash)
	OK(c, result)
}

func (h *FileHandler) ReadFileForProject(c *gin.Context) {
	project, ok := getProject(c, h.projectMgr, c.Param("id"))
	if !ok {
		return
	}
	path := c.Query("path")
	knownHash := c.Query("known_hash")
	if knownHash == "" {
		knownHash = c.GetHeader("If-None-Match")
	}
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "1000"))

	result, status, err := h.fileService.ReadFile(c.Request.Context(), project.Path, path, knownHash, offset, limit)
	if status == 304 {
		NotModified(c)
		return
	}
	if err != nil {
		Fail(c, status, ErrFileError, err.Error())
		return
	}
	c.Header("ETag", result.Hash)
	OK(c, result)
}

func (h *FileHandler) RawFileForProject(c *gin.Context) {
	project, ok := getProject(c, h.projectMgr, c.Param("id"))
	if !ok {
		return
	}
	h.rawFile(c, project.Path)
}

func (h *FileHandler) rawFile(c *gin.Context, projectPath string) {
	path := c.Query("path")
	knownHash := c.Query("known_hash")
	if knownHash == "" {
		knownHash = c.GetHeader("If-None-Match")
	}
	offset, _ := strconv.ParseInt(c.DefaultQuery("offset", "0"), 10, 64)
	limit, _ := strconv.ParseInt(c.DefaultQuery("limit", "0"), 10, 64)

	result, status, err := h.fileService.ReadRawFile(c.Request.Context(), projectPath, path, knownHash, offset, limit)
	if status == 304 {
		NotModified(c)
		return
	}
	if err != nil {
		Fail(c, status, ErrFileError, err.Error())
		return
	}
	c.Header("ETag", result.Hash)

	ext := filepath.Ext(path)
	mimeType := mime.TypeByExtension(ext)
	if mimeType == "" {
		mimeType = "application/octet-stream"
	}

	if isBinaryFile(ext) {
		OK(c, gin.H{
			"path":      path,
			"hash":      result.Hash,
			"mime":      mimeType,
			"encoding":  "base64",
			"data":      base64.StdEncoding.EncodeToString(result.Data),
			"size":      result.Size,
			"offset":    result.Offset,
			"limit":     result.Limit,
			"truncated": result.Truncated,
		})
		return
	}

	OK(c, gin.H{
		"path":      path,
		"hash":      result.Hash,
		"mime":      mimeType,
		"encoding":  "text",
		"data":      string(result.Data),
		"size":      result.Size,
		"offset":    result.Offset,
		"limit":     result.Limit,
		"truncated": result.Truncated,
	})
}

func isBinaryFile(ext string) bool {
	return fileservice.IsKnownBinaryExtension(ext)
}
