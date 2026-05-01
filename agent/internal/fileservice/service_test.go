package fileservice

import (
	"context"
	"os"
	"path/filepath"
	"testing"
)

func TestValidatePathRejectsTraversalAndSymlinkEscape(t *testing.T) {
	root := t.TempDir()
	outside := t.TempDir()
	if err := os.WriteFile(filepath.Join(outside, "secret.txt"), []byte("secret"), 0o600); err != nil {
		t.Fatalf("write outside file: %v", err)
	}
	if err := os.Symlink(outside, filepath.Join(root, "outside-link")); err != nil {
		t.Skipf("symlink unavailable: %v", err)
	}

	service := NewService(nil, nil)
	if _, status, err := service.ReadFile(context.Background(), root, "../secret.txt", "", 0, 10); err == nil || status != 403 {
		t.Fatalf("expected traversal rejection, status=%d err=%v", status, err)
	}
	if _, status, err := service.ReadFile(context.Background(), root, "outside-link/secret.txt", "", 0, 10); err == nil || status != 403 {
		t.Fatalf("expected symlink escape rejection, status=%d err=%v", status, err)
	}
}

func TestReadRawFileSupportsHashRangeAndLimit(t *testing.T) {
	root := t.TempDir()
	if err := os.WriteFile(filepath.Join(root, "large.bin"), bytesOf('a', DefaultRawFileLimit+128), 0o600); err != nil {
		t.Fatalf("write large file: %v", err)
	}

	service := NewService(nil, nil)
	result, status, err := service.ReadRawFile(context.Background(), root, "large.bin", "", 10, 20)
	if err != nil || status != 200 {
		t.Fatalf("ReadRawFile status=%d err=%v", status, err)
	}
	if result.Offset != 10 || result.Limit != 20 || len(result.Data) != 20 {
		t.Fatalf("unexpected range result: offset=%d limit=%d len=%d", result.Offset, result.Limit, len(result.Data))
	}
	if !result.Truncated {
		t.Fatalf("expected truncated range")
	}

	result, status, err = service.ReadRawFile(context.Background(), root, "large.bin", "", 0, 0)
	if err != nil || status != 200 {
		t.Fatalf("ReadRawFile default status=%d err=%v", status, err)
	}
	if len(result.Data) != DefaultRawFileLimit || !result.Truncated {
		t.Fatalf("expected default max limit and truncated=true, len=%d truncated=%v", len(result.Data), result.Truncated)
	}

	_, status, err = service.ReadRawFile(context.Background(), root, "large.bin", result.Hash, 0, 20)
	if err != nil || status != 304 {
		t.Fatalf("expected 304 for known hash, status=%d err=%v", status, err)
	}
}

func bytesOf(value byte, n int) []byte {
	data := make([]byte, n)
	for i := range data {
		data[i] = value
	}
	return data
}
