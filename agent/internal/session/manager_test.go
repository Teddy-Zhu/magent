package session

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"testing"
	"time"

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
	registry := provider.NewRegistry()
	registry.Register("codex", &managerTestProvider{
		name: "codex",
		active: map[string]bool{
			"listed-active-session": true,
		},
		threads: []provider.Session{
			{
				ID:         "listed-active-session",
				ProviderID: "codex",
				ThreadID:   "listed-active-session",
				Workdir:    "/tmp/project",
				Status:     string(provider.SessionStatusStopped),
			},
			{
				ID:         "listed-stopped-session",
				ProviderID: "codex",
				ThreadID:   "listed-stopped-session",
				Workdir:    "/tmp/project",
				Status:     string(provider.SessionStatusStopped),
			},
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

	if statuses["listed-active-session"] != string(provider.SessionStatusRunning) {
		t.Fatalf("active listed session status = %q, want running; sessions=%#v", statuses["listed-active-session"], got)
	}
	if statuses["listed-stopped-session"] != string(provider.SessionStatusStopped) {
		t.Fatalf("stopped listed session status = %q, want stopped; sessions=%#v", statuses["listed-stopped-session"], got)
	}
}

func TestGetSessionUsesProviderAsSourceOfTruth(t *testing.T) {
	db, err := storage.Open(":memory:")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer db.Close()

	store := NewSessionStore(db)
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
}

func TestGetSessionUsesProviderWorkdir(t *testing.T) {
	db, err := storage.Open(":memory:")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer db.Close()

	store := NewSessionStore(db)
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
		t.Fatal("expected provider-listed session")
	}
	if got.Workdir != "/home/teddyhp/code/python_web_template" {
		t.Fatalf("workdir = %q", got.Workdir)
	}
}

func TestForwardEventsUpsertsCompletedItemWithoutProviderRead(t *testing.T) {
	db, err := storage.Open(":memory:")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer db.Close()

	store := NewSessionStore(db)
	events := make(chan provider.ProviderEvent)
	providerImpl := &managerTestProvider{name: "codex", events: events}
	registry := provider.NewRegistry()
	registry.Register("codex", providerImpl)
	hub := ws.NewHub()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go hub.Run(ctx)
	manager := NewManager(store, registry, hub)
	done := make(chan struct{})
	go func() {
		manager.forwardEvents("s1", providerImpl)
		close(done)
	}()

	events <- provider.ProviderEvent{
		SessionID: "s1",
		Type:      string(provider.EventMessage),
		ItemID:    "msg-1",
		TurnID:    "turn-1",
		Timestamp: time.Unix(1777730145, 0),
		Payload: map[string]any{
			"id":     "msg-1",
			"type":   "agentMessage",
			"turnId": "turn-1",
			"text":   "hello",
			"index":  1,
		},
	}
	close(events)
	<-done

	if providerImpl.readItemsCount != 0 {
		t.Fatalf("ReadThreadItems called %d times, want 0", providerImpl.readItemsCount)
	}
	items, err := manager.itemProjection.Items(context.Background(), "s1")
	if err != nil {
		t.Fatalf("items: %v", err)
	}
	if len(items) != 1 || items[0].ItemID != "msg-1" {
		t.Fatalf("items = %#v", items)
	}
}

func TestForwardEventsIgnoresDeltaProjectionSync(t *testing.T) {
	db, err := storage.Open(":memory:")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer db.Close()

	store := NewSessionStore(db)
	events := make(chan provider.ProviderEvent)
	providerImpl := &managerTestProvider{name: "codex", events: events}
	manager := NewManager(store, provider.NewRegistry(), ws.NewHub())
	done := make(chan struct{})
	go func() {
		manager.forwardEvents("s1", providerImpl)
		close(done)
	}()

	events <- provider.ProviderEvent{
		SessionID: "s1",
		Type:      string(provider.EventMessageDelta),
		ItemID:    "msg-1",
		TurnID:    "turn-1",
		Timestamp: time.Unix(1777730145, 0),
		Payload: map[string]any{
			"itemId": "msg-1",
			"turnId": "turn-1",
			"delta":  "hello",
		},
	}
	close(events)
	<-done

	items, err := manager.itemProjection.Items(context.Background(), "s1")
	if err != nil {
		t.Fatalf("items: %v", err)
	}
	if len(items) != 0 {
		t.Fatalf("delta should not create projection item: %#v", items)
	}
}

func TestResumeSessionReturnsNotFoundForProviderMissingThread(t *testing.T) {
	db, err := storage.Open(":memory:")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer db.Close()

	store := NewSessionStore(db)
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
}

func TestArchiveSessionFallsBackToProviderForProviderOnlySession(t *testing.T) {
	db, err := storage.Open(":memory:")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer db.Close()

	store := NewSessionStore(db)
	providerImpl := &managerTestProvider{name: "codex"}
	registry := provider.NewRegistry()
	registry.Register("codex", providerImpl)
	manager := NewManager(store, registry, ws.NewHub())

	if err := manager.ArchiveSession(context.Background(), "provider-only-session"); err != nil {
		t.Fatalf("ArchiveSession: %v", err)
	}
	if len(providerImpl.archivedIDs) != 1 || providerImpl.archivedIDs[0] != "provider-only-session" {
		t.Fatalf("archivedIDs = %#v", providerImpl.archivedIDs)
	}
}

func TestForkSessionUpdatesProviderMetadataForNewThread(t *testing.T) {
	db, err := storage.Open(":memory:")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	defer db.Close()

	store := NewSessionStore(db)
	providerImpl := &managerTestProvider{
		name:   "codex",
		forkID: "forked-session",
		threads: []provider.Session{
			{
				ID:         "source-session",
				ProviderID: "codex",
				ThreadID:   "source-session",
				Status:     string(provider.SessionStatusStopped),
			},
		},
	}
	registry := provider.NewRegistry()
	registry.Register("codex", providerImpl)
	manager := NewManager(store, registry, ws.NewHub())

	if _, err := manager.ForkSession(context.Background(), "source-session"); err != nil {
		t.Fatalf("ForkSession: %v", err)
	}
	if providerImpl.lastMetadata == nil {
		t.Fatal("provider metadata was not updated")
	}
	if providerImpl.lastMetadata.ID != "forked-session" {
		t.Fatalf("metadata id = %q", providerImpl.lastMetadata.ID)
	}
}

type managerTestProvider struct {
	name           string
	active         map[string]bool
	threads        []provider.Session
	archived       []provider.Session
	items          []provider.SessionItem
	events         chan provider.ProviderEvent
	mu             sync.Mutex
	readItemsCount int
	resumeErr      error
	forkID         string
	archivedIDs    []string
	unarchivedID   string
	deletedIDs     []string
	lastMetadata   *provider.Session
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
	p.mu.Lock()
	p.readItemsCount++
	p.mu.Unlock()
	return &provider.ItemPage{
		SessionID: threadID,
		Items:     p.items,
	}, nil
}

func (p *managerTestProvider) ResolveApproval(ctx context.Context, sessionID, approvalID string, decision provider.ApprovalDecision) error {
	return fmt.Errorf("not implemented")
}

func (p *managerTestProvider) Subscribe(sessionID string) <-chan provider.ProviderEvent {
	if p.events != nil {
		return p.events
	}
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
