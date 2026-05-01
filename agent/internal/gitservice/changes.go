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
	summary, err := s.GetSummary(ctx, projectID, projectPath)
	if err != nil {
		return nil, err
	}
	if summary.Version == baseVersion {
		return &ChangesResult{Version: baseVersion}, nil
	}
	return s.computeChanges(ctx, projectPath, summary.Version)
}

func (s *Service) computeChanges(ctx context.Context, projectPath string, version int64) (*ChangesResult, error) {
	stagedOut, _ := s.Git(ctx, projectPath, "diff", "--cached", "--numstat")
	unstagedOut, _ := s.Git(ctx, projectPath, "diff", "--numstat")
	untrackedOut, _ := s.Git(ctx, projectPath, "ls-files", "--others", "--exclude-standard")

	var files []FileChange

	for _, l := range parseNumstat(string(stagedOut)) {
		f := l.toFileChange(true)
		f.DiffHash = s.computePathDiffHash(ctx, projectPath, f.Path, true)
		files = append(files, f)
	}

	for _, l := range parseNumstat(string(unstagedOut)) {
		f := l.toFileChange(false)
		f.DiffHash = s.computePathDiffHash(ctx, projectPath, f.Path, false)
		files = append(files, f)
	}

	for _, path := range strings.Split(strings.TrimSpace(string(untrackedOut)), "\n") {
		if path != "" {
			out, _ := s.Git(ctx, projectPath, "hash-object", "--no-filters", "--", path)
			files = append(files, FileChange{
				Path:     path,
				Status:   "untracked",
				NewHash:  strings.TrimSpace(string(out)),
				DiffHash: s.computeUntrackedDiffHash(ctx, projectPath, path),
			})
		}
	}

	return &ChangesResult{
		Version: version,
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

func ComputeDiffContentHash(content []byte) string {
	h := sha256.Sum256(content)
	return "diff_" + hex.EncodeToString(h[:])[:16]
}

func (s *Service) computePathDiffHash(ctx context.Context, projectPath, path string, staged bool) string {
	args := []string{"diff", "--", path}
	if staged {
		args = []string{"diff", "--cached", "--", path}
	}
	out, _ := s.Git(ctx, projectPath, args...)
	return ComputeDiffContentHash(out)
}

func (s *Service) computeUntrackedDiffHash(ctx context.Context, projectPath, path string) string {
	out, _ := s.Git(ctx, projectPath, "diff", "--no-index", "--", "/dev/null", path)
	return ComputeDiffContentHash(out)
}
