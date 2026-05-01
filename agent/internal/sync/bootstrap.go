package sync

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"sync"
	"time"

	"github.com/magent/agent/internal/config"
	"github.com/magent/agent/internal/project"
	"github.com/magent/agent/internal/provider"
	"github.com/magent/agent/internal/storage"
)

type ConfigService struct {
	registry  *provider.Registry
	cfg       *config.Config
	store     *storage.SQLite
	projectMgr *project.Manager

	cache     *BootstrapData
	cacheHash string
	cacheMu   sync.RWMutex
	dirty     chan struct{}
}

type BootstrapData struct {
	Agent     AgentData            `json:"agent"`
	Providers []ProviderConfigData `json:"providers"`
	Projects  []ProjectSummary     `json:"projects"`
	Workspace config.WorkspaceConfig `json:"workspace"`
	UpdatedAt int64                `json:"updated_at"`
}

type AgentData struct {
	Version      string              `json:"version"`
	Capabilities AgentCapabilities   `json:"capabilities"`
}

type AgentCapabilities struct {
	SupportsMultiAgent bool `json:"supports_multi_agent"`
}

type ProviderConfigData struct {
	Name         string                   `json:"name"`
	Status       string                   `json:"status"`
	Version      string                   `json:"version,omitempty"`
	RunMode      string                   `json:"run_mode,omitempty"`
	Error        string                   `json:"error,omitempty"`
	Capabilities provider.ProviderCapabilities `json:"capabilities,omitempty"`
	ConfigSchema map[string]FieldSchema   `json:"config_schema,omitempty"`
}

type FieldSchema struct {
	Type         string            `json:"type"`
	Label        string            `json:"label"`
	Values       []string          `json:"values,omitempty"`
	Default      any               `json:"default,omitempty"`
	Descriptions map[string]string `json:"descriptions,omitempty"`
}

type ProjectSummary struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Path string `json:"path"`
}

type CheckResult struct {
	ConfigHash string `json:"config_hash"`
	UpdatedAt  int64  `json:"updated_at"`
}

var version = "dev"

func NewConfigService(registry *provider.Registry, cfg *config.Config, store *storage.SQLite, projectMgr *project.Manager) *ConfigService {
	s := &ConfigService{
		registry:   registry,
		cfg:        cfg,
		store:      store,
		projectMgr: projectMgr,
		dirty:      make(chan struct{}, 1),
	}
	s.loadCache()
	go s.refreshLoop()
	return s
}

func (s *ConfigService) Check() *CheckResult {
	s.cacheMu.RLock()
	defer s.cacheMu.RUnlock()
	if s.cache == nil {
		return &CheckResult{}
	}
	return &CheckResult{
		ConfigHash: s.cacheHash,
		UpdatedAt:  s.cache.UpdatedAt,
	}
}

func (s *ConfigService) Bootstrap(ctx context.Context, localHash string) (*BootstrapData, int, error) {
	s.cacheMu.RLock()
	if localHash != "" && localHash == s.cacheHash {
		s.cacheMu.RUnlock()
		return nil, 304, nil
	}
	data := s.cache
	s.cacheMu.RUnlock()

	if data != nil {
		return data, 200, nil
	}

	if err := s.refresh(ctx); err != nil {
		return nil, 500, err
	}

	s.cacheMu.RLock()
	defer s.cacheMu.RUnlock()
	return s.cache, 200, nil
}

func (s *ConfigService) MarkDirty() {
	select {
	case s.dirty <- struct{}{}:
	default:
	}
}

func (s *ConfigService) refreshLoop() {
	for range s.dirty {
		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		s.refresh(ctx)
		cancel()
	}
}

func (s *ConfigService) refresh(ctx context.Context) error {
	providers := s.registry.List()

	var providerConfigs []ProviderConfigData
	for _, p := range providers {
		providerConfigs = append(providerConfigs, ProviderConfigData{
			Name:         p.Name,
			Status:       p.Status,
			Version:      p.Version,
			RunMode:      p.RunMode,
			Error:        p.Error,
			Capabilities: p.Capabilities,
			ConfigSchema: s.getProviderConfigSchema(p.Name),
		})
	}

	projects, _ := s.projectMgr.List(ctx)
	var projectSummaries []ProjectSummary
	for _, p := range projects {
		projectSummaries = append(projectSummaries, ProjectSummary{
			ID:   p.ID,
			Name: p.Name,
			Path: p.Path,
		})
	}

	data := &BootstrapData{
		Agent: AgentData{
			Version: version,
			Capabilities: AgentCapabilities{
				SupportsMultiAgent: true,
			},
		},
		Providers: providerConfigs,
		Projects:  projectSummaries,
		Workspace: s.cfg.Workspace,
		UpdatedAt: time.Now().Unix(),
	}

	hash := s.computeHash(data)

	s.cacheMu.Lock()
	s.cache = data
	s.cacheHash = hash
	s.cacheMu.Unlock()

	s.saveCache(data, hash)

	return nil
}

func (s *ConfigService) computeHash(data *BootstrapData) string {
	h := sha256.New()
	h.Write([]byte(data.Agent.Version))
	for _, p := range data.Providers {
		h.Write([]byte(p.Name))
		h.Write([]byte(p.Status))
	}
	for _, p := range data.Projects {
		h.Write([]byte(p.ID))
	}
	return hex.EncodeToString(h.Sum(nil))[:16]
}

func (s *ConfigService) loadCache() {
	row := s.store.DB().QueryRow(`SELECT config_hash, data FROM bootstrap_cache WHERE id = 1`)
	var hash string
	var dataBytes []byte
	if err := row.Scan(&hash, &dataBytes); err != nil {
		return
	}
	var data BootstrapData
	json.Unmarshal(dataBytes, &data)

	s.cacheMu.Lock()
	s.cache = &data
	s.cacheHash = hash
	s.cacheMu.Unlock()
}

func (s *ConfigService) saveCache(data *BootstrapData, hash string) {
	dataBytes, _ := json.Marshal(data)
	s.store.DB().Exec(`
		INSERT OR REPLACE INTO bootstrap_cache (id, config_hash, data, updated_at)
		VALUES (1, ?, ?, ?)`, hash, string(dataBytes), time.Now().Unix())
}

func (s *ConfigService) getProviderConfigSchema(providerName string) map[string]FieldSchema {
	switch providerName {
	case "codex":
		return map[string]FieldSchema{
			"model": {
				Type:    "enum",
				Label:   "模型",
				Default: "gpt-5.4",
			},
			"approval_policy": {
				Type:    "enum",
				Label:   "审批策略",
				Values:  []string{"untrusted", "on-request", "never"},
				Default: "on-request",
				Descriptions: map[string]string{
					"untrusted": "最严格，所有操作都需要审批",
					"on-request": "仅在需要时请求审批",
					"never":     "从不请求审批（危险）",
				},
			},
			"sandbox_mode": {
				Type:    "enum",
				Label:   "沙箱模式",
				Values:  []string{"read-only", "workspace-write", "danger-full-access"},
				Default: "workspace-write",
			},
		}
	default:
		return nil
	}
}
