package session

import (
	"database/sql"
	"encoding/json"
	"time"

	"github.com/magent/agent/internal/provider"
	"github.com/magent/agent/internal/storage"
)

type SessionStore struct {
	db *storage.SQLite
}

func NewSessionStore(db *storage.SQLite) *SessionStore {
	return &SessionStore{db: db}
}

// Save stores minimal session metadata. Provider is source of truth for everything else.
func (s *SessionStore) Save(session *provider.Session) error {
	normalized := *session
	normalizeSessionControlPlane(&normalized)
	now := time.Now().Unix()
	configJSON, _ := json.Marshal(normalized.Config)
	_, err := s.db.DB().Exec(`
		INSERT INTO sessions (
			id, provider_id, thread_id, project_id, purpose, title, workdir, last_status,
			runner_type, model, approval_policy, sandbox_mode, config, created_at, updated_at, exited_at
		)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(id) DO UPDATE SET
			provider_id = excluded.provider_id,
			thread_id = excluded.thread_id,
			project_id = excluded.project_id,
			purpose = COALESCE(excluded.purpose, sessions.purpose),
			title = excluded.title,
			workdir = excluded.workdir,
			last_status = excluded.last_status,
			runner_type = excluded.runner_type,
			model = excluded.model,
			approval_policy = excluded.approval_policy,
			sandbox_mode = excluded.sandbox_mode,
			config = excluded.config,
			updated_at = excluded.updated_at,
			exited_at = excluded.exited_at`,
		normalized.ID, normalized.ProviderID, normalized.ThreadID, normalized.ProjectID,
		nullableString(normalized.Purpose), normalized.Title, normalized.Workdir, nullableString(normalized.Status), defaultString(normalized.RunnerType, "app-server"),
		normalized.Model, normalized.ApprovalPolicy, normalized.SandboxMode, string(configJSON), now, now, nullableTime(normalized.ExitedAt))
	return err
}

func (s *SessionStore) Get(id string) (*provider.Session, error) {
	var session provider.Session
	var createdAt, updatedAt int64
	var purpose, title, workdir, lastStatus, runnerType, model, approvalMode, sandboxMode sql.NullString
	var configRaw sql.NullString
	var exitedAt sql.NullInt64

	err := s.db.DB().QueryRow(`
		SELECT id, provider_id, thread_id, project_id, purpose, title, workdir, last_status,
		       runner_type, model, approval_policy, sandbox_mode, config, created_at, updated_at, exited_at
		FROM sessions WHERE id = ?`, id).Scan(
		&session.ID, &session.ProviderID, &session.ThreadID, &session.ProjectID,
		&purpose, &title, &workdir, &lastStatus, &runnerType, &model, &approvalMode, &sandboxMode,
		&configRaw, &createdAt, &updatedAt, &exitedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	session.Purpose = purpose.String
	session.Title = title.String
	session.Workdir = workdir.String
	session.Status = lastStatus.String
	session.RunnerType = runnerType.String
	session.Model = model.String
	session.ApprovalPolicy = approvalMode.String
	session.SandboxMode = sandboxMode.String
	normalizeSessionControlPlane(&session)
	session.CreatedAt = time.Unix(createdAt, 0)
	session.UpdatedAt = time.Unix(updatedAt, 0)
	if configRaw.Valid && configRaw.String != "" && configRaw.String != "null" {
		_ = json.Unmarshal([]byte(configRaw.String), &session.Config)
	}
	if exitedAt.Valid {
		t := time.Unix(exitedAt.Int64, 0)
		session.ExitedAt = &t
	}
	return &session, nil
}

func (s *SessionStore) ListByProject(projectID string) ([]provider.Session, error) {
	rows, err := s.db.DB().Query(`
		SELECT id, provider_id, thread_id, project_id, purpose, title, workdir, last_status,
		       runner_type, model, approval_policy, sandbox_mode, created_at, updated_at
		FROM sessions WHERE project_id = ? ORDER BY created_at DESC`, projectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var sessions []provider.Session
	for rows.Next() {
		var session provider.Session
		var createdAt, updatedAt int64
		var purpose, title, workdir, lastStatus, runnerType, model, approvalMode, sandboxMode sql.NullString

		if err := rows.Scan(
			&session.ID, &session.ProviderID, &session.ThreadID, &session.ProjectID,
			&purpose, &title, &workdir, &lastStatus, &runnerType, &model, &approvalMode, &sandboxMode,
			&createdAt, &updatedAt); err != nil {
			return nil, err
		}

		session.Purpose = purpose.String
		session.Title = title.String
		session.Workdir = workdir.String
		session.Status = lastStatus.String
		session.RunnerType = runnerType.String
		session.Model = model.String
		session.ApprovalPolicy = approvalMode.String
		session.SandboxMode = sandboxMode.String
		normalizeSessionControlPlane(&session)
		session.CreatedAt = time.Unix(createdAt, 0)
		session.UpdatedAt = time.Unix(updatedAt, 0)
		sessions = append(sessions, session)
	}

	return sessions, nil
}

func (s *SessionStore) Update(session *provider.Session) error {
	status := provider.NormalizeSessionStatus(session.Status)
	_, err := s.db.DB().Exec(`
		UPDATE sessions SET model = ?, last_status = ?, updated_at = ? WHERE id = ?`,
		session.Model, nullableString(status), time.Now().Unix(), session.ID)
	return err
}

func (s *SessionStore) Delete(id string) error {
	_, err := s.db.DB().Exec(`DELETE FROM sessions WHERE id = ?`, id)
	return err
}

func nullableString(value string) any {
	if value == "" {
		return nil
	}
	return value
}

func defaultString(value, fallback string) string {
	if value == "" {
		return fallback
	}
	return value
}

func normalizeSessionControlPlane(session *provider.Session) {
	session.Status = provider.NormalizeSessionStatus(session.Status)
	session.ApprovalPolicy = provider.NormalizeApprovalPolicy(session.ApprovalPolicy)
	session.SandboxMode = provider.NormalizeSandboxMode(session.SandboxMode)
}

func nullableTime(value *time.Time) any {
	if value == nil {
		return nil
	}
	return value.Unix()
}
