package gitservice

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"strconv"
	"strings"
)

type FileChange struct {
	Path      string `json:"path"`
	Status    string `json:"status"`
	Staged    bool   `json:"staged"`
	Additions int    `json:"additions"`
	Deletions int    `json:"deletions"`
	Binary    bool   `json:"binary"`
	OldHash   string `json:"old_hash"`
	NewHash   string `json:"new_hash"`
	DiffHash  string `json:"diff_hash"`
	Size      int64  `json:"size"`
}

type ChangesResult struct {
	Version int64        `json:"version"`
	Files   []FileChange `json:"files"`
}

func (s *Service) GetChanges(ctx context.Context, projectID, projectPath string, baseVersion int64) (*ChangesResult, error) {
	currentState, _ := s.getGitState(ctx, projectID)
	if currentState != nil && currentState.Version == baseVersion {
		return &ChangesResult{Version: baseVersion}, nil
	}

	stagedOut, _ := s.Git(ctx, projectPath, "diff", "--cached", "--numstat")
	unstagedOut, _ := s.Git(ctx, projectPath, "diff", "--numstat")
	untrackedOut, _ := s.Git(ctx, projectPath, "ls-files", "--others", "--exclude-standard")

	var files []FileChange

	for _, l := range parseNumstat(string(stagedOut)) {
		f := l.toFileChange(true)
		f.DiffHash = ComputeDiffHash(f.Path, f.OldHash, f.NewHash, "staged")
		files = append(files, f)
	}

	for _, l := range parseNumstat(string(unstagedOut)) {
		f := l.toFileChange(false)
		f.DiffHash = ComputeDiffHash(f.Path, f.OldHash, f.NewHash, "unstaged")
		files = append(files, f)
	}

	for _, path := range strings.Split(strings.TrimSpace(string(untrackedOut)), "\n") {
		if path != "" {
			files = append(files, FileChange{
				Path:   path,
				Status: "untracked",
			})
		}
	}

	return &ChangesResult{
		Version: currentState.Version,
		Files:   files,
	}, nil
}

type numstatLine struct {
	Additions string
	Deletions string
	Path      string
}

func parseNumstat(output string) []numstatLine {
	var lines []numstatLine
	for _, line := range strings.Split(output, "\n") {
		parts := strings.SplitN(line, "\t", 3)
		if len(parts) == 3 {
			lines = append(lines, numstatLine{
				Additions: parts[0],
				Deletions: parts[1],
				Path:      parts[2],
			})
		}
	}
	return lines
}

func (l numstatLine) toFileChange(staged bool) FileChange {
	additions, _ := strconv.Atoi(l.Additions)
	deletions, _ := strconv.Atoi(l.Deletions)

	status := "modified"
	if additions > 0 && deletions == 0 {
		status = "added"
	} else if additions == 0 && deletions > 0 {
		status = "deleted"
	}

	return FileChange{
		Path:      l.Path,
		Status:    status,
		Staged:    staged,
		Additions: additions,
		Deletions: deletions,
	}
}

func ComputeDiffHash(path, oldHash, newHash, mode string) string {
	h := sha256.New()
	h.Write([]byte(path))
	h.Write([]byte(oldHash))
	h.Write([]byte(newHash))
	h.Write([]byte(mode))
	return "diff_" + hex.EncodeToString(h.Sum(nil))[:16]
}
