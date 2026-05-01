package provider

import "testing"

func TestNormalizeApprovalPolicy(t *testing.T) {
	tests := map[string]string{
		"":               "on-request",
		"on-request":     "on-request",
		"onRequest":      "on-request",
		"on-failure":     "on-failure",
		"onFailure":      "on-failure",
		"never":          "never",
		"untrusted":      "untrusted",
		"unless-trusted": "untrusted",
		"unlessTrusted":  "untrusted",
		"granular":       "granular",
		"custom":         "custom",
	}
	for input, want := range tests {
		if got := NormalizeApprovalPolicy(input); got != want {
			t.Fatalf("NormalizeApprovalPolicy(%q) = %q, want %q", input, got, want)
		}
	}
}

func TestNormalizeSandboxMode(t *testing.T) {
	tests := map[string]string{
		"":                   "workspace-write",
		"workspace-write":    "workspace-write",
		"workspaceWrite":     "workspace-write",
		"read-only":          "read-only",
		"readOnly":           "read-only",
		"danger-full-access": "danger-full-access",
		"dangerFullAccess":   "danger-full-access",
		"externalSandbox":    "externalSandbox",
	}
	for input, want := range tests {
		if got := NormalizeSandboxMode(input); got != want {
			t.Fatalf("NormalizeSandboxMode(%q) = %q, want %q", input, got, want)
		}
	}
}

func TestNormalizeSendInputMode(t *testing.T) {
	tests := map[string]string{
		"":                    "auto",
		"auto":                "auto",
		"steer":               "steer",
		"queue":               "queue",
		"interrupt_then_send": "interrupt_then_send",
		"interruptThenSend":   "interrupt_then_send",
		"interrupt-and-send":  "interrupt_then_send",
		"custom":              "custom",
	}
	for input, want := range tests {
		if got := NormalizeSendInputMode(input); got != want {
			t.Fatalf("NormalizeSendInputMode(%q) = %q, want %q", input, got, want)
		}
	}
}

func TestNormalizeSessionStatus(t *testing.T) {
	tests := map[string]string{
		"idle":        "running",
		"active":      "running",
		"running":     "running",
		"completed":   "completed",
		"exited":      "completed",
		"systemError": "failed",
		"notLoaded":   "stopped",
		"stopped":     "stopped",
		"lost":        "lost",
		"custom":      "custom",
	}
	for input, want := range tests {
		if got := NormalizeSessionStatus(input); got != want {
			t.Fatalf("NormalizeSessionStatus(%q) = %q, want %q", input, got, want)
		}
	}
}

func TestNormalizeItemType(t *testing.T) {
	tests := map[string]string{
		"userMessage":      "user_message",
		"agentMessage":     "agent_message",
		"commandExecution": "command_execution",
		"fileChange":       "file_change",
		"fileRead":         "file_read",
		"mcpToolCall":      "mcp_tool_call",
		"plan":             "plan",
		"custom":           "custom",
	}
	for input, want := range tests {
		if got := NormalizeItemType(input); got != want {
			t.Fatalf("NormalizeItemType(%q) = %q, want %q", input, got, want)
		}
	}
}
