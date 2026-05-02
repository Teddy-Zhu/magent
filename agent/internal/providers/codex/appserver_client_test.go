package codex

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"strings"
	"testing"
	"time"

	"github.com/Teddy-Zhu/magent/agent/internal/protocol"
	"github.com/Teddy-Zhu/magent/agent/internal/provider"
)

func TestCodexApprovalPolicyMapping(t *testing.T) {
	tests := map[string]string{
		"":               "on-request",
		"on-request":     "on-request",
		"onRequest":      "on-request",
		"untrusted":      "untrusted",
		"unless-trusted": "untrusted",
		"unlessTrusted":  "untrusted",
		"on-failure":     "on-failure",
		"onFailure":      "on-failure",
		"granular":       "granular",
		"never":          "never",
		"custom":         "custom",
	}

	for input, want := range tests {
		if got := codexApprovalPolicy(input); got != want {
			t.Fatalf("codexApprovalPolicy(%q) = %q, want %q", input, got, want)
		}
	}
}

func TestThreadStatusUnmarshalAcceptsStringAndObject(t *testing.T) {
	var stringStatus ThreadStatus
	if err := json.Unmarshal([]byte(`"active"`), &stringStatus); err != nil {
		t.Fatalf("unmarshal string status: %v", err)
	}
	if stringStatus.Type != "active" {
		t.Fatalf("string status type = %q, want active", stringStatus.Type)
	}

	var objectStatus ThreadStatus
	if err := json.Unmarshal([]byte(`{"type":"active","activeFlags":["waitingOnApproval"]}`), &objectStatus); err != nil {
		t.Fatalf("unmarshal object status: %v", err)
	}
	if objectStatus.Type != "active" {
		t.Fatalf("object status type = %q, want active", objectStatus.Type)
	}
	if len(objectStatus.ActiveFlags) != 1 || objectStatus.ActiveFlags[0] != "waitingOnApproval" {
		t.Fatalf("object status flags = %#v", objectStatus.ActiveFlags)
	}
}

func TestCodexSandboxModeMapping(t *testing.T) {
	tests := map[string]string{
		"":                   "workspace-write",
		"workspace-write":    "workspace-write",
		"workspaceWrite":     "workspace-write",
		"read-only":          "read-only",
		"readOnly":           "read-only",
		"danger-full-access": "danger-full-access",
		"dangerFullAccess":   "danger-full-access",
		"externalSandbox":    "externalSandbox",
	}

	for input, want := range tests {
		if got := codexSandboxMode(input); got != want {
			t.Fatalf("codexSandboxMode(%q) = %q, want %q", input, got, want)
		}
	}
}

func TestCodexSandboxPolicyTypeMapping(t *testing.T) {
	tests := map[string]string{
		"":                   "workspaceWrite",
		"workspace-write":    "workspaceWrite",
		"workspaceWrite":     "workspaceWrite",
		"read-only":          "readOnly",
		"readOnly":           "readOnly",
		"danger-full-access": "dangerFullAccess",
		"dangerFullAccess":   "dangerFullAccess",
		"externalSandbox":    "externalSandbox",
	}

	for input, want := range tests {
		if got := codexSandboxPolicyType(input); got != want {
			t.Fatalf("codexSandboxPolicyType(%q) = %q, want %q", input, got, want)
		}
	}
}

func TestSandboxPolicyObject(t *testing.T) {
	workspace := sandboxPolicyObject("workspace-write", "/repo")
	if workspace["type"] != "workspaceWrite" {
		t.Fatalf("workspace policy type = %v", workspace["type"])
	}
	roots, ok := workspace["writableRoots"].([]string)
	if !ok || len(roots) != 1 || roots[0] != "/repo" {
		t.Fatalf("workspace policy roots = %#v", workspace["writableRoots"])
	}

	emptyCWD := sandboxPolicyObject("workspace-write", "")
	if _, ok := emptyCWD["writableRoots"]; ok {
		t.Fatalf("workspace policy with empty cwd should omit writableRoots: %#v", emptyCWD)
	}

	readOnly := sandboxPolicyObject("read-only", "/repo")
	if readOnly["type"] != "readOnly" {
		t.Fatalf("read-only policy type = %v", readOnly["type"])
	}

	danger := sandboxPolicyObject("danger-full-access", "/repo")
	if danger["type"] != "dangerFullAccess" {
		t.Fatalf("danger policy type = %v", danger["type"])
	}
}

func TestStartThreadUsesWireEnums(t *testing.T) {
	client, server := newTestAppServerClient(t)
	defer client.Close()

	done := make(chan struct{})
	go func() {
		defer close(done)
		req := server.readRequest(t)
		if req.Method != "thread/start" || req.ID == nil {
			t.Fatalf("request = %#v", req)
		}
		params := requestParams(t, req)
		if params["approvalPolicy"] != "on-request" {
			t.Fatalf("approvalPolicy = %v", params["approvalPolicy"])
		}
		if params["sandbox"] != "workspace-write" {
			t.Fatalf("sandbox = %v", params["sandbox"])
		}
		if params["persistExtendedHistory"] != true {
			t.Fatalf("persistExtendedHistory = %v", params["persistExtendedHistory"])
		}
		server.writeResponse(t, *req.ID, map[string]any{
			"thread": map[string]any{"id": "thread_1"},
		})
	}()

	threadID, err := client.StartThread(context.Background(), "gpt-5.5", "/repo", "onRequest", "workspaceWrite")
	if err != nil {
		t.Fatalf("StartThread: %v", err)
	}
	if threadID != "thread_1" {
		t.Fatalf("threadID = %q", threadID)
	}
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("fake server did not receive thread/start")
	}
}

func TestForkThreadPersistsExtendedHistory(t *testing.T) {
	client, server := newTestAppServerClient(t)
	defer client.Close()

	done := make(chan struct{})
	go func() {
		defer close(done)
		req := server.readRequest(t)
		if req.Method != "thread/fork" || req.ID == nil {
			t.Fatalf("request = %#v", req)
		}
		params := requestParams(t, req)
		if params["threadId"] != "thread_1" {
			t.Fatalf("threadId = %v", params["threadId"])
		}
		if params["persistExtendedHistory"] != true {
			t.Fatalf("persistExtendedHistory = %v", params["persistExtendedHistory"])
		}
		server.writeResponse(t, *req.ID, map[string]any{
			"thread": map[string]any{"id": "thread_2"},
		})
	}()

	threadID, err := client.ForkThread(context.Background(), "thread_1")
	if err != nil {
		t.Fatalf("ForkThread: %v", err)
	}
	if threadID != "thread_2" {
		t.Fatalf("threadID = %q", threadID)
	}
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("fake server did not receive thread/fork")
	}
}

func TestStartTurnUsesWireEnumsAndModel(t *testing.T) {
	client, server := newTestAppServerClient(t)
	defer client.Close()

	done := make(chan struct{})
	go func() {
		defer close(done)
		req := server.readRequest(t)
		if req.Method != "turn/start" || req.ID == nil {
			t.Fatalf("request = %#v", req)
		}
		params := requestParams(t, req)
		if params["model"] != "gpt-5.5" {
			t.Fatalf("model = %v", params["model"])
		}
		if params["approvalPolicy"] != "on-request" {
			t.Fatalf("approvalPolicy = %v", params["approvalPolicy"])
		}
		sandbox, ok := params["sandboxPolicy"].(map[string]any)
		if !ok {
			t.Fatalf("sandboxPolicy = %#v", params["sandboxPolicy"])
		}
		if sandbox["type"] != "workspaceWrite" {
			t.Fatalf("sandbox type = %v", sandbox["type"])
		}
		server.writeResponse(t, *req.ID, map[string]any{
			"turn": map[string]any{"id": "turn_1"},
		})
	}()

	turnID, err := client.StartTurn(context.Background(), "thread_1", codexTextInput("hi", nil), "/repo", "onRequest", "workspaceWrite", "gpt-5.5", "low")
	if err != nil {
		t.Fatalf("StartTurn: %v", err)
	}
	if turnID != "turn_1" {
		t.Fatalf("turnID = %q", turnID)
	}
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("fake server did not receive turn/start")
	}
}

func TestListThreadTurnsAcceptsObjectChangeKind(t *testing.T) {
	client, server := newTestAppServerClient(t)
	defer client.Close()

	done := make(chan struct{})
	go func() {
		defer close(done)
		req := server.readRequest(t)
		if req.Method != "thread/turns/list" || req.ID == nil {
			t.Fatalf("request = %#v", req)
		}
		server.writeResponse(t, *req.ID, map[string]any{
			"data": []any{
				map[string]any{
					"id":     "turn_1",
					"status": "completed",
					"items": []any{
						map[string]any{
							"id":   "file_1",
							"type": "fileChange",
							"changes": []any{
								map[string]any{
									"path": "main.go",
									"kind": map[string]any{"type": "modify"},
								},
							},
						},
					},
				},
			},
		})
	}()

	page, err := client.ListThreadTurns(context.Background(), "thread_1", "", 20, "desc")
	if err != nil {
		t.Fatalf("ListThreadTurns: %v", err)
	}
	if len(page.Turns) != 1 || len(page.Turns[0].Items) != 1 {
		t.Fatalf("turns = %#v", page.Turns)
	}
	kind := page.Turns[0].Items[0].Changes[0].Kind
	if kind.Type != "modify" {
		t.Fatalf("change kind type = %q, want modify", kind.Type)
	}
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("fake server did not receive thread/turns/list")
	}
}

func TestListThreadsPreservesCWD(t *testing.T) {
	client, server := newTestAppServerClient(t)
	defer client.Close()

	done := make(chan struct{})
	go func() {
		defer close(done)
		req := server.readRequest(t)
		if req.Method != "thread/list" || req.ID == nil {
			t.Fatalf("request = %#v", req)
		}
		server.writeResponse(t, *req.ID, map[string]any{
			"data": []any{
				map[string]any{
					"id":        "thread_1",
					"preview":   "hello",
					"cwd":       "/home/teddyhp/code/python_web_template",
					"createdAt": float64(1777702095),
					"updatedAt": float64(1777702632),
					"status":    map[string]any{"type": "notLoaded"},
				},
			},
		})
	}()

	threads, err := client.ListThreads(context.Background(), "", 20)
	if err != nil {
		t.Fatalf("ListThreads: %v", err)
	}
	if len(threads) != 1 {
		t.Fatalf("threads len = %d, want 1", len(threads))
	}
	if threads[0].CWD != "/home/teddyhp/code/python_web_template" {
		t.Fatalf("cwd = %q", threads[0].CWD)
	}
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("fake server did not receive thread/list")
	}
}

func TestListThreadsWithOptionsRequestsArchivedVscodeThreads(t *testing.T) {
	client, server := newTestAppServerClient(t)
	defer client.Close()

	done := make(chan struct{})
	go func() {
		defer close(done)
		req := server.readRequest(t)
		if req.Method != "thread/list" || req.ID == nil {
			t.Fatalf("request = %#v", req)
		}
		params := requestParams(t, req)
		if archived, ok := params["archived"].(bool); !ok || !archived {
			t.Fatalf("archived param = %#v, want true", params["archived"])
		}
		if cwd, ok := params["cwd"].(string); !ok || cwd != "/repo" {
			t.Fatalf("cwd param = %#v, want /repo", params["cwd"])
		}
		rawSourceKinds, ok := params["sourceKinds"].([]any)
		if !ok {
			t.Fatalf("sourceKinds param = %#v", params["sourceKinds"])
		}
		sourceKinds := make(map[string]bool, len(rawSourceKinds))
		for _, raw := range rawSourceKinds {
			sourceKinds[fmt.Sprint(raw)] = true
		}
		for _, want := range []string{"cli", "vscode", "appServer"} {
			if !sourceKinds[want] {
				t.Fatalf("sourceKinds = %#v, missing %q", rawSourceKinds, want)
			}
		}
		if sourceKinds["archived"] {
			t.Fatalf("sourceKinds = %#v, archived is not a source kind", rawSourceKinds)
		}
		server.writeResponse(t, *req.ID, map[string]any{
			"data": []any{
				map[string]any{
					"id":        "thread_archived",
					"preview":   "archived thread",
					"cwd":       "/repo",
					"createdAt": float64(1777702095),
					"updatedAt": float64(1777702632),
					"status":    map[string]any{"type": "notLoaded"},
				},
			},
		})
	}()

	threads, err := client.ListThreadsWithOptions(context.Background(), ListThreadsOptions{
		CWD:      "/repo",
		Limit:    20,
		Archived: true,
	})
	if err != nil {
		t.Fatalf("ListThreadsWithOptions: %v", err)
	}
	if len(threads) != 1 || threads[0].ID != "thread_archived" {
		t.Fatalf("threads = %#v", threads)
	}
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("fake server did not receive thread/list")
	}
}

func TestCodexTurnsToItemsPreservesOrderIndexAndFileStats(t *testing.T) {
	exitCode := 1
	items := codexTurnsToItems([]ThreadTurn{
		{
			ID:          "turn_1",
			Status:      "completed",
			StartedAt:   100,
			CompletedAt: 101,
			Items: []TurnItem{
				{ID: "msg_1", Type: "agentMessage", Text: "done"},
				{
					ID:   "file_1",
					Type: "fileChange",
					Changes: []TurnItemChange{
						{
							Path: "main.go",
							Kind: ChangeKind{Type: "update"},
							Diff: strings.Join([]string{
								"--- a/main.go",
								"+++ b/main.go",
								"@@ -1,2 +1,3 @@",
								" package main",
								"-old",
								"+new",
								"+extra",
							}, "\n"),
						},
					},
				},
			},
		},
		{
			ID:        "turn_2",
			Status:    "completed",
			StartedAt: 102,
			Items: []TurnItem{
				{ID: "msg_2", Type: "agentMessage", Text: "next"},
				{
					ID:               "cmd_1",
					Type:             "commandExecution",
					Command:          []any{"go", "test", "./..."},
					CWD:              "/repo",
					Status:           "failed",
					AggregatedOutput: "FAIL",
					ExitCode:         &exitCode,
					Raw: map[string]any{
						"id": "cmd_1",
						"commandActions": []any{
							map[string]any{"type": "rerun"},
						},
					},
				},
			},
		},
	})

	if len(items) != 4 {
		t.Fatalf("items len = %d, want 4", len(items))
	}
	if items[0].Index != 10000000 || items[1].Index != 10000001 || items[2].Index != 10200000 || items[3].Index != 10200001 {
		t.Fatalf("item indexes = [%d %d %d %d], want [10000000 10000001 10200000 10200001]", items[0].Index, items[1].Index, items[2].Index, items[3].Index)
	}
	content, ok := items[1].Content.(map[string]any)
	if !ok {
		t.Fatalf("file content = %#v", items[1].Content)
	}
	if content["path"] != "main.go" {
		t.Fatalf("path = %v, want main.go", content["path"])
	}
	if content["kind"] != "update" {
		t.Fatalf("kind = %v, want update", content["kind"])
	}
	if content["additions"] != 2 || content["deletions"] != 1 {
		t.Fatalf("stats = +%v -%v, want +2 -1", content["additions"], content["deletions"])
	}
	if content["diff"] == "" {
		t.Fatal("diff should be preserved")
	}
	cmdContent, ok := items[3].Content.(map[string]any)
	if !ok {
		t.Fatalf("command content = %#v", items[3].Content)
	}
	if got := fmt.Sprint(cmdContent["command"]); !strings.Contains(got, "go") || !strings.Contains(got, "test") {
		t.Fatalf("command = %v, want go test", cmdContent["command"])
	}
	if cmdContent["cwd"] != "/repo" {
		t.Fatalf("cwd = %v, want /repo", cmdContent["cwd"])
	}
	if cmdContent["status"] != "failed" {
		t.Fatalf("status = %v, want failed", cmdContent["status"])
	}
	if cmdContent["aggregatedOutput"] != "FAIL" || cmdContent["output"] != "FAIL" {
		t.Fatalf("output fields = aggregated:%v output:%v, want FAIL", cmdContent["aggregatedOutput"], cmdContent["output"])
	}
	if cmdContent["exitCode"] != 1 || cmdContent["exit_code"] != 1 {
		t.Fatalf("exit fields = exitCode:%v exit_code:%v, want 1", cmdContent["exitCode"], cmdContent["exit_code"])
	}
	if _, ok := cmdContent["commandActions"].([]any); !ok {
		t.Fatalf("commandActions = %#v, want preserved list", cmdContent["commandActions"])
	}
}

func TestCodexTurnsToItemsPreservesAppServerToolCallIDs(t *testing.T) {
	exitCode := 0
	items := codexTurnsToItems([]ThreadTurn{
		{
			ID:          "019de8f9-4c06-71b1-9e71-d7580f935ef3",
			Status:      "failed",
			StartedAt:   1777730145,
			CompletedAt: 1777730707,
			Items: []TurnItem{
				{
					ID:     "call_50BanriSB8wfP52Zwql6mnbN",
					Type:   "fileChange",
					Status: "completed",
					Changes: []TurnItemChange{
						{
							Path: "/home/teddyhp/code/python_web_template/docs/dev/prepare/enginev4综合优化实施计划.md",
							Kind: ChangeKind{Type: "update"},
							Diff: "@@ -271,2 +271,3 @@\n+类型落位：\n",
						},
					},
				},
				{
					ID:               "call_9aeFf1ciI8rUGMFPARv8L5PM",
					Type:             "commandExecution",
					Status:           "completed",
					Command:          `/usr/bin/zsh -lc "nl -ba docs/dev/prepare/enginev4综合优化实施计划.md | sed -n '990,1040p'"`,
					CWD:              "/home/teddyhp/code/python_web_template",
					AggregatedOutput: "   990\tDivergenceIndex int\n",
					ExitCode:         &exitCode,
				},
				{
					ID:               "call_FcpXP8t6AwbUOO6obYCuhMbB",
					Type:             "commandExecution",
					Status:           "completed",
					Command:          `/usr/bin/zsh -lc "nl -ba docs/dev/prepare/enginev4综合优化实施计划.md | sed -n '1065,1118p'"`,
					CWD:              "/home/teddyhp/code/python_web_template",
					AggregatedOutput: "  1065\tmetrics.go\n",
					ExitCode:         &exitCode,
				},
			},
		},
	})

	if len(items) != 3 {
		t.Fatalf("items len = %d, want 3", len(items))
	}
	if items[1].ItemID != "call_9aeFf1ciI8rUGMFPARv8L5PM" || items[1].Type != string(provider.ItemTypeCommandExecution) {
		t.Fatalf("command item = %#v", items[1])
	}
	if items[2].ItemID != "call_FcpXP8t6AwbUOO6obYCuhMbB" || items[2].Type != string(provider.ItemTypeCommandExecution) {
		t.Fatalf("command item = %#v", items[2])
	}
	content, ok := items[2].Content.(map[string]any)
	if !ok {
		t.Fatalf("content = %#v", items[2].Content)
	}
	if content["output"] != "  1065\tmetrics.go\n" {
		t.Fatalf("output = %#v", content["output"])
	}
	fileContent, ok := items[0].Content.(map[string]any)
	if !ok {
		t.Fatalf("file content = %#v", items[0].Content)
	}
	if fileContent["diff"] == "" {
		t.Fatal("file diff should be preserved")
	}
}

func TestCodexListedThreadStatusRequiresActiveSessionForRunning(t *testing.T) {
	tests := []struct {
		name   string
		status ThreadStatus
		active bool
		want   string
	}{
		{
			name:   "idle historical thread is stopped",
			status: ThreadStatus{Type: "idle"},
			active: false,
			want:   string(provider.SessionStatusStopped),
		},
		{
			name:   "idle active provider session is running",
			status: ThreadStatus{Type: "idle"},
			active: true,
			want:   string(provider.SessionStatusRunning),
		},
		{
			name:   "active provider session is running",
			status: ThreadStatus{Type: "active"},
			active: true,
			want:   string(provider.SessionStatusRunning),
		},
		{
			name:   "system error active session is still input-capable",
			status: ThreadStatus{Type: "systemError"},
			active: true,
			want:   string(provider.SessionStatusRunning),
		},
		{
			name:   "completed active session is still input-capable",
			status: ThreadStatus{Type: "completed"},
			active: true,
			want:   string(provider.SessionStatusRunning),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := codexListedThreadStatus(tt.status, tt.active)
			if got != tt.want {
				t.Fatalf("status = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestProviderCloseUnsubscribesActiveThreads(t *testing.T) {
	client, server := newTestAppServerClient(t)
	p := New(CodexConfig{}, nil, nil)
	p.client = client
	p.threadIDs["session_1"] = "thread_1"
	p.threadIDs["session_2"] = "thread_2"
	p.threadIDs["session_3"] = "thread_2"

	done := make(chan map[string]int, 1)
	go func() {
		seen := make(map[string]int)
		for len(seen) < 2 {
			req := server.readRequest(t)
			if req.Method != "thread/unsubscribe" || req.ID == nil {
				t.Fatalf("request = %#v", req)
			}
			params := requestParams(t, req)
			threadID, _ := params["threadId"].(string)
			if threadID == "" {
				t.Fatalf("threadId params = %#v", params)
			}
			seen[threadID]++
			server.writeResponse(t, *req.ID, map[string]any{"status": "unsubscribed"})
		}
		done <- seen
	}()

	if err := p.Close(); err != nil {
		t.Fatalf("Close: %v", err)
	}

	select {
	case seen := <-done:
		if seen["thread_1"] != 1 || seen["thread_2"] != 1 {
			t.Fatalf("unsubscribe calls = %#v, want one per active thread", seen)
		}
	case <-time.After(time.Second):
		t.Fatal("timed out waiting for unsubscribe calls")
	}
	if p.client != nil {
		t.Fatal("provider client should be cleared after close")
	}
}

func TestProviderResumeSessionPersistsExtendedHistory(t *testing.T) {
	client, server := newTestAppServerClient(t)
	p := New(CodexConfig{}, nil, nil)
	p.client = client
	p.meta["session_1"] = &sessionMeta{Model: "gpt-5.5"}
	defer client.Close()

	done := make(chan struct{})
	go func() {
		defer close(done)
		req := server.readRequest(t)
		if req.Method != "thread/resume" || req.ID == nil {
			t.Fatalf("request = %#v", req)
		}
		params := requestParams(t, req)
		if params["threadId"] != "thread_1" {
			t.Fatalf("threadId = %v", params["threadId"])
		}
		if params["persistExtendedHistory"] != true {
			t.Fatalf("persistExtendedHistory = %v", params["persistExtendedHistory"])
		}
		server.writeResponse(t, *req.ID, map[string]any{
			"thread": map[string]any{"id": "thread_1"},
		})
	}()

	if err := p.ResumeSession(context.Background(), "session_1", "thread_1"); err != nil {
		t.Fatalf("ResumeSession: %v", err)
	}
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("fake server did not receive thread/resume")
	}
}

func TestAppServerClientInitializeAndInitializedNotification(t *testing.T) {
	client, server := newTestAppServerClient(t)
	defer client.Close()

	done := make(chan struct{})
	go func() {
		defer close(done)
		req := server.readRequest(t)
		if req.Method != "initialize" || req.ID == nil {
			t.Fatalf("first request = %#v", req)
		}
		server.writeResponse(t, *req.ID, map[string]any{"serverInfo": map[string]any{"name": "fake"}})

		notify := server.readRequest(t)
		if notify.Method != "initialized" || notify.ID != nil {
			t.Fatalf("second request should be initialized notification, got %#v", notify)
		}
	}()

	if err := client.Initialize(context.Background()); err != nil {
		t.Fatalf("initialize: %v", err)
	}
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("fake server did not receive initialize flow")
	}
}

func TestAppServerClientRoutesServerRequestAndNotification(t *testing.T) {
	client, server := newTestAppServerClient(t)
	defer client.Close()

	server.writeRaw(t, `{"jsonrpc":"2.0","id":77,"method":"item/commandExecution/requestApproval","params":{"threadId":"thr_1","itemId":"item_1"}}`)
	server.writeRaw(t, `{"jsonrpc":"2.0","method":"thread/started","params":{"threadId":"thr_1"}}`)

	select {
	case req := <-client.ServerRequests():
		if req.Method != "item/commandExecution/requestApproval" || req.ID == nil || *req.ID != 77 {
			t.Fatalf("server request = %#v", req)
		}
	case <-time.After(time.Second):
		t.Fatal("timed out waiting for server request")
	}

	select {
	case event := <-client.Events():
		if event.Type != "session.started" || event.SessionID != "thr_1" {
			t.Fatalf("event = %#v", event)
		}
	case <-time.After(time.Second):
		t.Fatal("timed out waiting for notification event")
	}
}

type testPipeConn struct {
	reader *io.PipeReader
	writer *io.PipeWriter
}

func (c *testPipeConn) Read(p []byte) (int, error)  { return c.reader.Read(p) }
func (c *testPipeConn) Write(p []byte) (int, error) { return c.writer.Write(p) }
func (c *testPipeConn) Close() error {
	c.reader.Close()
	return c.writer.Close()
}

type testAppServer struct {
	scanner *bufio.Scanner
	writer  *io.PipeWriter
}

func newTestAppServerClient(t *testing.T) (*AppServerClient, *testAppServer) {
	t.Helper()
	clientRead, serverWrite := io.Pipe()
	serverRead, clientWrite := io.Pipe()
	client := &AppServerClient{
		transport:      TransportStdio,
		conn:           &testPipeConn{reader: clientRead, writer: clientWrite},
		reqIDGen:       &protocol.RequestIDGenerator{},
		pending:        make(map[int64]*pendingRequest),
		events:         make(chan provider.ProviderEvent, 4),
		serverRequests: make(chan *protocol.JSONRPCResponse, 4),
		done:           make(chan struct{}),
		readDone:       make(chan struct{}),
		processDone:    make(chan struct{}),
		activeTurnIDs:  make(map[string]string),
	}
	go client.readLoop()
	return client, &testAppServer{
		scanner: bufio.NewScanner(serverRead),
		writer:  serverWrite,
	}
}

func (s *testAppServer) readRequest(t *testing.T) protocol.JSONRPCRequest {
	t.Helper()
	if !s.scanner.Scan() {
		t.Fatalf("read request: %v", s.scanner.Err())
	}
	var req protocol.JSONRPCRequest
	if err := json.Unmarshal(s.scanner.Bytes(), &req); err != nil {
		t.Fatalf("unmarshal request %q: %v", s.scanner.Text(), err)
	}
	return req
}

func requestParams(t *testing.T, req protocol.JSONRPCRequest) map[string]any {
	t.Helper()
	data, err := json.Marshal(req.Params)
	if err != nil {
		t.Fatalf("marshal params: %v", err)
	}
	var params map[string]any
	if err := json.Unmarshal(data, &params); err != nil {
		t.Fatalf("unmarshal params: %v", err)
	}
	return params
}

func (s *testAppServer) writeResponse(t *testing.T, id int64, result any) {
	t.Helper()
	data, err := json.Marshal(map[string]any{
		"jsonrpc": "2.0",
		"id":      id,
		"result":  result,
	})
	if err != nil {
		t.Fatalf("marshal response: %v", err)
	}
	s.writeRaw(t, string(data))
}

func (s *testAppServer) writeRaw(t *testing.T, line string) {
	t.Helper()
	if !strings.HasSuffix(line, "\n") {
		line += "\n"
	}
	if _, err := io.WriteString(s.writer, line); err != nil {
		t.Fatalf("write raw: %v", err)
	}
}
