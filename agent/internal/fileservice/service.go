package fileservice

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/magent/agent/internal/storage"
)

type Service struct {
	db             *storage.SQLite
	excludePattern []string
}

func NewService(db *storage.SQLite, excludePattern []string) *Service {
	return &Service{
		db:             db,
		excludePattern: excludePattern,
	}
}

type DirEntry struct {
	Name  string `json:"name"`
	Type  string `json:"type"`
	Size  int64  `json:"size,omitempty"`
	Mtime int64  `json:"mtime"`
	Hash  string `json:"hash,omitempty"`
}

type DirListResult struct {
	Path  string     `json:"path"`
	Hash  string     `json:"hash"`
	Items []DirEntry `json:"items"`
}

func (s *Service) ListDir(ctx context.Context, projectID, projectPath, relPath, knownHash string) (*DirListResult, int, error) {
	fullPath := filepath.Join(projectPath, relPath)

	if err := s.validatePath(fullPath, projectPath); err != nil {
		return nil, 403, err
	}

	entries, err := os.ReadDir(fullPath)
	if err != nil {
		return nil, 404, err
	}

	entries = s.filterExcluded(entries)

	var items []DirEntry
	for _, e := range entries {
		info, _ := e.Info()
		item := DirEntry{
			Name:  e.Name(),
			Mtime: info.ModTime().Unix(),
		}
		if e.IsDir() {
			item.Type = "dir"
		} else {
			item.Type = "file"
			item.Size = info.Size()
			item.Hash = s.fileHash(filepath.Join(fullPath, e.Name()), info)
		}
		items = append(items, item)
	}

	dirHash := s.computeDirHash(items)

	if knownHash != "" && knownHash == dirHash {
		return nil, 304, nil
	}

	return &DirListResult{
		Path:  relPath,
		Hash:  dirHash,
		Items: items,
	}, 200, nil
}

func (s *Service) validatePath(path, projectPath string) error {
	absPath, err := filepath.Abs(path)
	if err != nil {
		return err
	}
	absProject, err := filepath.Abs(projectPath)
	if err != nil {
		return err
	}
	if !strings.HasPrefix(absPath, absProject) {
		return fmt.Errorf("path traversal detected")
	}
	return nil
}

func (s *Service) filterExcluded(entries []os.DirEntry) []os.DirEntry {
	var filtered []os.DirEntry
	for _, e := range entries {
		excluded := false
		for _, pattern := range s.excludePattern {
			if matched, _ := filepath.Match(pattern, e.Name()); matched {
				excluded = true
				break
			}
		}
		if !excluded {
			filtered = append(filtered, e)
		}
	}
	return filtered
}

func (s *Service) fileHash(path string, info os.FileInfo) string {
	h := sha256.New()
	h.Write([]byte(path))
	h.Write([]byte(fmt.Sprintf("%d", info.Size())))
	h.Write([]byte(info.ModTime().String()))
	return "f_" + hex.EncodeToString(h.Sum(nil))[:16]
}

func (s *Service) computeDirHash(items []DirEntry) string {
	h := sha256.New()
	sort.Slice(items, func(i, j int) bool {
		return items[i].Name < items[j].Name
	})
	for _, item := range items {
		h.Write([]byte(item.Name))
		h.Write([]byte(item.Hash))
	}
	return "d_" + hex.EncodeToString(h.Sum(nil))[:16]
}

type FileContent struct {
	Path       string `json:"path"`
	Hash       string `json:"hash"`
	Size       int64  `json:"size"`
	TotalLines int    `json:"total_lines"`
	Offset     int    `json:"offset"`
	Limit      int    `json:"limit"`
	Content    string `json:"content"`
}

func (s *Service) ReadFile(ctx context.Context, projectPath, relPath, knownHash string, offset, limit int) (*FileContent, int, error) {
	fullPath := filepath.Join(projectPath, relPath)

	if err := s.validatePath(fullPath, projectPath); err != nil {
		return nil, 403, err
	}

	info, err := os.Stat(fullPath)
	if err != nil {
		return nil, 404, err
	}

	hash := s.fileHash(fullPath, info)

	if knownHash != "" && knownHash == hash {
		return nil, 304, nil
	}

	f, err := os.Open(fullPath)
	if err != nil {
		return nil, 500, err
	}
	defer f.Close()

	if limit <= 0 {
		limit = 1000
	}

	lines, totalLines := readLines(f, offset, limit)

	return &FileContent{
		Path:       relPath,
		Hash:       hash,
		Size:       info.Size(),
		TotalLines: totalLines,
		Offset:     offset,
		Limit:      limit,
		Content:    strings.Join(lines, "\n"),
	}, 200, nil
}

func readLines(f *os.File, offset, limit int) ([]string, int) {
	var lines []string
	totalLines := 0
	reader := io.Reader(f)
	buf := make([]byte, 32*1024)
	lineStart := 0
	currentLine := 0

	for {
		n, err := reader.Read(buf)
		if n > 0 {
			for i := 0; i < n; i++ {
				if buf[i] == '\n' {
					totalLines++
					if currentLine >= offset && currentLine < offset+limit {
						lines = append(lines, string(buf[lineStart:i]))
					}
					currentLine++
					lineStart = i + 1
				}
			}
		}
		if err != nil {
			break
		}
	}

	return lines, totalLines
}
