package gitservice

import "testing"

func TestComputeGitVersionIsStableAndContentBased(t *testing.T) {
	version1 := ComputeGitVersion("head", "worktree-a", "index")
	version2 := ComputeGitVersion("head", "worktree-a", "index")
	if version1 != version2 {
		t.Fatalf("expected stable version, got %d and %d", version1, version2)
	}

	version3 := ComputeGitVersion("head", "worktree-b", "index")
	if version3 == version1 {
		t.Fatalf("expected version to change when worktree hash changes")
	}
}

func TestComputeDiffContentHashUsesContent(t *testing.T) {
	hash1 := ComputeDiffContentHash([]byte("diff --git a/a b/a\n+one\n"))
	hash2 := ComputeDiffContentHash([]byte("diff --git a/a b/a\n+one\n"))
	if hash1 != hash2 {
		t.Fatalf("expected stable diff hash, got %s and %s", hash1, hash2)
	}

	hash3 := ComputeDiffContentHash([]byte("diff --git a/a b/a\n+two\n"))
	if hash3 == hash1 {
		t.Fatalf("expected diff hash to change when diff content changes")
	}
}

func TestDiffOutputIsBinary(t *testing.T) {
	if !diffOutputIsBinary("Binary files /dev/null and image.bin differ\n") {
		t.Fatalf("expected binary diff output")
	}
	if diffOutputIsBinary("diff --git a/a.txt b/a.txt\n+hello\n") {
		t.Fatalf("expected text diff output")
	}
}
