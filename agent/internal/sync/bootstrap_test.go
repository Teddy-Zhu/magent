package sync

import (
	"testing"
	"time"

	"github.com/magent/agent/internal/config"
	"github.com/magent/agent/internal/provider"
)

func TestBootstrapHashIgnoresUpdatedAtAndSortsCollections(t *testing.T) {
	service := &ConfigService{}
	base := &BootstrapData{
		Agent: AgentData{Version: "dev", Capabilities: AgentCapabilities{SupportsMultiAgent: true}},
		Providers: []ProviderConfigData{
			{Name: "codex", Status: "available", Config: provider.ProviderConfig{Models: []provider.ModelInfo{{ID: "gpt-5.4", Name: "GPT-5.4"}}}},
			{Name: "aider", Status: "unavailable", Error: "missing"},
		},
		Projects: []ProjectSummary{
			{ID: "p2", Name: "Two", Path: "/repo/two", DefaultProvider: "codex"},
			{ID: "p1", Name: "One", Path: "/repo/one", DefaultProvider: "codex"},
		},
		Workspace: config.WorkspaceConfig{AllowedDirs: []string{"/repo"}},
		UpdatedAt: time.Now().Unix(),
	}
	reordered := &BootstrapData{
		Agent: base.Agent,
		Providers: []ProviderConfigData{
			base.Providers[1],
			base.Providers[0],
		},
		Projects: []ProjectSummary{
			base.Projects[1],
			base.Projects[0],
		},
		Workspace: base.Workspace,
		UpdatedAt: base.UpdatedAt + 1000,
	}

	if got, want := service.computeHash(reordered), service.computeHash(base); got != want {
		t.Fatalf("hash should ignore updated_at and collection order: got %s want %s", got, want)
	}

	changed := &BootstrapData{
		Agent: base.Agent,
		Providers: []ProviderConfigData{
			{Name: "codex", Status: "available", Config: provider.ProviderConfig{Models: []provider.ModelInfo{{ID: "gpt-5.5", Name: "GPT-5.5"}}}},
			base.Providers[1],
		},
		Projects:  append([]ProjectSummary(nil), base.Projects...),
		Workspace: base.Workspace,
		UpdatedAt: base.UpdatedAt,
	}
	if got, old := service.computeHash(changed), service.computeHash(base); got == old {
		t.Fatalf("hash should change when provider config changes")
	}
}

func TestMarkDirtyClearsCachedBootstrap(t *testing.T) {
	service := &ConfigService{
		cache:     &BootstrapData{UpdatedAt: 1},
		cacheHash: "hash",
		dirty:     make(chan struct{}, 1),
	}

	service.MarkDirty()

	if result := service.Check(); result.ConfigHash != "" || result.UpdatedAt != 0 {
		t.Fatalf("expected empty check result after dirty mark, got %#v", result)
	}
	select {
	case <-service.dirty:
	default:
		t.Fatalf("expected dirty signal")
	}
}
