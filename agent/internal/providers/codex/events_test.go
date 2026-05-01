package codex

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/magent/agent/internal/protocol"
	"github.com/magent/agent/internal/provider"
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
						map[string]any{"path": "main.go", "kind": "modify"},
					},
				},
			},
			wantType:   provider.EventFileWrite,
			wantItemID: "file_1",
			wantPath:   "main.go",
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
