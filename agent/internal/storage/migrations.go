package storage

func (s *SQLite) migrate() error {
	_, err := s.db.Exec(`
		CREATE TABLE IF NOT EXISTS projects (
			id TEXT PRIMARY KEY,
			name TEXT NOT NULL,
			path TEXT NOT NULL,
			default_provider TEXT DEFAULT 'codex',
			created_at INTEGER NOT NULL,
			updated_at INTEGER NOT NULL
		);

		CREATE TABLE IF NOT EXISTS audit_log (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			session_id TEXT,
			action TEXT NOT NULL,
			target TEXT,
			detail TEXT,
			result TEXT,
			created_at INTEGER NOT NULL
		);

		CREATE TABLE IF NOT EXISTS bootstrap_cache (
			id INTEGER PRIMARY KEY CHECK (id = 1),
			config_hash TEXT NOT NULL,
			data BLOB NOT NULL,
			updated_at INTEGER NOT NULL
		);

		CREATE TABLE IF NOT EXISTS pending_approvals (
			approval_id TEXT PRIMARY KEY,
			session_id TEXT NOT NULL,
			thread_id TEXT NOT NULL,
			turn_id TEXT,
			item_id TEXT,
			codex_request_id INTEGER NOT NULL,
			type TEXT NOT NULL,
			request_json TEXT NOT NULL,
			status TEXT NOT NULL,
			created_at INTEGER NOT NULL,
			resolved_at INTEGER
		);

		CREATE TABLE IF NOT EXISTS session_items (
			session_id TEXT NOT NULL,
			item_id TEXT NOT NULL,
			turn_id TEXT,
			order_key INTEGER NOT NULL,
			revision INTEGER NOT NULL,
			type TEXT NOT NULL,
			status TEXT,
			role TEXT,
			summary TEXT,
			content_json TEXT NOT NULL,
			provider_cursor TEXT,
			created_at INTEGER NOT NULL,
			updated_at INTEGER NOT NULL,
			deleted_at INTEGER,
			PRIMARY KEY(session_id, item_id)
		);

		CREATE INDEX IF NOT EXISTS idx_session_items_order
			ON session_items(session_id, deleted_at, order_key, created_at, item_id);

		CREATE TABLE IF NOT EXISTS session_item_changes (
			session_id TEXT NOT NULL,
			revision INTEGER NOT NULL,
			op TEXT NOT NULL,
			item_id TEXT NOT NULL,
			item_json TEXT,
			created_at INTEGER NOT NULL,
			PRIMARY KEY(session_id, revision)
		);

		CREATE INDEX IF NOT EXISTS idx_session_item_changes_session_revision
			ON session_item_changes(session_id, revision);

		CREATE TABLE IF NOT EXISTS session_item_sync_state (
			session_id TEXT PRIMARY KEY,
			revision INTEGER NOT NULL DEFAULT 0,
			provider_tail_hash TEXT,
			provider_tail_item_count INTEGER NOT NULL DEFAULT 0,
			last_reconciled_at INTEGER
		);
	`)
	if err != nil {
		return err
	}
	if _, err := s.db.Exec(`DROP TABLE IF EXISTS sessions`); err != nil {
		return err
	}
	return s.dropContentCacheTables()
}

func (s *SQLite) dropContentCacheTables() error {
	_, err := s.db.Exec(`
		DROP TABLE IF EXISTS session_events;
		DROP TABLE IF EXISTS git_state;
		DROP TABLE IF EXISTS git_file_changes;
		DROP TABLE IF EXISTS git_diff_cache;
		DROP TABLE IF EXISTS file_cache;
		DROP TABLE IF EXISTS dir_cache;
	`)
	return err
}
