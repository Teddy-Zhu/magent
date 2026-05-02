package codex

import (
	"encoding/json"
	"time"

	"github.com/Teddy-Zhu/magent/agent/internal/log"
	"github.com/Teddy-Zhu/magent/agent/internal/protocol"
	"github.com/Teddy-Zhu/magent/agent/internal/provider"
)

func (c *AppServerClient) handleNotification(msg *protocol.JSONRPCResponse) {
	log.Debug("codex", "notification method=%s params=%s", msg.Method, string(msg.Params))
	switch msg.Method {
	case "thread/started":
		payload := parsePayload(msg.Params)
		c.emitEvent(provider.ProviderEvent{
			Type:      string(provider.EventSessionStarted),
			SessionID: sessionIDFromPayload(payload),
			Payload:   payload,
			Timestamp: time.Now(),
		})

	case "thread/status/changed":
		payload := parsePayload(msg.Params)
		c.emitEvent(provider.ProviderEvent{
			Type:      string(provider.EventSessionStatusChanged),
			SessionID: sessionIDFromPayload(payload),
			Payload:   payload,
			Timestamp: time.Now(),
		})

	case "thread/closed":
		payload := parsePayload(msg.Params)
		if params, ok := payload.(map[string]any); ok && params["status"] == nil {
			params["status"] = map[string]any{"type": string(provider.SessionStatusStopped)}
			payload = params
		}
		c.emitEvent(provider.ProviderEvent{
			Type:      string(provider.EventSessionStatusChanged),
			SessionID: sessionIDFromPayload(payload),
			Payload:   payload,
			Timestamp: time.Now(),
		})

	case "turn/started":
		params := parsePayload(msg.Params)
		if m, ok := params.(map[string]any); ok {
			if turn, ok := m["turn"].(map[string]any); ok {
				if turnID, ok := turn["id"].(string); ok && turnID != "" {
					c.activeTurnMu.Lock()
					if threadID, ok := m["threadId"].(string); ok {
						c.activeTurnIDs[threadID] = turnID
					}
					c.activeTurnMu.Unlock()
				}
			}
		}
		c.emitEvent(provider.ProviderEvent{
			Type:      string(provider.EventTurnStarted),
			SessionID: sessionIDFromPayload(params),
			Payload:   params,
			Timestamp: time.Now(),
		})

	case "turn/completed":
		params := parsePayload(msg.Params)
		if m, ok := params.(map[string]any); ok {
			if threadID, ok := m["threadId"].(string); ok {
				c.activeTurnMu.Lock()
				delete(c.activeTurnIDs, threadID)
				c.activeTurnMu.Unlock()
			}
		}
		c.emitEvent(provider.ProviderEvent{
			Type:      string(provider.EventTurnCompleted),
			SessionID: sessionIDFromPayload(params),
			Payload:   params,
			Timestamp: time.Now(),
		})

	case "turn/failed":
		payload := parsePayload(msg.Params)
		if m, ok := payload.(map[string]any); ok {
			if threadID, ok := m["threadId"].(string); ok {
				c.activeTurnMu.Lock()
				delete(c.activeTurnIDs, threadID)
				c.activeTurnMu.Unlock()
			}
		}
		c.emitEvent(provider.ProviderEvent{
			Type:      string(provider.EventTurnFailed),
			SessionID: sessionIDFromPayload(payload),
			Payload:   payload,
			Timestamp: time.Now(),
		})

	case "item/started":
		payload := parsePayload(msg.Params)
		c.emitEvent(provider.ProviderEvent{
			Type:      string(provider.EventItemStarted),
			SessionID: sessionIDFromPayload(payload),
			Payload:   payload,
			Timestamp: time.Now(),
		})

	case "item/completed":
		payload := parsePayload(msg.Params)
		params, ok := payload.(map[string]any)
		if !ok {
			c.emitEvent(provider.ProviderEvent{
				Type:      string(provider.EventItemCompleted),
				SessionID: sessionIDFromPayload(payload),
				Payload:   payload,
				Timestamp: time.Now(),
			})
			return
		}

		item, _ := params["item"].(map[string]any)
		if item == nil {
			item = params
		}
		copyThreadContext(item, params)

		itemType, _ := item["type"].(string)
		switch provider.NormalizeItemType(itemType) {
		case string(provider.ItemTypeCommandExecution):
			if out, ok := item["aggregatedOutput"]; ok {
				item["output"] = out
			}
			if code, ok := item["exitCode"]; ok {
				item["exit_code"] = code
			}
			c.emitEvent(provider.ProviderEvent{
				Type:      string(provider.EventCommandCompleted),
				SessionID: sessionIDFromPayload(item),
				Payload:   item,
				Timestamp: time.Now(),
			})
		case string(provider.ItemTypeAgentMessage):
			c.emitEvent(provider.ProviderEvent{
				Type:      string(provider.EventMessage),
				SessionID: sessionIDFromPayload(item),
				Payload:   item,
				Timestamp: time.Now(),
			})
		case string(provider.ItemTypeFileChange):
			applyCodexFileChangePayloadDetails(item)
			c.emitEvent(provider.ProviderEvent{
				Type:      string(provider.EventFileWrite),
				SessionID: sessionIDFromPayload(item),
				Payload:   item,
				Timestamp: time.Now(),
			})
		case string(provider.ItemTypeFileRead):
			c.emitEvent(provider.ProviderEvent{
				Type:      string(provider.EventFileRead),
				SessionID: sessionIDFromPayload(item),
				Payload:   item,
				Timestamp: time.Now(),
			})
		case string(provider.ItemTypeMCPToolCall):
			c.emitEvent(provider.ProviderEvent{
				Type:      string(provider.EventMCPToolCompleted),
				SessionID: sessionIDFromPayload(item),
				Payload:   item,
				Timestamp: time.Now(),
			})
		default:
			c.emitEvent(provider.ProviderEvent{
				Type:      string(provider.EventItemCompleted),
				SessionID: sessionIDFromPayload(item),
				Payload:   item,
				Timestamp: time.Now(),
			})
		}

	case "item/agentMessage/delta":
		payload := parsePayload(msg.Params)
		c.emitEvent(provider.ProviderEvent{
			Type:      string(provider.EventMessageDelta),
			SessionID: sessionIDFromPayload(payload),
			Payload:   payload,
			Timestamp: time.Now(),
		})

	case "item/plan/delta":
		payload := parsePayload(msg.Params)
		c.emitEvent(provider.ProviderEvent{
			Type:      string(provider.EventPlanDelta),
			SessionID: sessionIDFromPayload(payload),
			Payload:   payload,
			Timestamp: time.Now(),
		})

	case "item/reasoning/summaryTextDelta":
		payload := parsePayload(msg.Params)
		c.emitEvent(provider.ProviderEvent{
			Type:      string(provider.EventReasoningSummaryDelta),
			SessionID: sessionIDFromPayload(payload),
			Payload:   payload,
			Timestamp: time.Now(),
		})

	case "item/reasoning/summaryPartAdded":
		payload := parsePayload(msg.Params)
		c.emitEvent(provider.ProviderEvent{
			Type:      string(provider.EventReasoningSummaryPart),
			SessionID: sessionIDFromPayload(payload),
			Payload:   payload,
			Timestamp: time.Now(),
		})

	case "item/reasoning/textDelta":
		payload := parsePayload(msg.Params)
		c.emitEvent(provider.ProviderEvent{
			Type:      string(provider.EventReasoningTextDelta),
			SessionID: sessionIDFromPayload(payload),
			Payload:   payload,
			Timestamp: time.Now(),
		})

	case "item/commandExecution/outputDelta":
		payload := parsePayload(msg.Params)
		c.emitEvent(provider.ProviderEvent{
			Type:      string(provider.EventCommandOutputDelta),
			SessionID: sessionIDFromPayload(payload),
			Payload:   payload,
			Timestamp: time.Now(),
		})

	case "item/fileChange/outputDelta":
		payload := parsePayload(msg.Params)
		c.emitEvent(provider.ProviderEvent{
			Type:      string(provider.EventFileChangeOutputDelta),
			SessionID: sessionIDFromPayload(payload),
			Payload:   payload,
			Timestamp: time.Now(),
		})

	case "turn/plan/updated":
		payload := parsePayload(msg.Params)
		c.emitEvent(provider.ProviderEvent{
			Type:      string(provider.EventPlanUpdated),
			SessionID: sessionIDFromPayload(payload),
			Payload:   payload,
			Timestamp: time.Now(),
		})

	case "turn/diff/updated":
		payload := parsePayload(msg.Params)
		c.emitEvent(provider.ProviderEvent{
			Type:      string(provider.EventDiffUpdated),
			SessionID: sessionIDFromPayload(payload),
			Payload:   payload,
			Timestamp: time.Now(),
		})

	case "item/commandExecution/requestApproval",
		"item/fileChange/requestApproval",
		"item/mcpToolCall/requestApproval":
		params := parsePayload(msg.Params)
		if m, ok := params.(map[string]any); ok {
			if item, ok := m["item"].(map[string]any); ok {
				copyThreadContext(item, m)
				if item["id"] == nil {
					item["id"] = m["itemId"]
				}
				c.emitEvent(provider.ProviderEvent{
					Type:      string(provider.EventApprovalRequest),
					SessionID: sessionIDFromPayload(item),
					Payload:   item,
					Timestamp: time.Now(),
				})
			} else {
				if m["id"] == nil {
					m["id"] = m["itemId"]
				}
				c.emitEvent(provider.ProviderEvent{
					Type:      string(provider.EventApprovalRequest),
					SessionID: sessionIDFromPayload(m),
					Payload:   m,
					Timestamp: time.Now(),
				})
			}
		} else {
			c.emitEvent(provider.ProviderEvent{
				Type:      string(provider.EventApprovalRequest),
				SessionID: sessionIDFromPayload(params),
				Payload:   params,
				Timestamp: time.Now(),
			})
		}

	case "error":
		payload := parsePayload(msg.Params)
		c.emitEvent(provider.ProviderEvent{
			Type:      string(provider.EventError),
			SessionID: sessionIDFromPayload(payload),
			Payload:   payload,
			Timestamp: time.Now(),
		})
	}
}

func (c *AppServerClient) emitEvent(event provider.ProviderEvent) {
	select {
	case c.events <- event:
	default:
		log.Warn("codex", "events channel full, dropping %s", event.Type)
	}
}

func copyThreadContext(dst, src map[string]any) {
	for _, key := range []string{"threadId", "thread_id", "turnId", "turn_id"} {
		if dst[key] == nil && src[key] != nil {
			dst[key] = src[key]
		}
	}
}

func parsePayload(data json.RawMessage) any {
	var result any
	json.Unmarshal(data, &result)
	return result
}
