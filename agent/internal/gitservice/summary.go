package gitservice

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

type GitSummary struct {
	ProjectID      string `json:"project_id"`
	Head           string `json:"head"`
	Branch         string `json:"branch"`
	Upstream       string `json:"upstream"`
	Ahead          int    `json:"ahead"`
	Behind         int    `json:"behind"`
	WorktreeHash   string `json:"worktree_hash"`
	IndexHash      string `json:"index_hash"`
	ChangedCount   int    `json:"changed_count"`
	StagedCount    int    `json:"staged_count"`
	UnstagedCount  int    `json:"unstaged_count"`
	UntrackedCount int    `json:"untracked_count"`
	Version        int64  `json:"version"`
}

func (s *Service) GetSummary(ctx context.Context, projectID, projectPath string) (*GitSummary, error) {
	headOut, _ := s.Git(ctx, projectPath, "rev-parse", "HEAD")
	head := strings.TrimSpace(string(headOut))

	branchOut, _ := s.Git(ctx, projectPath, "rev-parse", "--abbrev-ref", "HEAD")
	branch := strings.TrimSpace(string(branchOut))

	upstreamOut, _ := s.Git(ctx, projectPath, "rev-parse", "--abbrev-ref", "@{upstream}")
	upstream := strings.TrimSpace(string(upstreamOut))

	ahead, behind := 0, 0
	if upstream != "" {
		revList, _ := s.Git(ctx, projectPath, "rev-list", "--left-right", "--count", "HEAD...@{upstream}")
		fmt.Sscanf(strings.TrimSpace(string(revList)), "%d\t%d", &ahead, &behind)
	}

	statusOut, _ := s.Git(ctx, projectPath, "status", "--porcelain=v1")
	staged, unstaged, untracked := parseStatusCounts(string(statusOut))

	worktreeHash := s.computeWorktreeHash(ctx, projectPath)
	indexHash := s.computeIndexHash(ctx, projectPath)

	version := s.getOrBumpVersion(ctx, projectID, head, worktreeHash, indexHash)

	return &GitSummary{
		ProjectID:      projectID,
		Head:           head,
		Branch:         branch,
		Upstream:       upstream,
		Ahead:          ahead,
		Behind:         behind,
		WorktreeHash:   worktreeHash,
		IndexHash:      indexHash,
		ChangedCount:   staged + unstaged + untracked,
		StagedCount:    staged,
		UnstagedCount:  unstaged,
		UntrackedCount: untracked,
		Version:        version,
	}, nil
}

func parseStatusCounts(status string) (staged, unstaged, untracked int) {
	for _, line := range strings.Split(status, "\n") {
		if len(line) < 2 {
			continue
		}
		x, y := line[0], line[1]
		if x == '?' && y == '?' {
			untracked++
		} else {
			if x != ' ' && x != '?' {
				staged++
			}
			if y != ' ' && y != '?' {
				unstaged++
			}
		}
	}
	return
}

type gitState struct {
	Head         string
	WorktreeHash string
	IndexHash    string
	Version      int64
}

func (s *Service) getGitState(ctx context.Context, projectID string) (*gitState, error) {
	row := s.db.DB().QueryRowContext(ctx,
		`SELECT head, worktree_hash, index_hash, version FROM git_state WHERE project_id = ?`,
		projectID)
	var state gitState
	err := row.Scan(&state.Head, &state.WorktreeHash, &state.IndexHash, &state.Version)
	if err != nil {
		return nil, err
	}
	return &state, nil
}

func (s *Service) saveGitState(ctx context.Context, projectID string, version int64, head, worktreeHash, indexHash string) {
	s.db.DB().ExecContext(ctx,
		`INSERT OR REPLACE INTO git_state (project_id, version, head, worktree_hash, index_hash, updated_at)
		 VALUES (?, ?, ?, ?, ?, strftime('%s', 'now'))`,
		projectID, version, head, worktreeHash, indexHash)
}

func (s *Service) getOrBumpVersion(ctx context.Context, projectID, head, worktreeHash, indexHash string) int64 {
	current, _ := s.getGitState(ctx, projectID)
	if current != nil && current.Head == head && current.WorktreeHash == worktreeHash && current.IndexHash == indexHash {
		return current.Version
	}
	newVersion := int64(1)
	if current != nil {
		newVersion = current.Version + 1
	}
	s.saveGitState(ctx, projectID, newVersion, head, worktreeHash, indexHash)
	return newVersion
}

func (s *Service) computeWorktreeHash(ctx context.Context, projectPath string) string {
	out, _ := s.Git(ctx, projectPath, "ls-files", "-s")
	h := sha256.Sum256(out)
	return "wt_" + hex.EncodeToString(h[:])[:16]
}

func (s *Service) computeIndexHash(ctx context.Context, projectPath string) string {
	indexBytes, _ := os.ReadFile(filepath.Join(projectPath, ".git", "index"))
	h := sha256.Sum256(indexBytes)
	return "idx_" + hex.EncodeToString(h[:])[:16]
}
