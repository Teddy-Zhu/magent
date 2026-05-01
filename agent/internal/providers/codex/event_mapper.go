package codex

import (
	"encoding/json"
	"time"

	"github.com/magent/agent/internal/protocol"
	"github.com/magent/agent/internal/provider"
)

func (c *AppServerClient) handleNotification(msg *protocol.JSONRPCResponse) {
	switch msg.Method {
	case "thread/started":
		c.events <- provider.ProviderEvent{
			Type:      "session.started",
			Payload:   parsePayload(msg.Params),
			Timestamp: time.Now(),
		}

	case "turn/started":
		c.events <- provider.ProviderEvent{
			Type:      "session.turn_started",
			Timestamp: time.Now(),
		}

	case "turn/completed":
		c.events <- provider.ProviderEvent{
			Type:      "session.turn_completed",
			Payload:   parsePayload(msg.Params),
			Timestamp: time.Now(),
		}

	case "turn/failed":
		c.events <- provider.ProviderEvent{
			Type:      "session.turn_failed",
			Payload:   parsePayload(msg.Params),
			Timestamp: time.Now(),
		}

	case "item/started":
		c.events <- provider.ProviderEvent{
			Type:      "session.item_started",
			Payload:   parsePayload(msg.Params),
			Timestamp: time.Now(),
		}

	case "item/completed":
		payload := parsePayload(msg.Params)
		item, ok := payload.(map[string]any)
		if !ok {
			c.events <- provider.ProviderEvent{
				Type:      "session.item_completed",
				Payload:   payload,
				Timestamp: time.Now(),
			}
			return
		}

		itemType, _ := item["type"].(string)
		switch itemType {
		case "command_execution":
			c.events <- provider.ProviderEvent{
				Type:      "session.command_completed",
				Payload:   payload,
				Timestamp: time.Now(),
			}
		case "agent_message":
			c.events <- provider.ProviderEvent{
				Type:      "session.message",
				Payload:   payload,
				Timestamp: time.Now(),
			}
		case "file_change":
			c.events <- provider.ProviderEvent{
				Type:      "session.file_write",
				Payload:   payload,
				Timestamp: time.Now(),
			}
		case "file_read":
			c.events <- provider.ProviderEvent{
				Type:      "session.file_read",
				Payload:   payload,
				Timestamp: time.Now(),
			}
		case "mcp_tool_call":
			c.events <- provider.ProviderEvent{
				Type:      "session.mcp_tool_completed",
				Payload:   payload,
				Timestamp: time.Now(),
			}
		default:
			c.events <- provider.ProviderEvent{
				Type:      "session.item_completed",
				Payload:   payload,
				Timestamp: time.Now(),
			}
		}

	case "item/commandExecution/requestApproval":
		c.events <- provider.ProviderEvent{
			Type:      "session.approval_request",
			Payload:   parsePayload(msg.Params),
			Timestamp: time.Now(),
		}

	case "item/fileChange/requestApproval":
		c.events <- provider.ProviderEvent{
			Type:      "session.approval_request",
			Payload:   parsePayload(msg.Params),
			Timestamp: time.Now(),
		}

	case "item/mcpToolCall/requestApproval":
		c.events <- provider.ProviderEvent{
			Type:      "session.approval_request",
			Payload:   parsePayload(msg.Params),
			Timestamp: time.Now(),
		}

	case "error":
		c.events <- provider.ProviderEvent{
			Type:      "session.error",
			Payload:   parsePayload(msg.Params),
			Timestamp: time.Now(),
		}
	}
}

func parsePayload(data json.RawMessage) any {
	var result any
	json.Unmarshal(data, &result)
	return result
}
