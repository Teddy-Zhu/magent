package claude

import "github.com/magent/agent/internal/provider"

func (p *ClaudeProvider) Config() provider.ProviderConfig {
	return provider.ProviderConfig{
		Models: []provider.ModelInfo{
			{ID: "claude-sonnet-4-20250514", Name: "Claude Sonnet", Default: true},
			{ID: "claude-opus-4-20250514", Name: "Claude Opus"},
			{ID: "claude-haiku-4-20251001", Name: "Claude Haiku"},
		},
		ApprovalPolicies: []string{
			string(provider.ApprovalPolicyOnRequest),
			string(provider.ApprovalPolicyNever),
		},
	}
}
