package session

import (
	"context"
	"fmt"
	"strings"
	"testing"

	"github.com/Teddy-Zhu/magent/agent/internal/provider"
	"github.com/Teddy-Zhu/magent/agent/internal/storage"
	"github.com/Teddy-Zhu/magent/agent/internal/ws"
)

func TestCreateSessionRequestProviderName(t *testing.T) {
	tests := []struct {
		name string
		req  CreateSessionRequest
		want string
	}{
		{
			name: "uses canonical provider id",
			req:  CreateSessionRequest{ProviderID: "codex", Provider: "legacy"},
			want: "codex",
		},
		{
			name: "falls back to legacy provider",
			req:  CreateSessionRequest{Provider: "codex"},
			want: "codex",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := tt.req.ProviderName(); got != tt.want {
				t.Fatalf("ProviderName() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestCreateSessionRequestValidateRequiresProviderIDOrLegacyProvider(t *testing.T) {
	if err := (CreateSessionRequest{ProjectID: "p1"}).Validate(); err == nil {
		t.Fatal("Validate should require provider_id")
	}
	if err := (CreateSessionRequest{ProviderID: "codex", ProjectID: "p1"}).Validate(); err != nil {
		t.Fatalf("Validate canonical provider_id: %v", err)
	}
	if err := (CreateSessionRequest{Provider: "codex", ProjectID: "p1"}).Validate(); err != nil {
		t.Fatalf("Validate legacy provider: %v", err)
	}
}

func TestListSessionsUsesProviderAsSourceOfTruth(t *testing.T) {
	db, err := storage.Open(":memory:")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer db.Close()

	store := NewSessionStore(db)
	for _, sess := range []*provider.Session{
		{
			ID:         "active-empty-session",
			ProviderID: "codex",
			ThreadID:   "active-empty-session",
			ProjectID:  "p1",
			Workdir:    "/tmp/project",
			Status:     string(provider.SessionStatusRunning),
		},
		{
			ID:         "inactive-session",
			ProviderID: "codex",
			ThreadID:   "inactive-session",
			ProjectID:  "p1",
			Workdir:    "/tmp/project",
			Status:     string(provider.SessionStatusRunning),
		},
	} {
		if err := store.Save(sess); err != nil {
			t.Fatalf("save %s: %v", sess.ID, err)
		}
	}

	registry := provider.NewRegistry()
	registry.Register("codex", &managerTestProvider{
		name: "codex",
		active: map[string]bool{
			"active-empty-session": true,
		},
	})
	manager := NewManager(store, registry, ws.NewHub())

	got, err := manager.ListSessions(context.Background(), "p1", "codex", "/tmp/project", false)
	if err != nil {
		t.Fatalf("ListSessions: %v", err)
	}

	statuses := map[string]string{}
	for _, sess := range got {
		statuses[sess.ID] = sess.Status
	}

	if statuses["active-empty-session"] != string(provider.SessionStatusRunning) {
		t.Fatalf("active omitted session status = %q, want running; sessions=%#v", statuses["active-empty-session"], got)
	}
	if _, ok := statuses["inactive-session"]; ok {
		t.Fatalf("inactive DB-only session should not be listed; sessions=%#v", got)
	}
}

func TestGetSessionUsesProviderAsSourceOfTruth(t *testing.T) {
	db, err := storage.Open(":memory:")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer db.Close()

	store := NewSessionStore(db)
	for _, sess := range []*provider.Session{
		{
			ID:         "active-empty-session",
			ProviderID: "codex",
			ThreadID:   "active-empty-session",
			ProjectID:  "p1",
			Workdir:    "/tmp/project",
			Status:     string(provider.SessionStatusStopped),
		},
		{
			ID:         "listed-session",
			ProviderID: "codex",
			ThreadID:   "listed-session",
			ProjectID:  "p1",
			Workdir:    "/tmp/project",
			Status:     string(provider.SessionStatusRunning),
		},
		{
			ID:         "stale-session",
			ProviderID: "codex",
			ThreadID:   "stale-session",
			ProjectID:  "p1",
			Workdir:    "/tmp/project",
			Status:     string(provider.SessionStatusRunning),
		},
	} {
		if err := store.Save(sess); err != nil {
			t.Fatalf("save %s: %v", sess.ID, err)
		}
	}

	registry := provider.NewRegistry()
	registry.Register("codex", &managerTestProvider{
		name: "codex",
		active: map[string]bool{
			"active-empty-session": true,
		},
		threads: []provider.Session{
			{
				ID:         "listed-session",
				ProviderID: "codex",
				ThreadID:   "listed-session",
				Status:     string(provider.SessionStatusStopped),
			},
		},
	})
	manager := NewManager(store, registry, ws.NewHub())

	active, err := manager.GetSession(context.Background(), "active-empty-session")
	if err != nil {
		t.Fatalf("GetSession active: %v", err)
	}
	if active == nil {
		t.Fatal("expected active session")
	}
	if active.Status != string(provider.SessionStatusRunning) {
		t.Fatalf("active status = %q, want running", active.Status)
	}

	listed, err := manager.GetSession(context.Background(), "listed-session")
	if err != nil {
		t.Fatalf("GetSession listed: %v", err)
	}
	if listed == nil {
		t.Fatal("expected listed session")
	}
	if listed.Status != string(provider.SessionStatusStopped) {
		t.Fatalf("listed status = %q, want stopped", listed.Status)
	}

	stale, err := manager.GetSession(context.Background(), "stale-session")
	if err != nil {
		t.Fatalf("GetSession stale: %v", err)
	}
	if stale != nil {
		t.Fatalf("stale session = %#v, want nil", stale)
	}
	deleted, err := store.Get("stale-session")
	if err != nil {
		t.Fatalf("get stale after delete: %v", err)
	}
	if deleted != nil {
		t.Fatalf("stale DB row should be deleted: %#v", deleted)
	}
}

func TestGetSessionFindsProviderSessionWhenDBWorkdirIsStale(t *testing.T) {
	db, err := storage.Open(":memory:")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer db.Close()

	store := NewSessionStore(db)
	if err := store.Save(&provider.Session{
		ID:         "listed-session",
		ProviderID: "codex",
		ThreadID:   "listed-session",
		ProjectID:  "p1",
		Workdir:    "/stale/workdir",
		Status:     string(provider.SessionStatusRunning),
	}); err != nil {
		t.Fatalf("save: %v", err)
	}

	registry := provider.NewRegistry()
	registry.Register("codex", &managerTestProvider{
		name: "codex",
		threads: []provider.Session{
			{
				ID:         "listed-session",
				ProviderID: "codex",
				ThreadID:   "listed-session",
				Workdir:    "/home/teddyhp/code/python_web_template",
				Status:     string(provider.SessionStatusStopped),
			},
		},
	})
	manager := NewManager(store, registry, ws.NewHub())

	got, err := manager.GetSession(context.Background(), "listed-session")
	if err != nil {
		t.Fatalf("GetSession: %v", err)
	}
	if got == nil {
		t.Fatal("provider-listed session should not be treated as stale")
	}
	if got.Workdir != "/home/teddyhp/code/python_web_template" {
		t.Fatalf("workdir = %q", got.Workdir)
	}
}

func TestResumeSessionDeletesProviderMissingDBMetadata(t *testing.T) {
	db, err := storage.Open(":memory:")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer db.Close()

	store := NewSessionStore(db)
	if err := store.Save(&provider.Session{
		ID:         "empty-stale-session",
		ProviderID: "codex",
		ThreadID:   "empty-stale-session",
		ProjectID:  "p1",
		Workdir:    "/tmp/project",
		Status:     string(provider.SessionStatusStopped),
	}); err != nil {
		t.Fatalf("save: %v", err)
	}

	registry := provider.NewRegistry()
	registry.Register("codex", &managerTestProvider{
		name:      "codex",
		resumeErr: fmt.Errorf("resume: thread/resume: jsonrpc error -32600: no rollout found for thread id empty-stale-session"),
	})
	manager := NewManager(store, registry, ws.NewHub())

	err = manager.ResumeSession(context.Background(), "empty-stale-session")
	if err == nil {
		t.Fatal("ResumeSession should fail")
	}
	if !strings.Contains(err.Error(), "not found") {
		t.Fatalf("ResumeSession error = %v, want not found", err)
	}
	got, getErr := store.Get("empty-stale-session")
	if getErr != nil {
		t.Fatalf("get after resume: %v", getErr)
	}
	if got != nil {
		t.Fatalf("stale DB row should be deleted: %#v", got)
	}
}

func TestResumeSessionUsesProviderWorkdirForMetadata(t *testing.T) {
	db, err := storage.Open(":memory:")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer db.Close()

	store := NewSessionStore(db)
	providerImpl := &managerTestProvider{
		name: "codex",
		threads: []provider.Session{
			{
				ID:         "provider-only-session",
				ProviderID: "codex",
				ThreadID:   "provider-only-session",
				Workdir:    "/home/teddyhp/code/python_web_template",
				Model:      "gpt-5.5",
				Status:     string(provider.SessionStatusStopped),
			},
		},
		active: map[string]bool{},
	}
	registry := provider.NewRegistry()
	registry.Register("codex", providerImpl)
	manager := NewManager(store, registry, ws.NewHub())

	if err := manager.ResumeSession(context.Background(), "provider-only-session"); err != nil {
		t.Fatalf("ResumeSession: %v", err)
	}

	if providerImpl.lastMetadata == nil {
		t.Fatal("provider metadata was not updated")
	}
	if providerImpl.lastMetadata.Workdir != "/home/teddyhp/code/python_web_template" {
		t.Fatalf("metadata workdir = %q", providerImpl.lastMetadata.Workdir)
	}
	sess, err := store.Get("provider-only-session")
	if err != nil {
		t.Fatalf("store.Get: %v", err)
	}
	if sess == nil {
		t.Fatal("resumed provider session should be saved")
	}
	if sess.Workdir != "/home/teddyhp/code/python_web_template" {
		t.Fatalf("stored workdir = %q", sess.Workdir)
	}
}

func TestForkSessionUpdatesProviderMetadataForNewThread(t *testing.T) {
	db, err := storage.Open(":memory:")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer db.Close()

	store := NewSessionStore(db)
	if err := store.Save(&provider.Session{
		ID:             "source-session",
		ProviderID:     "codex",
		ThreadID:       "source-session",
		ProjectID:      "p1",
		Workdir:        "/home/teddyhp/code/python_web_template",
		Model:          "gpt-5.5",
		ApprovalPolicy: string(provider.ApprovalPolicyOnRequest),
		SandboxMode:    string(provider.SandboxModeWorkspaceWrite),
		Status:         string(provider.SessionStatusStopped),
	}); err != nil {
		t.Fatalf("save: %v", err)
	}

	providerImpl := &managerTestProvider{name: "codex", forkID: "forked-session"}
	registry := provider.NewRegistry()
	registry.Register("codex", providerImpl)
	manager := NewManager(store, registry, ws.NewHub())

	forked, err := manager.ForkSession(context.Background(), "source-session")
	if err != nil {
		t.Fatalf("ForkSession: %v", err)
	}
	if forked.Workdir != "/home/teddyhp/code/python_web_template" {
		t.Fatalf("forked workdir = %q", forked.Workdir)
	}
	if providerImpl.lastMetadata == nil {
		t.Fatal("provider metadata was not updated")
	}
	if providerImpl.lastMetadata.ID != "forked-session" {
		t.Fatalf("metadata id = %q", providerImpl.lastMetadata.ID)
	}
	if providerImpl.lastMetadata.Workdir != "/home/teddyhp/code/python_web_template" {
		t.Fatalf("metadata workdir = %q", providerImpl.lastMetadata.Workdir)
	}
}

type managerTestProvider struct {
	name         string
	active       map[string]bool
	threads      []provider.Session
	archived     []provider.Session
	resumeErr    error
	forkID       string
	archivedIDs  []string
	unarchivedID string
	deletedIDs   []string
	lastMetadata *provider.Session
}

func (p *managerTestProvider) Name() string { return p.name }

func (p *managerTestProvider) Detect(ctx context.Context) (*provider.ProviderInfo, error) {
	return &provider.ProviderInfo{Name: p.name, Status: "available"}, nil
}

func (p *managerTestProvider) CreateSession(ctx context.Context, req provider.CreateSessionRequest) (*provider.Session, error) {
	return nil, fmt.Errorf("not implemented")
}

func (p *managerTestProvider) ResumeSession(ctx context.Context, sessionID, threadID string) error {
	if p.resumeErr != nil {
		return p.resumeErr
	}
	if p.active == nil {
		p.active = map[string]bool{}
	}
	p.active[sessionID] = true
	return nil
}

func (p *managerTestProvider) ForkSession(ctx context.Context, sessionID, threadID string) (string, error) {
	if p.forkID == "" {
		return "", fmt.Errorf("not implemented")
	}
	return p.forkID, nil
}

func (p *managerTestProvider) SendInput(ctx context.Context, sessionID string, input provider.SendInputRequest) error {
	return fmt.Errorf("not implemented")
}

func (p *managerTestProvider) UpdateSessionMetadata(session provider.Session) {
	copied := session
	p.lastMetadata = &copied
}

func (p *managerTestProvider) InterruptSession(ctx context.Context, sessionID string) error {
	return fmt.Errorf("not implemented")
}

func (p *managerTestProvider) StopSession(ctx context.Context, sessionID string) error {
	return fmt.Errorf("not implemented")
}

func (p *managerTestProvider) CompactSession(ctx context.Context, sessionID string) error {
	return fmt.Errorf("not implemented")
}

func (p *managerTestProvider) RollbackSession(ctx context.Context, sessionID string, turns int) error {
	return fmt.Errorf("not implemented")
}

func (p *managerTestProvider) ListThreads(ctx context.Context, cwd string, limit int) ([]provider.Session, error) {
	return p.threads, nil
}

func (p *managerTestProvider) ListThreadsWithOptions(ctx context.Context, opts provider.ThreadListOptions) ([]provider.Session, error) {
	if opts.Archived {
		return p.archived, nil
	}
	return p.threads, nil
}

func (p *managerTestProvider) ArchiveSession(ctx context.Context, sessionID string) error {
	p.archivedIDs = append(p.archivedIDs, sessionID)
	return nil
}

func (p *managerTestProvider) UnarchiveSession(ctx context.Context, sessionID string) (*provider.Session, error) {
	p.unarchivedID = sessionID
	return &provider.Session{
		ID:         sessionID,
		ProviderID: p.name,
		ThreadID:   sessionID,
		Status:     string(provider.SessionStatusStopped),
	}, nil
}

func (p *managerTestProvider) DeleteSession(ctx context.Context, sessionID string) error {
	p.deletedIDs = append(p.deletedIDs, sessionID)
	return nil
}

func (p *managerTestProvider) HasSession(sessionID string) bool {
	return p.active[sessionID]
}

func (p *managerTestProvider) ReadThreadEvents(ctx context.Context, threadID, cursor string, limit int) (*provider.EventPage, error) {
	return nil, fmt.Errorf("not implemented")
}

func (p *managerTestProvider) ReadThreadItems(ctx context.Context, threadID, cursor string, limit int) (*provider.ItemPage, error) {
	return nil, fmt.Errorf("not implemented")
}

func (p *managerTestProvider) ResolveApproval(ctx context.Context, sessionID, approvalID string, decision provider.ApprovalDecision) error {
	return fmt.Errorf("not implemented")
}

func (p *managerTestProvider) Subscribe(sessionID string) <-chan provider.ProviderEvent {
	return make(chan provider.ProviderEvent)
}

func (p *managerTestProvider) Unsubscribe(sessionID string) {}

func (p *managerTestProvider) Capabilities() provider.ProviderCapabilities {
	return provider.ProviderCapabilities{}
}

func (p *managerTestProvider) Config() provider.ProviderConfig {
	return provider.ProviderConfig{}
}

func (p *managerTestProvider) Close() error { return nil }
