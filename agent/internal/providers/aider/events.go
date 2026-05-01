package aider

import (
	"time"

	"github.com/magent/agent/internal/provider"
	"github.com/magent/agent/internal/runner"
)

func aiderRunnerEvent(sessionID string, event runner.RunnerEvent) (provider.ProviderEvent, bool) {
	switch event.Type {
	case "output":
		return provider.ProviderEvent{
			SessionID: sessionID,
			Type:      string(provider.EventOutput),
			Payload:   map[string]any{"content": string(event.Data)},
			Timestamp: time.Now(),
		}, true
	case "exit":
		return provider.ProviderEvent{
			SessionID: sessionID,
			Type:      string(provider.EventExited),
			Payload:   map[string]any{"exit_code": event.ExitCode},
			Timestamp: time.Now(),
		}, true
	case "error":
		return provider.ProviderEvent{
			SessionID: sessionID,
			Type:      string(provider.EventError),
			Payload:   map[string]any{"error": event.Err.Error()},
			Timestamp: time.Now(),
		}, true
	default:
		return provider.ProviderEvent{}, false
	}
}
