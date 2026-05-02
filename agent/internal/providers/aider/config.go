package aider

import "github.com/Teddy-Zhu/magent/agent/internal/provider"

func (p *AiderProvider) Config() provider.ProviderConfig {
	return provider.ProviderConfig{
		Models: []provider.ModelInfo{
			{ID: "gpt-4o", Name: "GPT-4o", Default: true},
			{ID: "claude-sonnet-4-20250514", Name: "Claude Sonnet"},
			{ID: "claude-opus-4-20250514", Name: "Claude Opus"},
			{ID: "deepseek/deepseek-chat", Name: "DeepSeek Chat"},
		},
	}
}
