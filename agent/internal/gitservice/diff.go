package gitservice

import (
	"context"
	"fmt"
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

func (s *Service) GetFileDiff(ctx context.Context, projectPath, filePath, diffHash string, offset, limit int, staged bool) (*DiffResult, error) {
	cached := s.getDiffCache(ctx, filePath, diffHash)
	if cached != nil {
		return s.paginateDiff(cached, diffHash, offset, limit), nil
	}

	var args []string
	if staged {
		args = []string{"diff", "--cached", "--", filePath}
	} else {
		args = []string{"diff", "--", filePath}
	}
	out, _ := s.Git(ctx, projectPath, args...)
	lines := parseDiffOutput(string(out))

	s.saveDiffCache(ctx, filePath, diffHash, lines)

	return s.paginateDiff(lines, diffHash, offset, limit), nil
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

func (s *Service) getDiffCache(ctx context.Context, path, diffHash string) []DiffLine {
	row := s.db.DB().QueryRowContext(ctx,
		`SELECT content FROM git_diff_cache WHERE path = ? AND diff_hash = ?`,
		path, diffHash)
	var content string
	if err := row.Scan(&content); err != nil {
		return nil
	}
	return parseDiffOutput(content)
}

func (s *Service) saveDiffCache(ctx context.Context, path, diffHash string, lines []DiffLine) {
	var sb strings.Builder
	for _, line := range lines {
		switch line.Type {
		case "add":
			sb.WriteString("+")
		case "del":
			sb.WriteString("-")
		case "context":
			sb.WriteString(" ")
		}
		sb.WriteString(line.Content)
		sb.WriteString("\n")
	}

	s.db.DB().ExecContext(ctx,
		`INSERT OR REPLACE INTO git_diff_cache (project_id, path, diff_hash, content, total_lines, created_at)
		 VALUES (?, ?, ?, ?, ?, strftime('%s', 'now'))`,
		"", path, diffHash, sb.String(), len(lines))
}
