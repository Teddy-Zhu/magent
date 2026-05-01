package api

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/magent/agent/internal/gitservice"
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

func runGit(t *testing.T, dir string, args ...string) {
	t.Helper()
	cmd := exec.Command("git", args...)
	cmd.Dir = dir
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git %v failed: %v\n%s", args, err, out)
	}
}
