package ws

import (
	"encoding/json"
	"testing"
)

func TestPrepareBroadcastAddsReplayCursor(t *testing.T) {
	hub := NewHub()
	data := hub.prepareBroadcast(map[string]any{
		"type":       "session.event",
		"session_id": "s1",
		"data":       map[string]any{"value": "first"},
	})

	var event map[string]any
	if err := json.Unmarshal(data, &event); err != nil {
		t.Fatalf("unmarshal broadcast: %v", err)
	}
	if event["ws_cursor"] != "1" {
		t.Fatalf("ws_cursor = %v, want 1", event["ws_cursor"])
	}
	if event["ws_seq"].(float64) != 1 {
		t.Fatalf("ws_seq = %v, want 1", event["ws_seq"])
	}
	if got := len(hub.replay["s1"]); got != 1 {
		t.Fatalf("replay len = %d, want 1", got)
	}
}

func TestReplaySessionReplaysAfterCursor(t *testing.T) {
	hub := NewHub()
	hub.prepareBroadcast(map[string]any{"type": "session.event", "session_id": "s1", "data": map[string]any{"n": 1}})
	hub.prepareBroadcast(map[string]any{"type": "session.event", "session_id": "s1", "data": map[string]any{"n": 2}})
	hub.prepareBroadcast(map[string]any{"type": "session.event", "session_id": "s2", "data": map[string]any{"n": 3}})

	client := NewClient(hub, nil, "test")
	hub.ReplaySession(client, "s1", "1")

	messages := drainClientMessages(client)
	if len(messages) != 2 {
		t.Fatalf("replayed messages = %d, want event + replay_complete", len(messages))
	}

	var event map[string]any
	if err := json.Unmarshal(messages[0], &event); err != nil {
		t.Fatalf("unmarshal event: %v", err)
	}
	if event["session_id"] != "s1" || event["ws_cursor"] != "2" {
		t.Fatalf("unexpected replay event: %#v", event)
	}

	var done map[string]any
	if err := json.Unmarshal(messages[1], &done); err != nil {
		t.Fatalf("unmarshal replay_complete: %v", err)
	}
	if done["type"] != "session.replay_complete" || done["replayed"].(float64) != 1 {
		t.Fatalf("unexpected replay_complete: %#v", done)
	}
}

func TestReplaySessionReportsGap(t *testing.T) {
	hub := NewHub()
	hub.replayCap = 2
	hub.prepareBroadcast(map[string]any{"type": "session.event", "session_id": "s1"})
	hub.prepareBroadcast(map[string]any{"type": "session.event", "session_id": "s1"})
	hub.prepareBroadcast(map[string]any{"type": "session.event", "session_id": "s1"})

	client := NewClient(hub, nil, "test")
	hub.ReplaySession(client, "s1", "0")

	messages := drainClientMessages(client)
	if len(messages) != 1 {
		t.Fatalf("messages = %d, want sync_required", len(messages))
	}
	var event map[string]any
	if err := json.Unmarshal(messages[0], &event); err != nil {
		t.Fatalf("unmarshal sync_required: %v", err)
	}
	if event["type"] != "session.sync_required" || event["reason"] != "replay_gap" {
		t.Fatalf("unexpected sync_required: %#v", event)
	}
}

func drainClientMessages(client *Client) [][]byte {
	var messages [][]byte
	for {
		select {
		case msg := <-client.send:
			messages = append(messages, msg)
		default:
			return messages
		}
	}
}
