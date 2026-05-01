package api

import (
	"context"
	"encoding/json"
	"testing"
	"time"

	"github.com/magent/agent/internal/gitservice"
	"github.com/magent/agent/internal/ws"
)

func TestBroadcastGitInvalidatedIsLightweight(t *testing.T) {
	hub := ws.NewHub()
	server := &Server{wsHub: hub}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go hub.Run(ctx)

	client := ws.NewClient(hub, nil, "test")
	hub.AddClient(client)
	waitForClient(t, hub)

	server.broadcastGitInvalidated(&gitservice.GitSummary{
		ProjectID:      "project-1",
		Head:           "abc123",
		Branch:         "main",
		WorktreeHash:   "wt_hash",
		IndexHash:      "idx_hash",
		ChangedCount:   3,
		StagedCount:    1,
		UnstagedCount:  1,
		UntrackedCount: 1,
		Version:        42,
	})

	var msg []byte
	select {
	case msg = <-client.MessagesForTest():
	case <-time.After(time.Second):
		t.Fatal("timed out waiting for git invalidation")
	}
	var event map[string]any
	if err := json.Unmarshal(msg, &event); err != nil {
		t.Fatalf("unmarshal broadcast: %v", err)
	}

	if event["type"] != "git.invalidated" {
		t.Fatalf("type = %v, want git.invalidated", event["type"])
	}
	if event["project_id"] != "project-1" {
		t.Fatalf("project_id = %v, want project-1", event["project_id"])
	}
	if _, ok := event["files"]; ok {
		t.Fatalf("git.invalidated must not include files payload")
	}
}

func waitForClient(t *testing.T, hub *ws.Hub) {
	t.Helper()
	deadline := time.Now().Add(time.Second)
	for time.Now().Before(deadline) {
		if hub.ClientCount() == 1 {
			return
		}
		time.Sleep(time.Millisecond)
	}
	t.Fatalf("client count = %d, want 1", hub.ClientCount())
}
