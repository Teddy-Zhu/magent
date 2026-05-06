package storage

import (
	"database/sql"
	"testing"

	_ "modernc.org/sqlite"
)

func TestMigrateDropsContentCachesAndSessions(t *testing.T) {
	db, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	defer db.Close()

	if _, err := db.Exec(`
		CREATE TABLE sessions (
			id TEXT PRIMARY KEY,
			provider_id TEXT NOT NULL,
			thread_id TEXT,
			project_id TEXT NOT NULL,
			title TEXT,
			workdir TEXT,
			status TEXT NOT NULL,
			runner_type TEXT NOT NULL,
			model TEXT,
			approval_mode TEXT,
			sandbox_mode TEXT,
			config TEXT,
			last_seq INTEGER DEFAULT 0,
			created_at INTEGER NOT NULL,
			updated_at INTEGER NOT NULL,
			exited_at INTEGER
		);
		INSERT INTO sessions (
			id, provider_id, thread_id, project_id, status, runner_type, approval_mode, created_at, updated_at
		) VALUES ('s1', 'codex', 'thr_1', 'p1', 'running', 'app-server', 'onRequest', 1, 1);
		CREATE TABLE session_events (id INTEGER PRIMARY KEY);
		CREATE TABLE git_state (project_id TEXT PRIMARY KEY);
		CREATE TABLE git_file_changes (project_id TEXT);
		CREATE TABLE git_diff_cache (project_id TEXT);
		CREATE TABLE file_cache (project_id TEXT);
		CREATE TABLE dir_cache (project_id TEXT);
	`); err != nil {
		t.Fatalf("seed old schema: %v", err)
	}

	store := &SQLite{db: db}
	if err := store.migrate(); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	if tableExists(t, db, "sessions") {
		t.Fatalf("expected sessions table to be dropped")
	}

	for _, table := range []string{"session_events", "git_state", "git_file_changes", "git_diff_cache", "file_cache", "dir_cache"} {
		if tableExists(t, db, table) {
			t.Fatalf("expected %s to be dropped", table)
		}
	}
}

func tableExists(t *testing.T, db *sql.DB, table string) bool {
	t.Helper()
	var name string
	err := db.QueryRow(`SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?`, table).Scan(&name)
	return err == nil
}
