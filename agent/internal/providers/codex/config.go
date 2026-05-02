package codex

import (
	"context"
	"encoding/json"
	"time"

	"github.com/Teddy-Zhu/magent/agent/internal/log"
	"github.com/Teddy-Zhu/magent/agent/internal/provider"
)

func (p *CodexProvider) Config() provider.ProviderConfig {
	p.configMu.RLock()
	if p.cachedConfig != nil {
		cfg := *p.cachedConfig
		p.configMu.RUnlock()
		cfg.Skills = p.fetchSkills()
		return cfg
	}
	p.configMu.RUnlock()

	cfg := p.fetchConfig()
	if cfg != nil {
		result := *cfg
		result.Skills = p.fetchSkills()
		p.configMu.Lock()
		p.cachedConfig = cfg
		p.configMu.Unlock()
		return result
	}

	return provider.ProviderConfig{
		Models: []provider.ModelInfo{
			{ID: "o3", Name: "o3", Default: true, ReasoningEfforts: []string{"low", "medium", "high"}},
			{ID: "o4-mini", Name: "o4-mini", ReasoningEfforts: []string{"low", "medium", "high"}},
		},
		ApprovalPolicies: []string{
			string(provider.ApprovalPolicyUntrusted),
			string(provider.ApprovalPolicyOnRequest),
			string(provider.ApprovalPolicyNever),
		},
		SandboxModes: []string{
			string(provider.SandboxModeReadOnly),
			string(provider.SandboxModeWorkspaceWrite),
			string(provider.SandboxModeDangerFullAccess),
		},
	}
}

func (p *CodexProvider) fetchConfig() *provider.ProviderConfig {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	client, err := p.appServerClient(ctx)
	if err != nil {
		log.Error("codex", "config: appserver unavailable: %v", err)
		return nil
	}

	models, err := client.ListModels(ctx)
	if err != nil {
		log.Error("codex", "config: list models failed: %v", err)
		return nil
	}
	requirements := readConfigRequirements(ctx, client)
	mcpServers := readMCPServers(ctx, client)

	var providerModels []provider.ModelInfo
	for i, m := range models {
		var efforts []string
		for _, e := range m.SupportedReasoningEfforts {
			efforts = append(efforts, e.ReasoningEffort)
		}
		if len(efforts) == 0 {
			efforts = []string{"low", "medium", "high"}
		}
		log.Debug("codex", "config: model=%s efforts=%v", m.ID, efforts)
		providerModels = append(providerModels, provider.ModelInfo{
			ID:               m.ID,
			Name:             m.DisplayName,
			Default:          i == 0,
			ReasoningEfforts: efforts,
		})
	}

	log.Info("codex", "config: fetched %d models from app-server", len(providerModels))
	approvalPolicies := []string{
		string(provider.ApprovalPolicyUntrusted),
		string(provider.ApprovalPolicyOnRequest),
		string(provider.ApprovalPolicyNever),
	}
	sandboxModes := []string{
		string(provider.SandboxModeReadOnly),
		string(provider.SandboxModeWorkspaceWrite),
		string(provider.SandboxModeDangerFullAccess),
	}
	approvalPolicies = constrainApprovalPolicies(approvalPolicies, requirements)
	sandboxModes = constrainSandboxModes(sandboxModes, requirements)

	return &provider.ProviderConfig{
		Models:           providerModels,
		ApprovalPolicies: approvalPolicies,
		SandboxModes:     sandboxModes,
		Requirements:     requirements,
		MCPServers:       mcpServers,
	}
}

func (p *CodexProvider) fetchSkills() any {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	client, err := p.appServerClient(ctx)
	if err != nil {
		log.Warn("codex", "config: skills unavailable: %v", err)
		return nil
	}
	return readSkills(ctx, client)
}

func readConfigRequirements(ctx context.Context, client *AppServerClient) any {
	raw, err := client.ReadConfigRequirements(ctx)
	if err != nil {
		log.Warn("codex", "config: requirements unavailable: %v", err)
		return nil
	}
	var resp struct {
		Requirements any `json:"requirements"`
	}
	if err := json.Unmarshal(raw, &resp); err != nil {
		log.Warn("codex", "config: requirements parse failed: %v", err)
		return nil
	}
	return resp.Requirements
}

func readSkills(ctx context.Context, client *AppServerClient) any {
	raw, err := client.ListSkills(ctx)
	if err != nil {
		log.Warn("codex", "config: skills unavailable: %v", err)
		return nil
	}
	return decodeRawConfig(raw)
}

func readMCPServers(ctx context.Context, client *AppServerClient) any {
	raw, err := client.ListMCPServers(ctx)
	if err != nil {
		log.Warn("codex", "config: mcp servers unavailable: %v", err)
		return nil
	}
	return decodeRawConfig(raw)
}

func decodeRawConfig(raw json.RawMessage) any {
	var value any
	if err := json.Unmarshal(raw, &value); err != nil {
		return nil
	}
	return value
}

func constrainApprovalPolicies(defaults []string, requirements any) []string {
	allowed := stringsFromRequirement(requirements, "allowedApprovalPolicies")
	if len(allowed) == 0 {
		return defaults
	}
	result := make([]string, 0, len(allowed))
	for _, value := range allowed {
		switch codexApprovalPolicy(value) {
		case string(provider.ApprovalPolicyOnRequest):
			result = append(result, string(provider.ApprovalPolicyOnRequest))
		case string(provider.ApprovalPolicyUntrusted):
			result = append(result, string(provider.ApprovalPolicyUntrusted))
		case string(provider.ApprovalPolicyOnFailure):
			result = append(result, string(provider.ApprovalPolicyOnFailure))
		case string(provider.ApprovalPolicyGranular):
			result = append(result, string(provider.ApprovalPolicyGranular))
		case string(provider.ApprovalPolicyNever):
			result = append(result, string(provider.ApprovalPolicyNever))
		default:
			result = append(result, value)
		}
	}
	return result
}

func constrainSandboxModes(defaults []string, requirements any) []string {
	allowed := stringsFromRequirement(requirements, "allowedSandboxModes")
	if len(allowed) == 0 {
		return defaults
	}
	result := make([]string, 0, len(allowed))
	for _, value := range allowed {
		switch codexSandboxMode(value) {
		case string(provider.SandboxModeReadOnly):
			result = append(result, string(provider.SandboxModeReadOnly))
		case string(provider.SandboxModeWorkspaceWrite):
			result = append(result, string(provider.SandboxModeWorkspaceWrite))
		case string(provider.SandboxModeDangerFullAccess):
			result = append(result, string(provider.SandboxModeDangerFullAccess))
		default:
			result = append(result, value)
		}
	}
	return result
}

func stringsFromRequirement(requirements any, key string) []string {
	m, ok := requirements.(map[string]any)
	if !ok {
		return nil
	}
	values, ok := m[key].([]any)
	if !ok {
		return nil
	}
	result := make([]string, 0, len(values))
	for _, value := range values {
		if s, ok := value.(string); ok && s != "" {
			result = append(result, s)
		}
	}
	return result
}
