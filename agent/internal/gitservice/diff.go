package gitservice

import (
	"context"
	"fmt"
	"strconv"
	"strings"
)

type DiffResult struct {
	Path       string     `json:"path"`
	DiffHash   string     `json:"diff_hash"`
	Encoding   string     `json:"encoding"`
	Binary     bool       `json:"binary"`
	Offset     int        `json:"offset"`
	Limit      int        `json:"limit"`
	TotalLines int        `json:"total_lines"`
	Lines      []DiffLine `json:"lines"`
}

type DiffLine struct {
	Type    string `json:"type"`
	Content string `json:"content"`
	OldLine int    `json:"old_line,omitempty"`
	NewLine int    `json:"new_line,omitempty"`
}

func (s *Service) GetFileDiff(ctx context.Context, projectID, projectPath, filePath, diffHash string, offset, limit int, staged bool) (*DiffResult, error) {
	var args []string
	if staged {
		args = []string{"diff", "--cached", "--", filePath}
	} else {
		args = []string{"diff", "--", filePath}
	}
	out, _ := s.Git(ctx, projectPath, args...)
	if strings.TrimSpace(string(out)) == "" && !staged && s.isUntracked(ctx, projectPath, filePath) {
		out, _ = s.Git(ctx, projectPath, "diff", "--no-index", "--", "/dev/null", filePath)
	}
	actualHash := ComputeDiffContentHash(out)
	if diffHash != "" && diffHash != actualHash {
		return nil, fmt.Errorf("diff hash mismatch: requested %s current %s", diffHash, actualHash)
	}
	cacheKey := diffCacheKey(projectID, filePath, actualHash, staged)
	lines, ok := s.diffCache.Get(cacheKey)
	if !ok {
		lines = parseDiffOutput(string(out))
		s.diffCache.Add(cacheKey, lines)
	}

	result := s.paginateDiff(lines, actualHash, offset, limit)
	result.Path = filePath
	result.Encoding = "text"
	result.Binary = diffOutputIsBinary(string(out))
	return result, nil
}

func diffCacheKey(projectID, filePath, diffHash string, staged bool) string {
	return projectID + "\x00" + filePath + "\x00" + diffHash + "\x00" + strconv.FormatBool(staged)
}

func (s *Service) isUntracked(ctx context.Context, projectPath, filePath string) bool {
	out, _ := s.Git(ctx, projectPath, "ls-files", "--others", "--exclude-standard", "-z", "--", filePath)
	return strings.TrimRight(string(out), "\x00") == filePath
}

func (s *Service) paginateDiff(lines []DiffLine, diffHash string, offset, limit int) *DiffResult {
	total := len(lines)
	if offset >= total {
		return &DiffResult{Lines: []DiffLine{}}
	}
	end := offset + limit
	if end > total {
		end = total
	}
	return &DiffResult{
		DiffHash:   diffHash,
		Offset:     offset,
		Limit:      limit,
		TotalLines: total,
		Lines:      lines[offset:end],
	}
}

func parseDiffOutput(diff string) []DiffLine {
	var lines []DiffLine
	oldLine, newLine := 0, 0
	for _, raw := range strings.Split(diff, "\n") {
		// Skip diff header lines
		if strings.HasPrefix(raw, "diff --git") ||
			strings.HasPrefix(raw, "index ") ||
			strings.HasPrefix(raw, "new file") ||
			strings.HasPrefix(raw, "deleted file") ||
			strings.HasPrefix(raw, "rename from") ||
			strings.HasPrefix(raw, "rename to") ||
			strings.HasPrefix(raw, "similarity") {
			continue
		}
		// Skip --- and +++ header lines (but not --- /dev/null content lines in diff body)
		if (strings.HasPrefix(raw, "--- ") || strings.HasPrefix(raw, "+++ ")) && !strings.Contains(raw, "/dev/null") {
			continue
		}
		if strings.HasPrefix(raw, "--- /dev/null") || strings.HasPrefix(raw, "+++ /dev/null") {
			continue
		}
		if strings.HasPrefix(raw, "@@") {
			var a, b, c, d int
			fmt.Sscanf(raw, "@@ -%d,%d +%d,%d", &a, &b, &c, &d)
			oldLine = a
			newLine = c
			continue
		}
		if strings.HasPrefix(raw, "+") {
			lines = append(lines, DiffLine{Type: "add", Content: raw[1:], NewLine: newLine})
			newLine++
		} else if strings.HasPrefix(raw, "-") {
			lines = append(lines, DiffLine{Type: "del", Content: raw[1:], OldLine: oldLine})
			oldLine++
		} else if strings.HasPrefix(raw, " ") {
			lines = append(lines, DiffLine{Type: "context", Content: raw[1:], OldLine: oldLine, NewLine: newLine})
			oldLine++
			newLine++
		}
	}
	return lines
}

func diffOutputIsBinary(diff string) bool {
	for _, line := range strings.Split(diff, "\n") {
		if strings.HasPrefix(line, "Binary files ") || strings.HasPrefix(line, "GIT binary patch") {
			return true
		}
	}
	return false
}
