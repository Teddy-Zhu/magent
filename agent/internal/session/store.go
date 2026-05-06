package session

import "github.com/Teddy-Zhu/magent/agent/internal/storage"

type SessionStore struct {
	db *storage.SQLite
}

// SessionStore only wraps the shared SQLite handle for session item projection.
// Session metadata itself is provider-owned and is not persisted in agent DB.
func NewSessionStore(db *storage.SQLite) *SessionStore {
	return &SessionStore{db: db}
}
