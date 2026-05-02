package session

import (
	"testing"

	"github.com/Teddy-Zhu/magent/agent/internal/provider"
	"github.com/Teddy-Zhu/magent/agent/internal/storage"
)

func TestSessionStoreSavesControlPlaneMetadata(t *testing.T) {
	db, err := storage.Open(":memory:")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer db.Close()

	store := NewSessionStore(db)
	input := &provider.Session{
		ID:             "s1",
		ProviderID:     "codex",
		ThreadID:       "thr_1",
		ProjectID:      "p1",
		Purpose:        string(provider.SessionPurposeAICommit),
		Title:          "Test",
		Workdir:        "/tmp/project",
		Status:         string(provider.SessionStatusRunning),
		RunnerType:     "app-server",
		Model:          "gpt-5.4",
		ApprovalPolicy: string(provider.ApprovalPolicyOnRequest),
		SandboxMode:    string(provider.SandboxModeWorkspaceWrite),
	}

	if err := store.Save(input); err != nil {
		t.Fatalf("save: %v", err)
	}

	got, err := store.Get("s1")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if got == nil {
		t.Fatal("expected session")
	}
	if got.ThreadID != input.ThreadID || got.ProjectID != input.ProjectID || got.Workdir != input.Workdir {
		t.Fatalf("metadata mismatch: got %#v", got)
	}
	if got.Purpose != input.Purpose {
		t.Fatalf("purpose mismatch: got %q", got.Purpose)
	}
	if got.Status != input.Status {
		t.Fatalf("last observed status mismatch: got %q", got.Status)
	}
	if got.ApprovalPolicy != input.ApprovalPolicy || got.SandboxMode != input.SandboxMode {
		t.Fatalf("policy metadata mismatch: got approval=%q sandbox=%q", got.ApprovalPolicy, got.SandboxMode)
	}
}

func TestSessionStoreNormalizesProviderWireMetadata(t *testing.T) {
	db, err := storage.Open(":memory:")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer db.Close()

	store := NewSessionStore(db)
	input := &provider.Session{
		ID:             "s1",
		ProviderID:     "codex",
		ThreadID:       "thr_1",
		ProjectID:      "p1",
		Status:         "active",
		ApprovalPolicy: "onRequest",
		SandboxMode:    "workspaceWrite",
	}

	if err := store.Save(input); err != nil {
		t.Fatalf("save: %v", err)
	}

	got, err := store.Get("s1")
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if got == nil {
		t.Fatal("expected session")
	}
	if got.Status != string(provider.SessionStatusRunning) {
		t.Fatalf("status = %q, want %q", got.Status, provider.SessionStatusRunning)
	}
	if got.ApprovalPolicy != string(provider.ApprovalPolicyOnRequest) {
		t.Fatalf("approval = %q, want %q", got.ApprovalPolicy, provider.ApprovalPolicyOnRequest)
	}
	if got.SandboxMode != string(provider.SandboxModeWorkspaceWrite) {
		t.Fatalf("sandbox = %q, want %q", got.SandboxMode, provider.SandboxModeWorkspaceWrite)
	}
}
