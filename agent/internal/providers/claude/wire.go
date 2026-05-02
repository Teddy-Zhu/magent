package claude

import "github.com/Teddy-Zhu/magent/agent/internal/provider"

func claudeArgs(req provider.CreateSessionRequest) []string {
	args := []string{}
	if req.Model != "" {
		args = append(args, "--model", req.Model)
	}
	if provider.NormalizeApprovalPolicy(req.ApprovalPolicy) == string(provider.ApprovalPolicyNever) {
		args = append(args, "--dangerously-skip-permissions")
	}
	return args
}
