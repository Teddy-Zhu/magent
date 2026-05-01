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

func (s *SessionStore) Save(session *provider.Session) error {
	configJSON, _ := json.Marshal(session.Config)
	_, err := s.db.DB().Exec(`
		INSERT INTO sessions (id, provider_id, thread_id, project_id, title,
			workdir, status, runner_type, model, approval_mode, sandbox_mode,
			config, last_seq, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)`,
		session.ID, session.ProviderID, session.ThreadID, session.ProjectID,
		session.Title, session.Workdir, session.Status, session.RunnerType,
		session.Model, session.ApprovalMode, session.SandboxMode,
		string(configJSON), time.Now().Unix(), time.Now().Unix())
	return err
}

func (s *SessionStore) Get(id string) (*provider.Session, error) {
	var session provider.Session
	var configStr string
	var createdAt, updatedAt int64
	var exitedAt sql.NullInt64

	err := s.db.DB().QueryRow(`
		SELECT id, provider_id, thread_id, project_id, title, workdir,
			status, runner_type, model, approval_mode, sandbox_mode,
			config, last_seq, created_at, updated_at, exited_at
		FROM sessions WHERE id = ?`, id).Scan(
		&session.ID, &session.ProviderID, &session.ThreadID, &session.ProjectID,
		&session.Title, &session.Workdir, &session.Status, &session.RunnerType,
		&session.Model, &session.ApprovalMode, &session.SandboxMode,
		&configStr, &session.LastSeq, &createdAt, &updatedAt, &exitedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	json.Unmarshal([]byte(configStr), &session.Config)
	session.CreatedAt = time.Unix(createdAt, 0)
	session.UpdatedAt = time.Unix(updatedAt, 0)
	if exitedAt.Valid {
		t := time.Unix(exitedAt.Int64, 0)
		session.ExitedAt = &t
	}

	return &session, nil
}

func (s *SessionStore) ListByProject(projectID string) ([]provider.Session, error) {
	rows, err := s.db.DB().Query(`
		SELECT id, provider_id, thread_id, project_id, title, workdir,
			status, runner_type, model, approval_mode, sandbox_mode,
			config, last_seq, created_at, updated_at, exited_at
		FROM sessions WHERE project_id = ? ORDER BY updated_at DESC`, projectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var sessions []provider.Session
	for rows.Next() {
		var session provider.Session
		var configStr string
		var createdAt, updatedAt int64
		var exitedAt sql.NullInt64

		if err := rows.Scan(
			&session.ID, &session.ProviderID, &session.ThreadID, &session.ProjectID,
			&session.Title, &session.Workdir, &session.Status, &session.RunnerType,
			&session.Model, &session.ApprovalMode, &session.SandboxMode,
			&configStr, &session.LastSeq, &createdAt, &updatedAt, &exitedAt); err != nil {
			return nil, err
		}

		json.Unmarshal([]byte(configStr), &session.Config)
		session.CreatedAt = time.Unix(createdAt, 0)
		session.UpdatedAt = time.Unix(updatedAt, 0)
		if exitedAt.Valid {
			t := time.Unix(exitedAt.Int64, 0)
			session.ExitedAt = &t
		}
		sessions = append(sessions, session)
	}

	return sessions, nil
}

func (s *SessionStore) GetActiveSessions() ([]provider.Session, error) {
	rows, err := s.db.DB().Query(`
		SELECT id, provider_id, thread_id, project_id, title, workdir,
			status, runner_type, model, approval_mode, sandbox_mode,
			config, last_seq, created_at, updated_at, exited_at
		FROM sessions WHERE status IN ('running', 'waiting_input')`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var sessions []provider.Session
	for rows.Next() {
		var session provider.Session
		var configStr string
		var createdAt, updatedAt int64
		var exitedAt sql.NullInt64

		if err := rows.Scan(
			&session.ID, &session.ProviderID, &session.ThreadID, &session.ProjectID,
			&session.Title, &session.Workdir, &session.Status, &session.RunnerType,
			&session.Model, &session.ApprovalMode, &session.SandboxMode,
			&configStr, &session.LastSeq, &createdAt, &updatedAt, &exitedAt); err != nil {
			return nil, err
		}

		json.Unmarshal([]byte(configStr), &session.Config)
		session.CreatedAt = time.Unix(createdAt, 0)
		session.UpdatedAt = time.Unix(updatedAt, 0)
		if exitedAt.Valid {
			t := time.Unix(exitedAt.Int64, 0)
			session.ExitedAt = &t
		}
		sessions = append(sessions, session)
	}

	return sessions, nil
}

func (s *SessionStore) Update(session *provider.Session) error {
	configJSON, _ := json.Marshal(session.Config)
	var exitedAt int64
	if session.ExitedAt != nil {
		exitedAt = session.ExitedAt.Unix()
	}
	_, err := s.db.DB().Exec(`
		UPDATE sessions SET title = ?, status = ?, model = ?,
			approval_mode = ?, sandbox_mode = ?, config = ?,
			last_seq = ?, updated_at = ?, exited_at = ?
		WHERE id = ?`,
		session.Title, session.Status, session.Model,
		session.ApprovalMode, session.SandboxMode, string(configJSON),
		session.LastSeq, time.Now().Unix(), exitedAt, session.ID)
	return err
}

func (s *SessionStore) UpdateStatus(id, status string) error {
	_, err := s.db.DB().Exec(`UPDATE sessions SET status = ?, updated_at = ? WHERE id = ?`,
		status, time.Now().Unix(), id)
	return err
}

type SessionEvent struct {
	ID        int64
	SessionID string
	Seq       int64
	Type      string
	Payload   any
	CreatedAt time.Time
}

func (s *SessionStore) SaveEvent(event SessionEvent) error {
	payloadJSON, _ := json.Marshal(event.Payload)
	_, err := s.db.DB().Exec(`
		INSERT INTO session_events (session_id, seq, type, payload, created_at)
		VALUES (?, ?, ?, ?, ?)`,
		event.SessionID, event.Seq, event.Type, string(payloadJSON), event.CreatedAt.Unix())
	return err
}

func (s *SessionStore) GetEventsAfterSeq(sessionID string, afterSeq int64, limit int) ([]SessionEvent, error) {
	rows, err := s.db.DB().Query(`
		SELECT id, session_id, seq, type, payload, created_at
		FROM session_events
		WHERE session_id = ? AND seq > ?
		ORDER BY seq ASC
		LIMIT ?`, sessionID, afterSeq, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var events []SessionEvent
	for rows.Next() {
		var event SessionEvent
		var payloadStr string
		var createdAt int64
		if err := rows.Scan(&event.ID, &event.SessionID, &event.Seq, &event.Type, &payloadStr, &createdAt); err != nil {
			return nil, err
		}
		json.Unmarshal([]byte(payloadStr), &event.Payload)
		event.CreatedAt = time.Unix(createdAt, 0)
		events = append(events, event)
	}

	return events, nil
}
