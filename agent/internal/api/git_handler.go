package api

import (
	"context"
	"fmt"
	"io"
	"strconv"
	"strings"
	"time"

	"github.com/Teddy-Zhu/magent/agent/internal/gitservice"
	"github.com/Teddy-Zhu/magent/agent/internal/log"
	"github.com/Teddy-Zhu/magent/agent/internal/project"
	"github.com/Teddy-Zhu/magent/agent/internal/provider"
	"github.com/gin-gonic/gin"
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

func (h *GitHandler) SummaryForProject(c *gin.Context) {
	project, ok := getProject(c, h.projectMgr, c.Param("id"))
	if !ok {
		return
	}

	summary, err := h.gitService.GetSummary(c.Request.Context(), project.ID, project.Path)
	if err != nil {
		Fail(c, 500, ErrGitError, err.Error())
		return
	}
	if c.GetHeader("If-None-Match") == strconv.FormatInt(summary.Version, 10) {
		NotModified(c)
		return
	}
	c.Header("ETag", strconv.FormatInt(summary.Version, 10))
	OK(c, summary)
}

func (h *GitHandler) ChangesForProject(c *gin.Context) {
	project, ok := getProject(c, h.projectMgr, c.Param("id"))
	if !ok {
		return
	}
	baseVersion, _ := strconv.ParseInt(c.DefaultQuery("base_version", "0"), 10, 64)

	changes, err := h.gitService.GetChanges(c.Request.Context(), project.ID, project.Path, baseVersion)
	if err != nil {
		Fail(c, 500, ErrGitError, err.Error())
		return
	}
	if changes.Version == baseVersion && len(changes.Files) == 0 {
		NotModified(c)
		return
	}
	c.Header("ETag", strconv.FormatInt(changes.Version, 10))
	OK(c, changes)
}

func (h *GitHandler) FileDiffForProject(c *gin.Context) {
	project, ok := getProject(c, h.projectMgr, c.Param("id"))
	if !ok {
		return
	}
	path := c.Query("path")
	diffHash := c.Query("diff_hash")
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "200"))
	staged := c.Query("staged") == "true"

	diff, err := h.gitService.GetFileDiff(c.Request.Context(), project.ID, project.Path, path, diffHash, offset, limit, staged)
	if err != nil {
		Fail(c, 409, ErrGitError, err.Error())
		return
	}

	OK(c, diff)
}

func (h *GitHandler) StageForProject(c *gin.Context) {
	var req struct {
		Paths []string `json:"paths" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, 400, ErrInvalidRequest, err.Error())
		return
	}

	project, ok := getProject(c, h.projectMgr, c.Param("id"))
	if !ok {
		return
	}

	log.Debug("git", "stage project=%s paths=%v", project.ID, req.Paths)
	var failed []string
	for _, path := range req.Paths {
		if _, err := h.gitService.Git(c.Request.Context(), project.Path, "add", path); err != nil {
			log.Error("git", "stage failed path=%s: %v", path, err)
			failed = append(failed, path)
		}
	}

	if len(failed) == len(req.Paths) {
		Fail(c, 500, ErrGitError, "all stage operations failed")
		return
	}
	if len(failed) > 0 {
		OK(c, gin.H{"failed": failed})
		return
	}
	OK(c, nil)
}

func (h *GitHandler) UnstageForProject(c *gin.Context) {
	var req struct {
		Paths []string `json:"paths" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, 400, ErrInvalidRequest, err.Error())
		return
	}

	project, ok := getProject(c, h.projectMgr, c.Param("id"))
	if !ok {
		return
	}

	for _, path := range req.Paths {
		if _, err := h.gitService.Git(c.Request.Context(), project.Path, "reset", "HEAD", "--", path); err != nil {
			log.Error("git", "unstage failed path=%s: %v", path, err)
		}
	}

	OK(c, nil)
}

func (h *GitHandler) DiscardForProject(c *gin.Context) {
	var req struct {
		Paths   []string `json:"paths" binding:"required"`
		Staged  bool     `json:"staged"`
		Confirm bool     `json:"confirm"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, 400, ErrInvalidRequest, err.Error())
		return
	}
	if !req.Confirm {
		Fail(c, 400, ErrConfirmRequired, "discard requires confirmation")
		return
	}

	project, ok := getProject(c, h.projectMgr, c.Param("id"))
	if !ok {
		return
	}

	for _, path := range req.Paths {
		if strings.TrimSpace(path) == "" {
			continue
		}
		if isUntrackedPath(c.Request.Context(), h.gitService, project.Path, path) {
			if _, err := h.gitService.Git(c.Request.Context(), project.Path, "clean", "-fd", "--", path); err != nil {
				Fail(c, 500, ErrGitError, err.Error())
				return
			}
			continue
		}
		if _, err := h.gitService.Git(c.Request.Context(), project.Path, "restore", "--staged", "--worktree", "--", path); err != nil {
			Fail(c, 500, ErrGitError, err.Error())
			return
		}
	}

	OK(c, nil)
}

func isUntrackedPath(ctx context.Context, gitService *gitservice.Service, projectPath, path string) bool {
	out, _ := gitService.Git(ctx, projectPath, "ls-files", "--others", "--exclude-standard", "-z", "--", path)
	for _, item := range strings.Split(strings.TrimRight(string(out), "\x00"), "\x00") {
		if item == path {
			return true
		}
	}
	return false
}

func (h *GitHandler) CommitForProject(c *gin.Context) {
	var req struct {
		Message string `json:"message" binding:"required"`
		All     bool   `json:"all"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, 400, ErrInvalidRequest, err.Error())
		return
	}

	if strings.TrimSpace(req.Message) == "" {
		Fail(c, 400, ErrInvalidRequest, "commit message required")
		return
	}

	project, ok := getProject(c, h.projectMgr, c.Param("id"))
	if !ok {
		return
	}

	args := []string{"commit", "-m", req.Message}
	if req.All {
		args = append(args, "-a")
	}

	log.Debug("git", "commit project=%s msg=%q all=%v", project.ID, req.Message, req.All)
	out, err := h.gitService.Git(c.Request.Context(), project.Path, args...)
	if err != nil {
		log.Error("git", "commit failed: %s", string(out))
		Fail(c, 500, ErrGitError, string(out))
		return
	}

	log.Info("git", "committed project=%s", project.ID)
	OK(c, gin.H{"output": string(out)})
}

func (h *GitHandler) PushForProject(c *gin.Context) {
	var req struct {
		Remote       string `json:"remote"`
		Branch       string `json:"branch"`
		Force        bool   `json:"force"`
		ConfirmForce bool   `json:"confirm_force"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		Fail(c, 400, ErrInvalidRequest, err.Error())
		return
	}

	if req.Force && !req.ConfirmForce {
		Fail(c, 400, ErrConfirmRequired, "force push requires confirmation")
		return
	}

	project, ok := getProject(c, h.projectMgr, c.Param("id"))
	if !ok {
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

	log.Info("git", "push project=%s remote=%s branch=%s force=%v", project.ID, remote, branch, req.Force)
	out, err := h.gitService.Git(c.Request.Context(), project.Path, args...)
	if err != nil {
		log.Error("git", "push failed: %s", string(out))
		Fail(c, 500, ErrGitError, string(out))
		return
	}

	log.Info("git", "pushed project=%s", project.ID)
	OK(c, gin.H{"output": string(out)})
}

func (h *GitHandler) PullForProject(c *gin.Context) {
	var req struct {
		Remote string `json:"remote"`
		Branch string `json:"branch"`
		Rebase bool   `json:"rebase"`
	}
	if err := c.ShouldBindJSON(&req); err != nil && err != io.EOF {
		Fail(c, 400, ErrInvalidRequest, err.Error())
		return
	}

	project, ok := getProject(c, h.projectMgr, c.Param("id"))
	if !ok {
		return
	}

	args := []string{"pull"}
	if req.Rebase {
		args = append(args, "--rebase")
	}
	if req.Remote != "" {
		args = append(args, req.Remote)
		if req.Branch != "" {
			args = append(args, req.Branch)
		}
	}

	log.Info("git", "pull project=%s remote=%s branch=%s rebase=%v", project.ID, req.Remote, req.Branch, req.Rebase)
	out, err := h.gitService.Git(c.Request.Context(), project.Path, args...)
	if err != nil {
		log.Error("git", "pull failed: %s", string(out))
		Fail(c, 500, ErrGitError, string(out))
		return
	}

	OK(c, gin.H{"output": string(out)})
}

type GitCommit struct {
	Hash      string    `json:"hash"`
	Author    string    `json:"author"`
	Email     string    `json:"email"`
	Timestamp time.Time `json:"timestamp"`
	Message   string    `json:"message"`
}

func (h *GitHandler) LogForProject(c *gin.Context) {
	project, ok := getProject(c, h.projectMgr, c.Param("id"))
	if !ok {
		return
	}
	limit := c.DefaultQuery("limit", "50")
	offset := c.DefaultQuery("offset", "0")

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

func (h *GitHandler) BranchesForProject(c *gin.Context) {
	project, ok := getProject(c, h.projectMgr, c.Param("id"))
	if !ok {
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

func (h *GitHandler) CommitFilesForProject(c *gin.Context) {
	project, ok := getProject(c, h.projectMgr, c.Param("id"))
	if !ok {
		return
	}
	hash, ok := requireQuery(c, "hash")
	if !ok {
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

func (h *GitHandler) CommitFileDiffForProject(c *gin.Context) {
	project, ok := getProject(c, h.projectMgr, c.Param("id"))
	if !ok {
		return
	}
	hash, ok := requireQuery(c, "hash")
	if !ok {
		return
	}
	filePath, ok := requireQuery(c, "path")
	if !ok {
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

func (h *GitHandler) SuggestCommitMessageForProject(c *gin.Context) {
	project, ok := getProject(c, h.projectMgr, c.Param("id"))
	if !ok {
		return
	}
	var req struct {
		ProviderID string `json:"provider_id"`
		Model      string `json:"model"`
		Effort     string `json:"effort"`
	}
	if c.Request.Body != nil && c.Request.ContentLength != 0 {
		if err := c.ShouldBindJSON(&req); err != nil && err != io.EOF {
			Fail(c, 400, ErrInvalidRequest, err.Error())
			return
		}
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

	providerName := strings.TrimSpace(req.ProviderID)
	if providerName == "" {
		providerName = "codex"
	}
	model := strings.TrimSpace(req.Model)
	effort := strings.TrimSpace(req.Effort)
	if effort == "" {
		effort = "low"
	}

	log.Debug("git", "suggest commit message: provider=%s model=%s effort=%s prompt len=%d", providerName, model, effort, len(prompt))

	p, ok := getProvider(c, h.registry, providerName)
	if !ok {
		return
	}

	cfg := p.Config()

	ctx, cancel := context.WithTimeout(c.Request.Context(), 30*time.Second)
	defer cancel()

	// Create a one-shot session
	providerReq := provider.CreateSessionRequest{
		ProjectID:      project.ID,
		Purpose:        string(provider.SessionPurposeAICommit),
		Workdir:        project.Path,
		Model:          model,
		Effort:         effort,
		ApprovalPolicy: string(provider.ApprovalPolicyNever),
		SandboxMode:    string(provider.SandboxModeWorkspaceWrite),
		Prompt:         prompt,
	}
	providerReq.ApplyDefaults(cfg)
	if err := providerReq.Validate(); err != nil {
		Fail(c, 400, ErrInvalidRequest, err.Error())
		return
	}
	sess, err := p.CreateSession(ctx, providerReq)
	if err != nil {
		log.Error("git", "suggest: create session failed: %v", err)
		Fail(c, 500, "AI_FAILED", err.Error())
		return
	}

	defer func() {
		log.Info("git", "suggest: stopping session %s", sess.ID)
		if err := p.StopSession(context.Background(), sess.ID); err != nil {
			log.Warn("git", "suggest: stop session error: %v", err)
		}
	}()

	// Wait for the AI response
	events := p.Subscribe(sess.ID)
	defer p.Unsubscribe(sess.ID)

	var message string
	timeout := time.After(20 * time.Second)
	var quietTimer *time.Timer
	var quiet <-chan time.Time
	defer func() {
		if quietTimer != nil {
			quietTimer.Stop()
		}
	}()
	resetQuiet := func() {
		if quietTimer != nil {
			quietTimer.Stop()
		}
		quietTimer = time.NewTimer(1500 * time.Millisecond)
		quiet = quietTimer.C
	}

	for {
		select {
		case event, ok := <-events:
			if !ok {
				if message != "" {
					OK(c, gin.H{"message": cleanCommitMessage(message)})
					return
				}
				log.Warn("git", "suggest: events channel closed without response")
				OK(c, gin.H{"message": "", "error": "AI session ended without response"})
				return
			}
			switch event.Type {
			case string(provider.EventMessage), string(provider.EventMessageDelta), string(provider.EventOutput):
				if payload, ok := event.Payload.(map[string]any); ok {
					message = mergeCommitMessageEvent(message, event.Type, payload)
					if event.Type == string(provider.EventOutput) && message != "" {
						resetQuiet()
					}
				}
			case string(provider.EventTurnCompleted):
				log.Info("git", "suggest: turn completed, message len=%d", len(message))
				if message != "" {
					OK(c, gin.H{"message": cleanCommitMessage(message)})
					return
				}
			case string(provider.EventError):
				if payload, ok := event.Payload.(map[string]any); ok {
					errMsg, _ := payload["error"].(string)
					log.Warn("git", "suggest: session error: %s payload=%v", errMsg, payload)
					if message != "" {
						OK(c, gin.H{"message": cleanCommitMessage(message)})
						return
					}
					OK(c, gin.H{"message": "", "error": errMsg})
					return
				}
			case string(provider.EventTurnFailed):
				if payload, ok := event.Payload.(map[string]any); ok {
					log.Warn("git", "suggest: turn failed payload=%v", payload)
				}
				if message != "" {
					OK(c, gin.H{"message": cleanCommitMessage(message)})
					return
				}
				OK(c, gin.H{"message": "", "error": "AI turn failed"})
				return
			case string(provider.EventExited):
				if message != "" {
					OK(c, gin.H{"message": cleanCommitMessage(message)})
					return
				}
				OK(c, gin.H{"message": "", "error": "AI session exited unexpectedly"})
				return
			}
		case <-timeout:
			if message != "" {
				OK(c, gin.H{"message": cleanCommitMessage(message)})
				return
			}
			log.Warn("git", "suggest: timeout waiting for AI response")
			OK(c, gin.H{"message": "", "error": "AI response timeout"})
			return
		case <-quiet:
			quiet = nil
			if message != "" {
				OK(c, gin.H{"message": cleanCommitMessage(message)})
				return
			}
		}
	}
}

func mergeCommitMessageEvent(current, eventType string, payload map[string]any) string {
	switch eventType {
	case string(provider.EventMessage):
		if final := commitMessageFromPayload(payload); final != "" {
			return final
		}
	case string(provider.EventMessageDelta):
		if delta, ok := payload["delta"].(string); ok {
			return current + delta
		}
	case string(provider.EventOutput):
		if output := commitMessageFromPayload(payload); output != "" {
			return current + output
		}
	}
	return current
}

func commitMessageFromPayload(payload map[string]any) string {
	for _, key := range []string{"text", "content"} {
		if value, ok := payload[key].(string); ok && value != "" {
			return value
		}
	}
	return ""
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
