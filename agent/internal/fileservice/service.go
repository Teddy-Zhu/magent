package fileservice

import (
	"bufio"
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"unicode/utf8"

	"github.com/Teddy-Zhu/magent/agent/internal/storage"
)

const DefaultRawFileLimit = 2 * 1024 * 1024
const DefaultPreviewFileLimit = 2 * 1024 * 1024

const binarySniffLimit = 8 * 1024

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
	resolvedProject, err := filepath.EvalSymlinks(absProject)
	if err != nil {
		return err
	}
	resolvedPath, err := filepath.EvalSymlinks(absPath)
	if err != nil {
		if !os.IsNotExist(err) {
			return err
		}
		resolvedPath = absPath
	}
	rel, err := filepath.Rel(resolvedProject, resolvedPath)
	if err != nil {
		return err
	}
	if rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) || filepath.IsAbs(rel) {
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

type RawFileContent struct {
	Path      string `json:"path"`
	Hash      string `json:"hash"`
	Mime      string `json:"mime"`
	Encoding  string `json:"encoding"`
	Data      []byte `json:"-"`
	Size      int64  `json:"size"`
	Offset    int64  `json:"offset"`
	Limit     int64  `json:"limit"`
	Truncated bool   `json:"truncated"`
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
	if info.IsDir() {
		return nil, 400, fmt.Errorf("path is a directory")
	}
	if info.Size() > DefaultPreviewFileLimit {
		return nil, 413, fmt.Errorf("file is too large to preview")
	}
	binary, err := isLikelyBinaryFile(fullPath)
	if err != nil {
		return nil, 500, err
	}
	if binary {
		return nil, 415, fmt.Errorf("binary file cannot be previewed")
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
	if offset < 0 {
		offset = 0
	}

	lines, totalLines, err := readLines(f, offset, limit)
	if err != nil {
		return nil, 500, err
	}

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

func (s *Service) ReadRawFile(ctx context.Context, projectPath, relPath, knownHash string, offset, limit int64) (*RawFileContent, int, error) {
	fullPath := filepath.Join(projectPath, relPath)
	if err := s.validatePath(fullPath, projectPath); err != nil {
		return nil, 403, err
	}

	info, err := os.Stat(fullPath)
	if err != nil {
		return nil, 404, err
	}
	if info.IsDir() {
		return nil, 400, fmt.Errorf("path is a directory")
	}
	if limit <= 0 && info.Size() > DefaultRawFileLimit {
		return nil, 413, fmt.Errorf("file is too large to preview")
	}
	binary, err := isLikelyBinaryFile(fullPath)
	if err != nil {
		return nil, 500, err
	}
	if binary && !IsPreviewImageExtension(strings.ToLower(filepath.Ext(fullPath))) {
		return nil, 415, fmt.Errorf("binary file cannot be previewed")
	}

	hash := s.fileHash(fullPath, info)
	if knownHash != "" && knownHash == hash {
		return nil, 304, nil
	}
	if offset < 0 {
		offset = 0
	}
	if limit <= 0 || limit > DefaultRawFileLimit {
		limit = DefaultRawFileLimit
	}
	if offset > info.Size() {
		offset = info.Size()
	}

	f, err := os.Open(fullPath)
	if err != nil {
		return nil, 500, err
	}
	defer f.Close()

	if _, err := f.Seek(offset, io.SeekStart); err != nil {
		return nil, 500, err
	}
	var buf bytes.Buffer
	n, err := io.CopyN(&buf, f, limit)
	if err != nil && err != io.EOF {
		return nil, 500, err
	}

	return &RawFileContent{
		Path:      relPath,
		Hash:      hash,
		Data:      buf.Bytes(),
		Size:      info.Size(),
		Offset:    offset,
		Limit:     limit,
		Truncated: offset+n < info.Size(),
	}, 200, nil
}

func readLines(f *os.File, offset, limit int) ([]string, int, error) {
	var lines []string
	totalLines := 0
	if offset < 0 {
		offset = 0
	}
	if limit <= 0 {
		limit = 1000
	}
	reader := bufio.NewReaderSize(f, 32*1024)
	for {
		line, err := reader.ReadString('\n')
		if len(line) > 0 {
			line = strings.TrimSuffix(line, "\n")
			line = strings.TrimSuffix(line, "\r")
			if totalLines >= offset && totalLines < offset+limit {
				lines = append(lines, line)
			}
			totalLines++
		}
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, totalLines, err
		}
	}

	return lines, totalLines, nil
}

func isLikelyBinaryFile(path string) (bool, error) {
	f, err := os.Open(path)
	if err != nil {
		return false, err
	}
	defer f.Close()

	buf := make([]byte, binarySniffLimit)
	n, err := f.Read(buf)
	if err != nil && err != io.EOF {
		return false, err
	}
	if n == 0 {
		return false, nil
	}
	sample := buf[:n]
	if bytes.IndexByte(sample, 0) >= 0 {
		return true, nil
	}
	return !validUTF8Prefix(sample), nil
}

func validUTF8Prefix(data []byte) bool {
	if utf8.Valid(data) {
		return true
	}
	for trim := 1; trim <= 3 && trim < len(data); trim++ {
		if utf8.Valid(data[:len(data)-trim]) {
			return true
		}
	}
	return false
}

func IsKnownBinaryExtension(ext string) bool {
	if IsPreviewImageExtension(ext) {
		return true
	}
	switch ext {
	case ".pdf", ".zip", ".tar", ".gz", ".bz2", ".xz", ".7z", ".rar", ".jar",
		".exe", ".dll", ".so", ".dylib", ".bin", ".dat",
		".mp3", ".mp4", ".avi", ".mov", ".mkv", ".wav", ".flac",
		".ttf", ".otf", ".woff", ".woff2", ".eot":
		return true
	default:
		return false
	}
}

func IsPreviewImageExtension(ext string) bool {
	switch ext {
	case ".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp", ".ico", ".svg":
		return true
	default:
		return false
	}
}
