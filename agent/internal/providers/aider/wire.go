package aider

import "github.com/magent/agent/internal/provider"

func aiderArgs(req provider.CreateSessionRequest) []string {
	args := []string{
		"--yes",
		"--no-git",
		"--no-auto-commits",
	}
	if req.Model != "" {
		args = append(args, "--model", req.Model)
	}
	return args
}
