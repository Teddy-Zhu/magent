package gitservice

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
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

	version := ComputeGitVersion(head, worktreeHash, indexHash)

	summary := &GitSummary{
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
	}

	return summary, nil
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

func (s *Service) computeWorktreeHash(ctx context.Context, projectPath string) string {
	statusOut, _ := s.Git(ctx, projectPath, "status", "--porcelain=v2", "-z", "--branch")
	diffOut, _ := s.Git(ctx, projectPath, "diff", "--binary")
	untrackedOut, _ := s.Git(ctx, projectPath, "ls-files", "--others", "--exclude-standard", "-z")
	h := sha256.New()
	h.Write(statusOut)
	h.Write([]byte{0})
	h.Write(diffOut)
	h.Write([]byte{0})
	for _, path := range strings.Split(strings.TrimRight(string(untrackedOut), "\x00"), "\x00") {
		if path == "" {
			continue
		}
		contentHash, _ := s.Git(ctx, projectPath, "hash-object", "--no-filters", "--", path)
		h.Write([]byte(path))
		h.Write([]byte{0})
		h.Write(contentHash)
		h.Write([]byte{0})
	}
	return "wt_" + hex.EncodeToString(h.Sum(nil))[:16]
}

func (s *Service) computeIndexHash(ctx context.Context, projectPath string) string {
	out, _ := s.Git(ctx, projectPath, "diff", "--cached", "--binary")
	h := sha256.Sum256(out)
	return "idx_" + hex.EncodeToString(h[:])[:16]
}

func ComputeGitVersion(parts ...string) int64 {
	h := sha256.New()
	for _, part := range parts {
		h.Write([]byte(part))
		h.Write([]byte{0})
	}
	sum := h.Sum(nil)
	var version int64
	for _, b := range sum[:8] {
		version = (version << 8) | int64(b)
	}
	if version < 0 {
		version = -version
	}
	if version == 0 {
		version = 1
	}
	return version
}
