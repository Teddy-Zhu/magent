package codex

import "github.com/Teddy-Zhu/magent/agent/internal/provider"

func codexApprovalPolicy(policy string) string {
	switch policy {
	case "", string(provider.ApprovalPolicyOnRequest), "onRequest":
		return "on-request"
	case string(provider.ApprovalPolicyUntrusted), "unless-trusted", "unlessTrusted":
		return "untrusted"
	case string(provider.ApprovalPolicyOnFailure), "onFailure":
		return "on-failure"
	case string(provider.ApprovalPolicyGranular):
		return "granular"
	case string(provider.ApprovalPolicyNever):
		return "never"
	default:
		return policy
	}
}

func codexSandboxMode(mode string) string {
	return codexThreadSandboxMode(mode)
}

func codexThreadSandboxMode(mode string) string {
	switch mode {
	case "", string(provider.SandboxModeWorkspaceWrite), "workspaceWrite":
		return "workspace-write"
	case string(provider.SandboxModeReadOnly), "readOnly":
		return "read-only"
	case string(provider.SandboxModeDangerFullAccess), "dangerFullAccess":
		return "danger-full-access"
	default:
		return mode
	}
}

func codexSandboxPolicyType(mode string) string {
	switch mode {
	case "", string(provider.SandboxModeWorkspaceWrite), "workspaceWrite":
		return "workspaceWrite"
	case string(provider.SandboxModeReadOnly), "readOnly":
		return "readOnly"
	case string(provider.SandboxModeDangerFullAccess), "dangerFullAccess":
		return "dangerFullAccess"
	default:
		return mode
	}
}

func sandboxPolicyObject(mode, cwd string) map[string]any {
	switch codexSandboxPolicyType(mode) {
	case "readOnly":
		return map[string]any{"type": "readOnly"}
	case "dangerFullAccess":
		return map[string]any{"type": "dangerFullAccess"}
	default:
		policy := map[string]any{"type": "workspaceWrite"}
		if cwd != "" {
			policy["writableRoots"] = []string{cwd}
		}
		return policy
	}
}

func codexInputItems(items []provider.InputItem) []map[string]any {
	if len(items) == 0 {
		return []map[string]any{}
	}
	result := make([]map[string]any, 0, len(items))
	for _, item := range items {
		if len(item) == 0 {
			continue
		}
		copied := make(map[string]any, len(item))
		for key, value := range item {
			copied[key] = value
		}
		result = append(result, copied)
	}
	return result
}

func codexTextInput(input string, extra []provider.InputItem) []provider.InputItem {
	items := make([]provider.InputItem, 0, len(extra)+1)
	items = append(items, provider.InputItem{"type": "text", "text": input})
	items = append(items, extra...)
	return items
}
