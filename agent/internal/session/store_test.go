package session

import (
	"testing"

	"github.com/Teddy-Zhu/magent/agent/internal/storage"
)

func TestSessionStoreWrapsSQLiteForItemProjection(t *testing.T) {
	db, err := storage.Open(":memory:")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer db.Close()

	store := NewSessionStore(db)
	if store.db != db {
		t.Fatalf("store db = %#v, want %#v", store.db, db)
	}
}
