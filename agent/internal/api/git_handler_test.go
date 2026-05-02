package api

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/Teddy-Zhu/magent/agent/internal/gitservice"
	"github.com/Teddy-Zhu/magent/agent/internal/provider"
)

func TestIsUntrackedPath(t *testing.T) {
	repo := t.TempDir()
	runGit(t, repo, "init")
	runGit(t, repo, "config", "user.email", "test@example.com")
	runGit(t, repo, "config", "user.name", "Test")

	if err := os.WriteFile(filepath.Join(repo, "tracked.txt"), []byte("tracked\n"), 0o600); err != nil {
		t.Fatalf("write tracked: %v", err)
	}
	runGit(t, repo, "add", "tracked.txt")
	runGit(t, repo, "commit", "-m", "initial")

	if err := os.WriteFile(filepath.Join(repo, "new.txt"), []byte("new\n"), 0o600); err != nil {
		t.Fatalf("write new: %v", err)
	}

	service := gitservice.NewService(nil)
	if !isUntrackedPath(context.Background(), service, repo, "new.txt") {
		t.Fatalf("new.txt should be untracked")
	}
	if isUntrackedPath(context.Background(), service, repo, "tracked.txt") {
		t.Fatalf("tracked.txt should not be untracked")
	}
}

func TestCommitMessageFromPayloadUsesCompletedTextAsFinalMessage(t *testing.T) {
	message := ""
	for _, delta := range []string{"feat", ":", " add", " session"} {
		message = mergeCommitMessageEvent(message, string(provider.EventMessageDelta), map[string]any{
			"delta": delta,
		})
	}

	message = mergeCommitMessageEvent(message, string(provider.EventMessage), map[string]any{
		"type": "agentMessage",
		"text": "feat: add session",
	})

	if message != "feat: add session" {
		t.Fatalf("message = %q, want completed text without duplicate", message)
	}
}

func TestCommitMessageFromPayloadFallsBackToContent(t *testing.T) {
	got := commitMessageFromPayload(map[string]any{
		"content": "fix: handle archived sessions",
	})
	if got != "fix: handle archived sessions" {
		t.Fatalf("message = %q", got)
	}
}

func runGit(t *testing.T, dir string, args ...string) {
	t.Helper()
	cmd := exec.Command("git", args...)
	cmd.Dir = dir
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git %v failed: %v\n%s", args, err, out)
	}
}
