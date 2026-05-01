package api

import (
	"context"
	"time"

	"github.com/magent/agent/internal/gitservice"
	"github.com/magent/agent/internal/log"
	"github.com/magent/agent/internal/project"
)

func (s *Server) startGitWatchers(ctx context.Context) {
	projects, err := s.projectMgr.List(ctx)
	if err != nil {
		log.Warn("git", "list projects for watcher failed: %v", err)
		return
	}
	for _, project := range projects {
		s.startGitWatcher(project)
	}
}

func (s *Server) startGitWatcher(project project.Project) {
	if project.ID == "" || project.Path == "" {
		return
	}
	if err := s.gitService.StartWatcher(project.ID, project.Path, func(summary *gitservice.GitSummary) {
		s.broadcastGitInvalidated(summary)
	}); err != nil {
		log.Warn("git", "watcher start failed project=%s path=%s err=%v", project.ID, project.Path, err)
	}
}

func (s *Server) restartGitWatcher(project project.Project) {
	s.gitService.StopWatcher(project.ID)
	s.startGitWatcher(project)
}

func (s *Server) stopGitWatcher(projectID string) {
	s.gitService.StopWatcher(projectID)
}

func (s *Server) broadcastGitInvalidated(summary *gitservice.GitSummary) {
	s.wsHub.Broadcast(map[string]any{
		"type":            "git.invalidated",
		"project_id":      summary.ProjectID,
		"version":         summary.Version,
		"head":            summary.Head,
		"branch":          summary.Branch,
		"worktree_hash":   summary.WorktreeHash,
		"index_hash":      summary.IndexHash,
		"changed_count":   summary.ChangedCount,
		"staged_count":    summary.StagedCount,
		"unstaged_count":  summary.UnstagedCount,
		"untracked_count": summary.UntrackedCount,
		"created_at":      time.Now().UTC().Format(time.RFC3339Nano),
	})
}
