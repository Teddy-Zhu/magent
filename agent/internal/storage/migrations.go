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
			purpose TEXT,
			title TEXT,
			workdir TEXT,
			last_status TEXT,
			runner_type TEXT NOT NULL,
			model TEXT,
			approval_policy TEXT,
			sandbox_mode TEXT,
			config TEXT,
			created_at INTEGER NOT NULL,
			updated_at INTEGER NOT NULL,
			exited_at INTEGER
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
	`)
	if err != nil {
		return err
	}
	if err := s.migrateSessionControlPlaneSchema(); err != nil {
		return err
	}
	return s.dropContentCacheTables()
}

func (s *SQLite) migrateSessionControlPlaneSchema() error {
	rows, err := s.db.Query(`PRAGMA table_info(sessions)`)
	if err != nil {
		return err
	}
	defer rows.Close()

	hasStatus := false
	hasLastStatus := false
	hasLastSeq := false
	hasApprovalMode := false
	hasApprovalPolicy := false
	hasPurpose := false
	for rows.Next() {
		var cid int
		var name, typ string
		var notNull int
		var defaultValue any
		var pk int
		if err := rows.Scan(&cid, &name, &typ, &notNull, &defaultValue, &pk); err != nil {
			return err
		}
		switch name {
		case "status":
			hasStatus = true
		case "last_status":
			hasLastStatus = true
		case "last_seq":
			hasLastSeq = true
		case "approval_mode":
			hasApprovalMode = true
		case "approval_policy":
			hasApprovalPolicy = true
		case "purpose":
			hasPurpose = true
		}
	}
	if err := rows.Err(); err != nil {
		return err
	}
	if !hasStatus && !hasLastSeq && hasLastStatus && hasApprovalPolicy && !hasApprovalMode && hasPurpose {
		return nil
	}
	lastStatusExpr := "status"
	if hasLastStatus && hasStatus {
		lastStatusExpr = "COALESCE(last_status, status)"
	} else if hasLastStatus {
		lastStatusExpr = "last_status"
	}
	approvalPolicyExpr := "NULL"
	if hasApprovalMode && hasApprovalPolicy {
		approvalPolicyExpr = "COALESCE(approval_policy, approval_mode)"
	} else if hasApprovalMode {
		approvalPolicyExpr = "approval_mode"
	} else if hasApprovalPolicy {
		approvalPolicyExpr = "approval_policy"
	}
	purposeExpr := "NULL"
	if hasPurpose {
		purposeExpr = "purpose"
	}

	_, err = s.db.Exec(`
		CREATE TABLE IF NOT EXISTS sessions_new (
			id TEXT PRIMARY KEY,
			provider_id TEXT NOT NULL,
			thread_id TEXT,
			project_id TEXT NOT NULL,
			purpose TEXT,
			title TEXT,
			workdir TEXT,
			last_status TEXT,
			runner_type TEXT NOT NULL,
			model TEXT,
			approval_policy TEXT,
			sandbox_mode TEXT,
			config TEXT,
			created_at INTEGER NOT NULL,
			updated_at INTEGER NOT NULL,
			exited_at INTEGER
		);

		INSERT OR REPLACE INTO sessions_new (
			id, provider_id, thread_id, project_id, purpose, title, workdir, last_status,
			runner_type, model, approval_policy, sandbox_mode, config, created_at, updated_at, exited_at
		)
		SELECT
			id,
			provider_id,
			thread_id,
			project_id,
			` + purposeExpr + `,
			title,
			workdir,
			` + lastStatusExpr + `,
			COALESCE(runner_type, 'app-server'),
			model,
			` + approvalPolicyExpr + `,
			sandbox_mode,
			config,
			created_at,
			updated_at,
			exited_at
		FROM sessions;

		DROP TABLE sessions;
		ALTER TABLE sessions_new RENAME TO sessions;
	`)
	return err
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
