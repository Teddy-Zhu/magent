package codex

import (
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/Teddy-Zhu/magent/agent/internal/protocol"
	"github.com/Teddy-Zhu/magent/agent/internal/provider"
)

func TestHandleNotificationMapsCodexEventsToCanonicalEvents(t *testing.T) {
	tests := []struct {
		name       string
		method     string
		params     map[string]any
		wantType   provider.EventType
		wantItemID string
		wantOutput string
		wantPath   string
		wantAdd    int
		wantDel    int
		noStats    bool
	}{
		{
			name:     "agent message delta",
			method:   "item/agentMessage/delta",
			params:   map[string]any{"threadId": "thr_1", "itemId": "item_1", "delta": "hi"},
			wantType: provider.EventMessageDelta,
		},
		{
			name:     "thread closed emits canonical stopped status",
			method:   "thread/closed",
			params:   map[string]any{"threadId": "thr_1"},
			wantType: provider.EventSessionStatusChanged,
		},
		{
			name:   "command completed",
			method: "item/completed",
			params: map[string]any{
				"threadId": "thr_1",
				"item": map[string]any{
					"id":               "cmd_1",
					"type":             "commandExecution",
					"aggregatedOutput": "done",
					"exitCode":         float64(0),
				},
			},
			wantType:   provider.EventCommandCompleted,
			wantItemID: "cmd_1",
			wantOutput: "done",
		},
		{
			name:   "file change completed",
			method: "item/completed",
			params: map[string]any{
				"threadId": "thr_1",
				"item": map[string]any{
					"id":   "file_1",
					"type": "fileChange",
					"changes": []any{
						map[string]any{
							"path": "main.go",
							"kind": map[string]any{"type": "update"},
							"diff": strings.Join([]string{
								"--- a/main.go",
								"+++ b/main.go",
								"@@ -1 +1,2 @@",
								"-old",
								"+new",
								"+extra",
							}, "\n"),
						},
					},
				},
			},
			wantType:   provider.EventFileWrite,
			wantItemID: "file_1",
			wantPath:   "main.go",
			wantAdd:    2,
			wantDel:    1,
		},
		{
			name:   "file change completed without diff",
			method: "item/completed",
			params: map[string]any{
				"threadId": "thr_1",
				"item": map[string]any{
					"id":   "file_2",
					"type": "fileChange",
					"changes": []any{
						map[string]any{"path": "empty.go", "kind": "update"},
					},
				},
			},
			wantType:   provider.EventFileWrite,
			wantItemID: "file_2",
			wantPath:   "empty.go",
			noStats:    true,
		},
		{
			name:     "approval request without item",
			method:   "item/commandExecution/requestApproval",
			params:   map[string]any{"threadId": "thr_1", "itemId": "approval_1"},
			wantType: provider.EventApprovalRequest,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			client := &AppServerClient{
				events:        make(chan provider.ProviderEvent, 1),
				activeTurnIDs: make(map[string]string),
			}
			client.handleNotification(jsonRPCNotification(t, tt.method, tt.params))

			select {
			case event := <-client.Events():
				if event.Type != string(tt.wantType) {
					t.Fatalf("event type = %q, want %q", event.Type, tt.wantType)
				}
				if event.SessionID != "thr_1" {
					t.Fatalf("session id = %q, want thr_1", event.SessionID)
				}
				payload, ok := event.Payload.(map[string]any)
				if !ok {
					t.Fatalf("payload = %#v", event.Payload)
				}
				if tt.wantItemID != "" && payload["id"] != tt.wantItemID {
					t.Fatalf("payload id = %v, want %q", payload["id"], tt.wantItemID)
				}
				if tt.wantOutput != "" && payload["output"] != tt.wantOutput {
					t.Fatalf("payload output = %v, want %q", payload["output"], tt.wantOutput)
				}
				if tt.wantPath != "" && payload["path"] != tt.wantPath {
					t.Fatalf("payload path = %v, want %q", payload["path"], tt.wantPath)
				}
				if tt.wantAdd > 0 && payload["additions"] != tt.wantAdd {
					t.Fatalf("payload additions = %v, want %d", payload["additions"], tt.wantAdd)
				}
				if tt.wantDel > 0 && payload["deletions"] != tt.wantDel {
					t.Fatalf("payload deletions = %v, want %d", payload["deletions"], tt.wantDel)
				}
				if tt.noStats {
					if _, ok := payload["additions"]; ok {
						t.Fatalf("payload additions should be omitted: %#v", payload)
					}
					if _, ok := payload["deletions"]; ok {
						t.Fatalf("payload deletions should be omitted: %#v", payload)
					}
				}
				if tt.method == "thread/closed" {
					status, ok := payload["status"].(map[string]any)
					if !ok {
						t.Fatalf("payload status = %#v", payload["status"])
					}
					if status["type"] != string(provider.SessionStatusStopped) {
						t.Fatalf("status type = %v, want %q", status["type"], provider.SessionStatusStopped)
					}
				}
			case <-time.After(time.Second):
				t.Fatal("timed out waiting for event")
			}
		})
	}
}

func TestHandleNotificationClearsActiveTurnOnTerminalTurnEvents(t *testing.T) {
	for _, method := range []string{"turn/completed", "turn/failed"} {
		t.Run(method, func(t *testing.T) {
			client := &AppServerClient{
				events:        make(chan provider.ProviderEvent, 1),
				activeTurnIDs: map[string]string{"thr_1": "turn_1"},
			}
			client.handleNotification(jsonRPCNotification(t, method, map[string]any{
				"threadId": "thr_1",
				"turn":     map[string]any{"id": "turn_1"},
			}))

			client.activeTurnMu.Lock()
			_, ok := client.activeTurnIDs["thr_1"]
			client.activeTurnMu.Unlock()
			if ok {
				t.Fatalf("active turn was not cleared for %s", method)
			}
		})
	}
}

func TestHookCompletedBlockedEmitsErrorEvent(t *testing.T) {
	client := &AppServerClient{
		events:        make(chan provider.ProviderEvent, 1),
		activeTurnIDs: make(map[string]string),
	}
	client.handleNotification(jsonRPCNotification(t, "hook/completed", map[string]any{
		"threadId": "thr_1",
		"turnId":   "turn_1",
		"run": map[string]any{
			"id":            "user-prompt-submit:0:/repo/.codex/hooks.json",
			"status":        "blocked",
			"statusMessage": "Sending notification",
			"entries": []any{
				map[string]any{"kind": "feedback", "text": "missing hook script"},
			},
		},
	}))

	select {
	case event := <-client.Events():
		if event.Type != string(provider.EventError) {
			t.Fatalf("event type = %q, want error", event.Type)
		}
		if event.SessionID != "thr_1" {
			t.Fatalf("session id = %q, want thr_1", event.SessionID)
		}
		payload, ok := event.Payload.(map[string]any)
		if !ok {
			t.Fatalf("payload = %#v", event.Payload)
		}
		if payload["message"] != "missing hook script" {
			t.Fatalf("message = %v", payload["message"])
		}
	case <-time.After(time.Second):
		t.Fatal("timed out waiting for error event")
	}
}

func TestSessionStatusEventClosesOnlySessionTerminalStates(t *testing.T) {
	openEvent := provider.ProviderEvent{
		Type:    string(provider.EventSessionStatusChanged),
		Payload: map[string]any{"status": map[string]any{"type": "completed"}},
	}
	if eventClosesSession(openEvent) {
		t.Fatal("completed turn status should not close an active session")
	}

	closedEvent := provider.ProviderEvent{
		Type:    string(provider.EventSessionStatusChanged),
		Payload: map[string]any{"status": map[string]any{"type": "stopped"}},
	}
	if !eventClosesSession(closedEvent) {
		t.Fatal("stopped session status should close the active session")
	}
}

func TestQueuedInputPreservesOrderWhenDrainFindsActiveTurn(t *testing.T) {
	p := &CodexProvider{queuedInputs: make(map[string][]queuedInput)}
	p.enqueueInput("session_1", "thread_1", provider.SendInputRequest{Input: "first"})
	p.enqueueInput("session_1", "thread_1", provider.SendInputRequest{Input: "second"})

	p.queueMu.Lock()
	next := p.queuedInputs["session_1"][0]
	p.queuedInputs["session_1"] = p.queuedInputs["session_1"][1:]
	p.queueMu.Unlock()
	p.prependQueuedInput(next)

	p.queueMu.Lock()
	queue := p.queuedInputs["session_1"]
	p.queueMu.Unlock()
	if len(queue) != 2 {
		t.Fatalf("queue length = %d, want 2", len(queue))
	}
	if queue[0].input.Input != "first" || queue[1].input.Input != "second" {
		t.Fatalf("queue order = %#v", queue)
	}
}

func TestQueueDrainAllowsOnlyOneActiveDrainer(t *testing.T) {
	p := &CodexProvider{}
	if !p.beginQueueDrain("session_1") {
		t.Fatal("first drain should start")
	}
	if p.beginQueueDrain("session_1") {
		t.Fatal("second drain should be rejected while first is active")
	}
	p.endQueueDrain("session_1")
	if !p.beginQueueDrain("session_1") {
		t.Fatal("drain should start again after previous drain ended")
	}
}

func jsonRPCNotification(t *testing.T, method string, params map[string]any) *protocol.JSONRPCResponse {
	t.Helper()
	data, err := json.Marshal(params)
	if err != nil {
		t.Fatalf("marshal params: %v", err)
	}
	return &protocol.JSONRPCResponse{
		JSONRPC: "2.0",
		Method:  method,
		Params:  data,
	}
}
