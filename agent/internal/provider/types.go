package provider

type SessionStatus string

const (
	SessionStatusRunning   SessionStatus = "running"
	SessionStatusStopped   SessionStatus = "stopped"
	SessionStatusCompleted SessionStatus = "completed"
	SessionStatusFailed    SessionStatus = "failed"
	SessionStatusLost      SessionStatus = "lost"
)

type ApprovalPolicy string

const (
	ApprovalPolicyOnRequest ApprovalPolicy = "on-request"
	ApprovalPolicyOnFailure ApprovalPolicy = "on-failure"
	ApprovalPolicyNever     ApprovalPolicy = "never"
	ApprovalPolicyUntrusted ApprovalPolicy = "untrusted"
	ApprovalPolicyGranular  ApprovalPolicy = "granular"
)

type SandboxMode string

const (
	SandboxModeReadOnly         SandboxMode = "read-only"
	SandboxModeWorkspaceWrite   SandboxMode = "workspace-write"
	SandboxModeDangerFullAccess SandboxMode = "danger-full-access"
)

type EventType string

const (
	EventSessionStarted        EventType = "session.started"
	EventSessionStatusChanged  EventType = "session.status_changed"
	EventTurnStarted           EventType = "session.turn_started"
	EventTurnCompleted         EventType = "session.turn_completed"
	EventTurnFailed            EventType = "session.turn_failed"
	EventUserMessage           EventType = "session.user_message"
	EventMessage               EventType = "session.message"
	EventMessageDelta          EventType = "session.message_delta"
	EventOutput                EventType = "session.output"
	EventPlan                  EventType = "session.plan"
	EventPlanDelta             EventType = "session.plan_delta"
	EventPlanUpdated           EventType = "session.plan_updated"
	EventReasoning             EventType = "session.reasoning"
	EventReasoningSummaryDelta EventType = "session.reasoning_summary_delta"
	EventReasoningTextDelta    EventType = "session.reasoning_text_delta"
	EventReasoningSummaryPart  EventType = "session.reasoning_summary_part"
	EventDiffUpdated           EventType = "session.diff_updated"
	EventCommandCompleted      EventType = "session.command_completed"
	EventCommandOutputDelta    EventType = "session.command_output_delta"
	EventFileWrite             EventType = "session.file_write"
	EventFileRead              EventType = "session.file_read"
	EventFileChangeOutputDelta EventType = "session.file_change_output_delta"
	EventMCPToolCompleted      EventType = "session.mcp_tool_completed"
	EventApprovalRequest       EventType = "session.approval_request"
	EventApprovalResolved      EventType = "session.approval_resolved"
	EventError                 EventType = "session.error"
	EventExited                EventType = "session.exited"
	EventItemStarted           EventType = "session.item_started"
	EventItemCompleted         EventType = "session.item_completed"
)

type ItemType string

const (
	ItemTypeUserMessage      ItemType = "user_message"
	ItemTypeAgentMessage     ItemType = "agent_message"
	ItemTypeCommandExecution ItemType = "command_execution"
	ItemTypeFileChange       ItemType = "file_change"
	ItemTypeFileRead         ItemType = "file_read"
	ItemTypeMCPToolCall      ItemType = "mcp_tool_call"
	ItemTypePlan             ItemType = "plan"
	ItemTypeReasoning        ItemType = "reasoning"
	ItemTypeDiff             ItemType = "diff"
)

func NormalizeApprovalPolicy(value string) string {
	switch value {
	case "", "on-request", "onRequest":
		return string(ApprovalPolicyOnRequest)
	case "on-failure", "onFailure":
		return string(ApprovalPolicyOnFailure)
	case "never":
		return string(ApprovalPolicyNever)
	case "untrusted", "unless-trusted", "unlessTrusted":
		return string(ApprovalPolicyUntrusted)
	case "granular":
		return string(ApprovalPolicyGranular)
	default:
		return value
	}
}

func NormalizeSandboxMode(value string) string {
	switch value {
	case "", "workspace-write", "workspaceWrite":
		return string(SandboxModeWorkspaceWrite)
	case "read-only", "readOnly":
		return string(SandboxModeReadOnly)
	case "danger-full-access", "dangerFullAccess":
		return string(SandboxModeDangerFullAccess)
	default:
		return value
	}
}

func NormalizeSessionStatus(value string) string {
	switch value {
	case "idle", "active", "running", "inProgress":
		return string(SessionStatusRunning)
	case "completed", "succeeded", "exited":
		return string(SessionStatusCompleted)
	case "systemError", "failed", "error":
		return string(SessionStatusFailed)
	case "notLoaded", "not_loaded", "stopped", "closed":
		return string(SessionStatusStopped)
	case "lost":
		return string(SessionStatusLost)
	default:
		return value
	}
}

func NormalizeItemType(value string) string {
	switch value {
	case "userMessage", "user_message":
		return string(ItemTypeUserMessage)
	case "agentMessage", "agent_message":
		return string(ItemTypeAgentMessage)
	case "commandExecution", "command_execution":
		return string(ItemTypeCommandExecution)
	case "fileChange", "file_change":
		return string(ItemTypeFileChange)
	case "fileRead", "file_read":
		return string(ItemTypeFileRead)
	case "mcpToolCall", "mcp_tool_call":
		return string(ItemTypeMCPToolCall)
	case "plan":
		return string(ItemTypePlan)
	case "reasoning":
		return string(ItemTypeReasoning)
	case "diff":
		return string(ItemTypeDiff)
	default:
		return value
	}
}
