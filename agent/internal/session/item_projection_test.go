package session

import (
	"context"
	"testing"
	"time"

	"github.com/Teddy-Zhu/magent/agent/internal/provider"
	"github.com/Teddy-Zhu/magent/agent/internal/storage"
)

func TestItemProjectionReconcileUpsertIsStable(t *testing.T) {
	store := newTestItemProjectionStore(t)
	ctx := context.Background()
	items := []provider.SessionItem{
		testProjectionItem("item-1", 1, "hello"),
	}

	first, err := store.Reconcile(ctx, "s1", items)
	if err != nil {
		t.Fatalf("first reconcile: %v", err)
	}
	if len(first.Changes) != 1 || first.ToRevision != 1 {
		t.Fatalf("first changes = %#v", first)
	}

	second, err := store.Reconcile(ctx, "s1", items)
	if err != nil {
		t.Fatalf("second reconcile: %v", err)
	}
	if len(second.Changes) != 0 || second.ToRevision != 1 {
		t.Fatalf("stable reconcile changed projection: %#v", second)
	}
}

func TestItemProjectionReconcileDeletesMissingItems(t *testing.T) {
	store := newTestItemProjectionStore(t)
	ctx := context.Background()
	if _, err := store.Reconcile(ctx, "s1", []provider.SessionItem{
		testProjectionItem("item-1", 1, "hello"),
		testProjectionItem("item-2", 2, "bye"),
	}); err != nil {
		t.Fatalf("seed reconcile: %v", err)
	}

	changes, err := store.Reconcile(ctx, "s1", []provider.SessionItem{
		testProjectionItem("item-2", 2, "bye"),
	})
	if err != nil {
		t.Fatalf("delete reconcile: %v", err)
	}
	if len(changes.Changes) != 1 || changes.Changes[0].Op != "delete" || changes.Changes[0].ItemID != "item-1" {
		t.Fatalf("delete changes = %#v", changes.Changes)
	}
	snapshot, err := store.Snapshot(ctx, "s1")
	if err != nil {
		t.Fatalf("snapshot: %v", err)
	}
	if len(snapshot.Items) != 1 || snapshot.Items[0].ItemID != "item-2" {
		t.Fatalf("snapshot items = %#v", snapshot.Items)
	}
}

func TestItemProjectionChangesRequiresResetWhenChangeLogGap(t *testing.T) {
	store := newTestItemProjectionStore(t)
	ctx := context.Background()
	if _, err := store.Reconcile(ctx, "s1", []provider.SessionItem{
		testProjectionItem("item-1", 1, "hello"),
		testProjectionItem("item-2", 2, "bye"),
	}); err != nil {
		t.Fatalf("seed reconcile: %v", err)
	}
	if _, err := store.db.Exec(`DELETE FROM session_item_changes WHERE session_id = ? AND revision = ?`, "s1", 1); err != nil {
		t.Fatalf("delete change log: %v", err)
	}

	page, err := store.Changes(ctx, "s1", 0, 500)
	if err != nil {
		t.Fatalf("changes: %v", err)
	}
	if !page.ResetRequired {
		t.Fatalf("ResetRequired = false, page=%#v", page)
	}
}

func TestItemProjectionUpsertDoesNotDeleteExistingItems(t *testing.T) {
	store := newTestItemProjectionStore(t)
	ctx := context.Background()
	if _, err := store.Reconcile(ctx, "s1", []provider.SessionItem{
		testProjectionItem("item-1", 1, "hello"),
	}); err != nil {
		t.Fatalf("seed reconcile: %v", err)
	}

	changes, err := store.Upsert(ctx, "s1", testProjectionItem("item-2", 2, "bye"))
	if err != nil {
		t.Fatalf("upsert: %v", err)
	}
	if len(changes.Changes) != 1 || changes.Changes[0].Op != "upsert" {
		t.Fatalf("upsert changes = %#v", changes.Changes)
	}
	snapshot, err := store.Snapshot(ctx, "s1")
	if err != nil {
		t.Fatalf("snapshot: %v", err)
	}
	if len(snapshot.Items) != 2 {
		t.Fatalf("snapshot items = %#v, want 2 items", snapshot.Items)
	}
}

func newTestItemProjectionStore(t *testing.T) *itemProjectionStore {
	t.Helper()
	db, err := storage.Open(":memory:")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	return newItemProjectionStore(NewSessionStore(db))
}

func testProjectionItem(id string, index int, text string) provider.SessionItem {
	ts := time.Unix(1777730145+int64(index), 0)
	return provider.SessionItem{
		ItemID:    id,
		TurnID:    "turn-1",
		Index:     index,
		Type:      string(provider.ItemTypeAgentMessage),
		Status:    "completed",
		Role:      "assistant",
		Summary:   text,
		Content:   map[string]any{"text": text},
		CreatedAt: ts,
		UpdatedAt: ts,
	}
}
