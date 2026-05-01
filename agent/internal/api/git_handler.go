package api

import (
	"context"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/magent/agent/internal/gitservice"
	"github.com/magent/agent/internal/log"
	"github.com/magent/agent/internal/project"
	"github.com/magent/agent/internal/provider"
)

type GitHandler struct {
	gitService *gitservice.Service
	projectMgr *project.Manager
	registry   *provider.Registry
}

func NewGitHandler(gitService *gitservice.Service, projectMgr *project.Manager, registry *provider.Registry) *GitHandler {
	return &GitHandler{
		gitService: gitService,
		projectMgr: projectMgr,
		registry:   registry,
	}
}

func (h *GitHandler) Summary(c *gin.Context) {
	projectID := c.Query("project_id")
	project, err := h.projectMgr.Get(c.Request.Context(), projectID)
	if err != nil || project == nil {
		Fail(c, 404, ErrNotFound, "project not found")
		return
	}

	summary, err := h.gitService.GetSummary(c.Request.Context(), projectID, project.Path)
	if err != nil {
		Fail(c, 500, "GIT_ERROR", err.Error())
		return
	}

	OK(c, summary)
}

func (h *GitHandler) Changes(c *gin.Context) {
	projectID := c.Query("project_id")
	baseVersion, _ := strconv.ParseInt(c.DefaultQuery("base_version", "0"), 10, 64)

	project, err := h.projectMgr.Get(c.Request.Context(), projectID)
	if err != nil || project == nil {
		Fail(c, 404, ErrNotFound, "project not found")
		return
	}

	changes, err := h.gitService.GetChanges(c.Request.Context(), projectID, project.Path, baseVersion)
	if err != nil {
		Fail(c, 500, "GIT_ERROR", err.Error())
		return
	}

	OK(c, changes)
}

func (h *GitHandler) FileDiff(c *gin.Context) {
	projectID := c.Query("project_id")
	path := c.Query("path")
	diffHash := c.Query("diff_hash")
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "200"))
	staged := c.Query("staged") == "true"

	project, err := h.projectMgr.Get(c.Request.Context(), projectID)
	if err != nil || project == nil {
		Fail(c, 404, ErrNotFound, "project not found")
		return
	}

	diff, err := h.gitService.GetFileDiff(c.Request.Context(), project.Path, path, diffHash, offset, limit, staged)
	if err != nil {
		Fail(c, 500, "GIT_ERROR", err.Error())
		return
	}

	OK(c, diff)
}

func (h *GitHandler) Stage(c *gin.Context) {
	var req struct {
		ProjectID string   `json:"project_id" binding:"required"`
		Paths     []string `json:"paths" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, 400, "INVALID_REQUEST", err.Error())
		return
	}

	project, err := h.projectMgr.Get(c.Request.Context(), req.ProjectID)
	if err != nil || project == nil {
		Fail(c, 404, ErrNotFound, "project not found")
		return
	}

	log.Debug("git", "stage project=%s paths=%v", req.ProjectID, req.Paths)
	var failed []string
	for _, path := range req.Paths {
		if _, err := h.gitService.Git(c.Request.Context(), project.Path, "add", path); err != nil {
			log.Error("git", "stage failed path=%s: %v", path, err)
			failed = append(failed, path)
		}
	}

	if len(failed) == len(req.Paths) {
		Fail(c, 500, "GIT_ERROR", "all stage operations failed")
		return
	}
	if len(failed) > 0 {
		OK(c, gin.H{"failed": failed})
		return
	}
	OK(c, nil)
}

func (h *GitHandler) Unstage(c *gin.Context) {
	var req struct {
		ProjectID string   `json:"project_id" binding:"required"`
		Paths     []string `json:"paths" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, 400, "INVALID_REQUEST", err.Error())
		return
	}

	project, err := h.projectMgr.Get(c.Request.Context(), req.ProjectID)
	if err != nil || project == nil {
		Fail(c, 404, ErrNotFound, "project not found")
		return
	}

	for _, path := range req.Paths {
		if _, err := h.gitService.Git(c.Request.Context(), project.Path, "reset", "HEAD", "--", path); err != nil {
			log.Error("git", "unstage failed path=%s: %v", path, err)
		}
	}

	OK(c, nil)
}

func (h *GitHandler) Discard(c *gin.Context) {
	var req struct {
		ProjectID string   `json:"project_id" binding:"required"`
		Paths     []string `json:"paths" binding:"required"`
		Staged    bool     `json:"staged"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, 400, "INVALID_REQUEST", err.Error())
		return
	}

	project, err := h.projectMgr.Get(c.Request.Context(), req.ProjectID)
	if err != nil || project == nil {
		Fail(c, 404, ErrNotFound, "project not found")
		return
	}

	for _, path := range req.Paths {
		if req.Staged {
			h.gitService.Git(c.Request.Context(), project.Path, "reset", "HEAD", "--", path)
		}
		if _, err := h.gitService.Git(c.Request.Context(), project.Path, "checkout", "--", path); err != nil {
			Fail(c, 500, "GIT_ERROR", err.Error())
			return
		}
	}

	OK(c, nil)
}

func (h *GitHandler) Commit(c *gin.Context) {
	var req struct {
		ProjectID string `json:"project_id" binding:"required"`
		Message   string `json:"message" binding:"required"`
		All       bool   `json:"all"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, 400, "INVALID_REQUEST", err.Error())
		return
	}

	if strings.TrimSpace(req.Message) == "" {
		Fail(c, 400, "INVALID_REQUEST", "commit message required")
		return
	}

	project, err := h.projectMgr.Get(c.Request.Context(), req.ProjectID)
	if err != nil || project == nil {
		Fail(c, 404, ErrNotFound, "project not found")
		return
	}

	args := []string{"commit", "-m", req.Message}
	if req.All {
		args = append(args, "-a")
	}

	log.Debug("git", "commit project=%s msg=%q all=%v", req.ProjectID, req.Message, req.All)
	out, err := h.gitService.Git(c.Request.Context(), project.Path, args...)
	if err != nil {
		log.Error("git", "commit failed: %s", string(out))
		Fail(c, 500, "GIT_ERROR", string(out))
		return
	}

	log.Info("git", "committed project=%s", req.ProjectID)
	OK(c, gin.H{"output": string(out)})
}

func (h *GitHandler) Push(c *gin.Context) {
	var req struct {
		ProjectID string `json:"project_id" binding:"required"`
		Remote    string `json:"remote"`
		Branch    string `json:"branch"`
		Force     bool   `json:"force"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, 400, "INVALID_REQUEST", err.Error())
		return
	}

	if req.Force && c.GetHeader("X-Confirm-Force") != "true" {
		Fail(c, 400, ErrConfirmRequired, "force push requires confirmation")
		return
	}

	project, err := h.projectMgr.Get(c.Request.Context(), req.ProjectID)
	if err != nil || project == nil {
		Fail(c, 404, ErrNotFound, "project not found")
		return
	}

	remote := req.Remote
	if remote == "" {
		remote = "origin"
	}
	branch := req.Branch
	if branch == "" {
		branch = "HEAD"
	}

	args := []string{"push", remote, branch}
	if req.Force {
		args = append(args, "--force-with-lease")
	}

	log.Info("git", "push project=%s remote=%s branch=%s force=%v", req.ProjectID, remote, branch, req.Force)
	out, err := h.gitService.Git(c.Request.Context(), project.Path, args...)
	if err != nil {
		log.Error("git", "push failed: %s", string(out))
		Fail(c, 500, "GIT_ERROR", string(out))
		return
	}

	log.Info("git", "pushed project=%s", req.ProjectID)
	OK(c, gin.H{"output": string(out)})
}

type GitCommit struct {
	Hash      string    `json:"hash"`
	Author    string    `json:"author"`
	Email     string    `json:"email"`
	Timestamp time.Time `json:"timestamp"`
	Message   string    `json:"message"`
}

func (h *GitHandler) Log(c *gin.Context) {
	projectID := c.Query("project_id")
	limit := c.DefaultQuery("limit", "50")
	offset := c.DefaultQuery("offset", "0")

	project, err := h.projectMgr.Get(c.Request.Context(), projectID)
	if err != nil || project == nil {
		Fail(c, 404, ErrNotFound, "project not found")
		return
	}

	format := "%H|%an|%ae|%at|%s"
	out, _ := h.gitService.Git(c.Request.Context(), project.Path,
		"log", fmt.Sprintf("-%s", limit), fmt.Sprintf("--skip=%s", offset),
		fmt.Sprintf("--format=%s", format))

	var commits []GitCommit
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		parts := strings.SplitN(line, "|", 5)
		if len(parts) == 5 {
			timestamp, _ := strconv.ParseInt(parts[3], 10, 64)
			commits = append(commits, GitCommit{
				Hash:      parts[0],
				Author:    parts[1],
				Email:     parts[2],
				Timestamp: time.Unix(timestamp, 0),
				Message:   parts[4],
			})
		}
	}

	OK(c, commits)
}

type Branch struct {
	Name    string `json:"name"`
	Current bool   `json:"current"`
}

func (h *GitHandler) Branches(c *gin.Context) {
	projectID := c.Query("project_id")

	project, err := h.projectMgr.Get(c.Request.Context(), projectID)
	if err != nil || project == nil {
		Fail(c, 404, ErrNotFound, "project not found")
		return
	}

	out, _ := h.gitService.Git(c.Request.Context(), project.Path, "branch", "-a", "--format=%(refname:short)|%(HEAD)")

	var branches []Branch
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		parts := strings.SplitN(line, "|", 2)
		if len(parts) == 2 {
			branches = append(branches, Branch{
				Name:    parts[0],
				Current: parts[1] == "*",
			})
		}
	}

	OK(c, branches)
}

func (h *GitHandler) CommitFiles(c *gin.Context) {
	projectID := c.Query("project_id")
	hash := c.Query("hash")

	project, err := h.projectMgr.Get(c.Request.Context(), projectID)
	if err != nil || project == nil {
		Fail(c, 404, ErrNotFound, "project not found")
		return
	}

	if hash == "" {
		Fail(c, 400, "INVALID_REQUEST", "hash required")
		return
	}

	out, _ := h.gitService.Git(c.Request.Context(), project.Path,
		"diff-tree", "--root", "--no-commit-id", "-r", "--name-status", hash)

	var files []CommitFile
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		parts := strings.SplitN(line, "\t", 2)
		if len(parts) == 2 {
			files = append(files, CommitFile{
				Status: parts[0],
				Path:   parts[1],
			})
		}
	}

	OK(c, gin.H{"hash": hash, "files": files})
}

func (h *GitHandler) CommitFileDiff(c *gin.Context) {
	projectID := c.Query("project_id")
	hash := c.Query("hash")
	filePath := c.Query("path")

	project, err := h.projectMgr.Get(c.Request.Context(), projectID)
	if err != nil || project == nil {
		Fail(c, 404, ErrNotFound, "project not found")
		return
	}

	if hash == "" || filePath == "" {
		Fail(c, 400, "INVALID_REQUEST", "hash and path required")
		return
	}

	// Use git show to get the diff for this file in this commit
	out, _ := h.gitService.Git(c.Request.Context(), project.Path,
		"show", "--format=", "--patch", hash, "--", filePath)

	// Fallback: diff against empty tree for initial commits
	if strings.TrimSpace(string(out)) == "" {
		out, _ = h.gitService.Git(c.Request.Context(), project.Path,
			"diff", fmt.Sprintf("4b825dc642cb6eb9a060e54bf899d69f3e452344..%s", hash), "--", filePath)
	}

	OK(c, gin.H{
		"hash":    hash,
		"path":    filePath,
		"content": string(out),
	})
}

type CommitFile struct {
	Status string `json:"status"`
	Path   string `json:"path"`
}

func (h *GitHandler) SuggestCommitMessage(c *gin.Context) {
	var req struct {
		ProjectID string `json:"project_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, 400, "INVALID_REQUEST", err.Error())
		return
	}

	project, err := h.projectMgr.Get(c.Request.Context(), req.ProjectID)
	if err != nil || project == nil {
		Fail(c, 404, ErrNotFound, "project not found")
		return
	}

	// Check staged changes
	nameStatus, _ := h.gitService.Git(c.Request.Context(), project.Path,
		"diff", "--staged", "--name-status")
	if strings.TrimSpace(string(nameStatus)) == "" {
		Fail(c, 400, "NO_CHANGES", "No staged changes. Stage files first.")
		return
	}

	// Get diff stat (truncated)
	stat, _ := h.gitService.Git(c.Request.Context(), project.Path,
		"diff", "--staged", "--stat")

	// Get partial diff (first 3000 chars)
	diffOut, _ := h.gitService.Git(c.Request.Context(), project.Path,
		"diff", "--staged", "--unified=3")
	diffContent := string(diffOut)
	if len(diffContent) > 3000 {
		diffContent = diffContent[:3000] + "\n... (truncated)"
	}

	prompt := fmt.Sprintf(`Based on the following git diff, generate a commit message.

Files:
%s

Summary:
%s

Changes:
%s

Requirements:
- Use conventional commits format (e.g. feat:, fix:, refactor:, docs:, chore:)
- One line summary only
- No longer than 72 characters
- Output ONLY the commit message, nothing else`, nameStatus, stat, diffContent)

	log.Debug("git", "suggest commit message: prompt len=%d", len(prompt))

	// Get codex provider
	p, err := h.registry.Get("codex")
	if err != nil {
		Fail(c, 503, "NO_PROVIDER", "No AI provider available")
		return
	}

	ctx, cancel := context.WithTimeout(c.Request.Context(), 30*time.Second)
	defer cancel()

	// Create a one-shot session
	sess, err := p.CreateSession(ctx, provider.CreateSessionRequest{
		ProjectID:      req.ProjectID,
		Workdir:        project.Path,
		Effort:         "low",
		ApprovalPolicy: "never",
		SandboxMode:    "read-only",
		Prompt:         prompt,
	})
	if err != nil {
		log.Error("git", "suggest: create session failed: %v", err)
		Fail(c, 500, "AI_FAILED", err.Error())
		return
	}

	defer func() {
		p.StopSession(context.Background(), sess.ID)
	}()

	// Wait for the AI response
	events := p.Subscribe(sess.ID)
	defer p.Unsubscribe(sess.ID)

	var message string
	timeout := time.After(25 * time.Second)

	for {
		select {
		case event, ok := <-events:
			if !ok {
				if message != "" {
					OK(c, gin.H{"message": cleanCommitMessage(message)})
					return
				}
				Fail(c, 500, "AI_FAILED", "No response from AI")
				return
			}
			switch event.Type {
			case "session.message":
				if payload, ok := event.Payload.(map[string]any); ok {
					if text, ok := payload["text"].(string); ok {
						message += text
					}
					if content, ok := payload["content"].(string); ok {
						message += content
					}
				}
			case "session.turn_completed":
				if message != "" {
					OK(c, gin.H{"message": cleanCommitMessage(message)})
					return
				}
			case "session.error":
				if payload, ok := event.Payload.(map[string]any); ok {
					errMsg, _ := payload["error"].(string)
					if message != "" {
						OK(c, gin.H{"message": cleanCommitMessage(message)})
						return
					}
					Fail(c, 500, "AI_FAILED", errMsg)
					return
				}
			case "session.exited":
				if message != "" {
					OK(c, gin.H{"message": cleanCommitMessage(message)})
					return
				}
				Fail(c, 500, "AI_FAILED", "Session exited without response")
				return
			}
		case <-timeout:
			if message != "" {
				OK(c, gin.H{"message": cleanCommitMessage(message)})
				return
			}
			Fail(c, 504, "AI_TIMEOUT", "AI response timeout")
			return
		}
	}
}

func cleanCommitMessage(raw string) string {
	msg := strings.TrimSpace(raw)
	// Remove markdown code fences
	msg = strings.TrimPrefix(msg, "```")
	msg = strings.TrimSuffix(msg, "```")
	msg = strings.TrimSpace(msg)
	// Remove leading "commit message:" or similar prefixes
	lower := strings.ToLower(msg)
	for _, prefix := range []string{"commit message:", "commit:", "message:"} {
		if strings.HasPrefix(lower, prefix) {
			msg = strings.TrimSpace(msg[len(prefix):])
			lower = strings.ToLower(msg)
		}
	}
	// Remove surrounding quotes
	if len(msg) >= 2 && ((msg[0] == '"' && msg[len(msg)-1] == '"') || (msg[0] == '\'' && msg[len(msg)-1] == '\'')) {
		msg = msg[1 : len(msg)-1]
	}
	// Take first line only
	if idx := strings.IndexByte(msg, '\n'); idx > 0 {
		msg = msg[:idx]
	}
	return strings.TrimSpace(msg)
}
