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

		CREATE TABLE IF NOT EXISTS sessions (
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

		CREATE TABLE IF NOT EXISTS session_events (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			session_id TEXT NOT NULL,
			seq INTEGER NOT NULL,
			type TEXT NOT NULL,
			payload BLOB,
			created_at INTEGER NOT NULL,
			UNIQUE(session_id, seq)
		);
		CREATE INDEX IF NOT EXISTS idx_events_session_seq
			ON session_events(session_id, seq);

		CREATE TABLE IF NOT EXISTS git_state (
			project_id TEXT PRIMARY KEY,
			version INTEGER NOT NULL,
			head TEXT,
			branch TEXT,
			upstream TEXT,
			ahead INTEGER DEFAULT 0,
			behind INTEGER DEFAULT 0,
			worktree_hash TEXT,
			index_hash TEXT,
			changed_count INTEGER DEFAULT 0,
			staged_count INTEGER DEFAULT 0,
			unstaged_count INTEGER DEFAULT 0,
			untracked_count INTEGER DEFAULT 0,
			updated_at INTEGER NOT NULL
		);

		CREATE TABLE IF NOT EXISTS git_file_changes (
			project_id TEXT NOT NULL,
			path TEXT NOT NULL,
			version INTEGER NOT NULL,
			status TEXT NOT NULL,
			staged INTEGER DEFAULT 0,
			additions INTEGER DEFAULT 0,
			deletions INTEGER DEFAULT 0,
			binary INTEGER DEFAULT 0,
			old_hash TEXT,
			new_hash TEXT,
			diff_hash TEXT,
			size INTEGER,
			PRIMARY KEY(project_id, path, version)
		);

		CREATE TABLE IF NOT EXISTS git_diff_cache (
			project_id TEXT NOT NULL,
			path TEXT NOT NULL,
			diff_hash TEXT NOT NULL,
			content TEXT,
			total_lines INTEGER,
			created_at INTEGER NOT NULL,
			PRIMARY KEY(project_id, path, diff_hash)
		);

		CREATE TABLE IF NOT EXISTS file_cache (
			project_id TEXT NOT NULL,
			path TEXT NOT NULL,
			hash TEXT NOT NULL,
			size INTEGER,
			mtime INTEGER,
			content BLOB,
			created_at INTEGER NOT NULL,
			PRIMARY KEY(project_id, path, hash)
		);

		CREATE TABLE IF NOT EXISTS dir_cache (
			project_id TEXT NOT NULL,
			path TEXT NOT NULL,
			hash TEXT NOT NULL,
			items TEXT,
			created_at INTEGER NOT NULL,
			PRIMARY KEY(project_id, path)
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
	`)
	return err
}
