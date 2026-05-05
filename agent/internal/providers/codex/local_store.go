package codex

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"github.com/Teddy-Zhu/magent/agent/internal/log"
	_ "modernc.org/sqlite"
)

// LocalThreadStore reads codex's local sqlite (`~/.codex/state_5.sqlite`,
// override with `CODEX_HOME`) in read-only mode. The DB is the source of truth
// for fields that codex's app-server `thread/list` does NOT expose: source
// (cli / vscode / appServer / exec / subAgent ...), model, reasoning_effort,
// sandbox_policy, approval_mode, archived_at, etc.
//
// codex_core writes to this file; we only read. We open with `mode=ro` to
// guarantee we never accidentally mutate codex's state.
type LocalThreadStore struct {
	path string

	mu  sync.Mutex
	db  *sql.DB
	bad bool // open failed once — stop retrying within process lifetime
}

func newLocalThreadStore() *LocalThreadStore {
	path := resolveCodexStatePath()
	if path == "" {
		return nil
	}
	return &LocalThreadStore{path: path}
}

// resolveCodexStatePath returns the path to codex's threads sqlite, honoring
// the `CODEX_HOME` env var the same way codex itself does.
func resolveCodexStatePath() string {
	if v := strings.TrimSpace(os.Getenv("CODEX_HOME")); v != "" {
		return filepath.Join(v, "state_5.sqlite")
	}
	home, err := os.UserHomeDir()
	if err != nil || home == "" {
		return ""
	}
	return filepath.Join(home, ".codex", "state_5.sqlite")
}

// Available reports whether the file exists and we have not previously failed
// to open it. Cheap; safe to call on every list request.
func (s *LocalThreadStore) Available() bool {
	if s == nil {
		return false
	}
	s.mu.Lock()
	bad := s.bad
	s.mu.Unlock()
	if bad {
		return false
	}
	if _, err := os.Stat(s.path); err != nil {
		return false
	}
	return true
}

func (s *LocalThreadStore) Close() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.db == nil {
		return nil
	}
	err := s.db.Close()
	s.db = nil
	return err
}

func (s *LocalThreadStore) ensureOpen() (*sql.DB, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.db != nil {
		return s.db, nil
	}
	if s.bad {
		return nil, errors.New("codex local store previously failed to open")
	}
	if _, err := os.Stat(s.path); err != nil {
		s.bad = true
		return nil, fmt.Errorf("codex state not found at %s: %w", s.path, err)
	}
	// modernc.org/sqlite supports SQLite URI; ?mode=ro forces read-only.
	dsn := fmt.Sprintf("file:%s?mode=ro&_pragma=busy_timeout(5000)", url.PathEscape(s.path))
	db, err := sql.Open("sqlite", dsn)
	if err != nil {
		s.bad = true
		return nil, err
	}
	db.SetMaxOpenConns(2)
	if err := db.Ping(); err != nil {
		_ = db.Close()
		s.bad = true
		return nil, err
	}
	s.db = db
	log.Info("codex", "local thread store opened: %s", s.path)
	return db, nil
}

// markFailed closes the connection and marks the store unusable for the rest
// of the process — callers should fall back to the app-server. We treat
// transient errors (busy, locked) as fatal here for simplicity; they are rare
// because codex uses WAL.
func (s *LocalThreadStore) markFailed() {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.db != nil {
		_ = s.db.Close()
		s.db = nil
	}
	s.bad = true
}

// ListThreads reads threads matching opts from codex's local DB.
//
// Matches `codexThreadListSourceKinds` (cli / vscode / appServer) so the UI
// shows the same set that the app-server would show. cwd, when provided, is
// matched exactly — same semantics as `thread/list`.
func (s *LocalThreadStore) ListThreads(ctx context.Context, opts ListThreadsOptions) ([]ThreadInfo, error) {
	db, err := s.ensureOpen()
	if err != nil {
		return nil, err
	}

	limit := opts.Limit
	if limit <= 0 {
		limit = 100
	}

	var b strings.Builder
	b.WriteString(`
		SELECT
			id, cwd,
			COALESCE(source, '') AS source,
			COALESCE(model_provider, '') AS model_provider,
			COALESCE(model, '') AS model,
			COALESCE(reasoning_effort, '') AS reasoning_effort,
			COALESCE(sandbox_policy, '') AS sandbox_policy,
			COALESCE(approval_mode, '') AS approval_mode,
			COALESCE(title, '') AS title,
			COALESCE(first_user_message, '') AS first_user_message,
			archived,
			COALESCE(archived_at, 0) AS archived_at,
			created_at, updated_at
		FROM threads
		WHERE source IN ('cli', 'vscode', 'appServer')
	`)
	args := []any{}
	if opts.Archived {
		b.WriteString(" AND archived = 1")
	} else {
		b.WriteString(" AND archived = 0")
	}
	if cwd := strings.TrimSpace(opts.CWD); cwd != "" {
		b.WriteString(" AND cwd = ?")
		args = append(args, cwd)
	}
	b.WriteString(" ORDER BY updated_at_ms DESC, id DESC LIMIT ?")
	args = append(args, limit)

	rows, err := db.QueryContext(ctx, b.String(), args...)
	if err != nil {
		log.Warn("codex", "local thread store query failed: %v", err)
		s.markFailed()
		return nil, err
	}
	defer rows.Close()

	var result []ThreadInfo
	for rows.Next() {
		var (
			id, cwd, source, modelProvider, model, effort string
			sandboxPolicy, approvalMode, title             string
			firstUserMessage                               string
			archivedFlag                                   int
			archivedAt                                     int64
			createdAt, updatedAt                           int64
		)
		if err := rows.Scan(
			&id, &cwd,
			&source, &modelProvider, &model, &effort,
			&sandboxPolicy, &approvalMode, &title, &firstUserMessage,
			&archivedFlag, &archivedAt,
			&createdAt, &updatedAt,
		); err != nil {
			log.Warn("codex", "local thread store scan failed: %v", err)
			return nil, err
		}
		preview := firstUserMessage
		if preview == "" {
			preview = title
		}
		info := ThreadInfo{
			ID:            id,
			Preview:       preview,
			Name:          title,
			ModelProvider: modelProvider,
			CWD:           cwd,
			Status:        ThreadStatus{Type: "notLoaded"},
			CreatedAt:     createdAt,
			UpdatedAt:     updatedAt,
			Source:        source,
			Model:         model,
			Effort:        effort,
			SandboxPolicy: sandboxPolicy,
			ApprovalMode:  approvalMode,
			Archived:      archivedFlag != 0,
			ArchivedAt:    archivedAt,
		}
		result = append(result, info)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return result, nil
}
