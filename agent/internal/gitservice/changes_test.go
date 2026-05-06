package gitservice

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

func TestGetChangesMarksUntrackedBinaryFile(t *testing.T) {
	repo := t.TempDir()
	runGit(t, repo, "init")
	if err := os.WriteFile(filepath.Join(repo, "image.bin"), []byte{0x00, 0x01, 0x02}, 0o600); err != nil {
		t.Fatalf("write binary: %v", err)
	}

	service := NewService(nil)
	changes, err := service.computeChanges(context.Background(), repo, 1)
	if err != nil {
		t.Fatalf("computeChanges: %v", err)
	}
	if len(changes.Files) != 1 {
		t.Fatalf("files = %#v", changes.Files)
	}
	file := changes.Files[0]
	if file.Path != "image.bin" || file.Status != "untracked" || !file.Binary {
		t.Fatalf("unexpected file change: %#v", file)
	}
	if file.Size != 3 {
		t.Fatalf("size = %d, want 3", file.Size)
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
