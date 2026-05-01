package storage

import (
	"database/sql"
	"testing"

	_ "modernc.org/sqlite"
)

func TestMigrateDropsContentCachesAndRebuildsSessions(t *testing.T) {
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

	columns := tableColumns(t, db, "sessions")
	if columns["status"] {
		t.Fatalf("expected old status column to be removed")
	}
	if columns["last_seq"] {
		t.Fatalf("expected last_seq column to be removed")
	}
	if !columns["last_status"] {
		t.Fatalf("expected last_status column")
	}
	if columns["approval_mode"] {
		t.Fatalf("expected approval_mode column to be removed")
	}
	if !columns["approval_policy"] {
		t.Fatalf("expected approval_policy column")
	}
	if !columns["purpose"] {
		t.Fatalf("expected purpose column")
	}

	var lastStatus string
	var approvalPolicy string
	if err := db.QueryRow(`SELECT last_status, approval_policy FROM sessions WHERE id = 's1'`).Scan(&lastStatus, &approvalPolicy); err != nil {
		t.Fatalf("read migrated session: %v", err)
	}
	if lastStatus != "running" {
		t.Fatalf("expected status copied to last_status, got %q", lastStatus)
	}
	if approvalPolicy != "onRequest" {
		t.Fatalf("expected approval_mode copied to approval_policy, got %q", approvalPolicy)
	}

	for _, table := range []string{"session_events", "git_state", "git_file_changes", "git_diff_cache", "file_cache", "dir_cache"} {
		if tableExists(t, db, table) {
			t.Fatalf("expected %s to be dropped", table)
		}
	}
}

func tableColumns(t *testing.T, db *sql.DB, table string) map[string]bool {
	t.Helper()
	rows, err := db.Query(`PRAGMA table_info(` + table + `)`)
	if err != nil {
		t.Fatalf("table info %s: %v", table, err)
	}
	defer rows.Close()

	columns := map[string]bool{}
	for rows.Next() {
		var cid int
		var name, typ string
		var notNull int
		var defaultValue any
		var pk int
		if err := rows.Scan(&cid, &name, &typ, &notNull, &defaultValue, &pk); err != nil {
			t.Fatalf("scan table info %s: %v", table, err)
		}
		columns[name] = true
	}
	return columns
}

func tableExists(t *testing.T, db *sql.DB, table string) bool {
	t.Helper()
	var name string
	err := db.QueryRow(`SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?`, table).Scan(&name)
	return err == nil
}
