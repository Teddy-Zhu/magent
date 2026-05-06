package fileservice

import (
	"context"
	"os"
	"path/filepath"
	"strings"
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
	hash := result.Hash

	result, status, err = service.ReadRawFile(context.Background(), root, "large.bin", "", 0, 0)
	if err == nil || status != 413 {
		t.Fatalf("expected default large raw preview rejection, status=%d err=%v", status, err)
	}

	_, status, err = service.ReadRawFile(context.Background(), root, "large.bin", hash, 0, 20)
	if err != nil || status != 304 {
		t.Fatalf("expected 304 for known hash, status=%d err=%v", status, err)
	}
}

func TestReadFileHandlesLongLinesAcrossBufferBoundaries(t *testing.T) {
	root := t.TempDir()
	content := strings.Repeat("a", 40*1024) + "\nsecond\n"
	if err := os.WriteFile(filepath.Join(root, "go.work.sum"), []byte(content), 0o600); err != nil {
		t.Fatalf("write go.work.sum: %v", err)
	}

	service := NewService(nil, nil)
	result, status, err := service.ReadFile(context.Background(), root, "go.work.sum", "", 0, 10)
	if err != nil || status != 200 {
		t.Fatalf("ReadFile status=%d err=%v", status, err)
	}
	if result.TotalLines != 2 {
		t.Fatalf("total lines = %d, want 2", result.TotalLines)
	}
	if len(result.Content) == 0 || !strings.Contains(result.Content, "\nsecond") {
		t.Fatalf("unexpected content suffix: len=%d", len(result.Content))
	}
}

func TestReadFileRejectsBinaryAndLargePreviews(t *testing.T) {
	root := t.TempDir()
	if err := os.WriteFile(filepath.Join(root, "image.bin"), []byte{0x00, 0x01, 0x02}, 0o600); err != nil {
		t.Fatalf("write binary: %v", err)
	}
	if err := os.WriteFile(filepath.Join(root, "large.txt"), bytesOf('x', DefaultPreviewFileLimit+1), 0o600); err != nil {
		t.Fatalf("write large: %v", err)
	}

	service := NewService(nil, nil)
	if _, status, err := service.ReadFile(context.Background(), root, "image.bin", "", 0, 10); err == nil || status != 415 {
		t.Fatalf("expected binary rejection, status=%d err=%v", status, err)
	}
	if _, status, err := service.ReadFile(context.Background(), root, "large.txt", "", 0, 10); err == nil || status != 413 {
		t.Fatalf("expected large preview rejection, status=%d err=%v", status, err)
	}
	if _, status, err := service.ReadRawFile(context.Background(), root, "image.bin", "", 0, 1); err == nil || status != 415 {
		t.Fatalf("expected binary raw rejection, status=%d err=%v", status, err)
	}
}

func TestReadFileAllowsTextContentWithBinaryLookingExtension(t *testing.T) {
	root := t.TempDir()
	if err := os.WriteFile(filepath.Join(root, "notes.bin"), []byte("plain text\n"), 0o600); err != nil {
		t.Fatalf("write text-ish bin: %v", err)
	}

	service := NewService(nil, nil)
	result, status, err := service.ReadFile(context.Background(), root, "notes.bin", "", 0, 10)
	if err != nil || status != 200 {
		t.Fatalf("ReadFile status=%d err=%v", status, err)
	}
	if result.Content != "plain text" {
		t.Fatalf("content = %q", result.Content)
	}
}

func TestReadRawFileAllowsSmallPreviewImages(t *testing.T) {
	root := t.TempDir()
	png := []byte{0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n'}
	if err := os.WriteFile(filepath.Join(root, "image.png"), png, 0o600); err != nil {
		t.Fatalf("write png: %v", err)
	}

	service := NewService(nil, nil)
	result, status, err := service.ReadRawFile(context.Background(), root, "image.png", "", 0, 0)
	if err != nil || status != 200 {
		t.Fatalf("ReadRawFile status=%d err=%v", status, err)
	}
	if string(result.Data) != string(png) {
		t.Fatalf("unexpected image bytes: %v", result.Data)
	}
}

func bytesOf(value byte, n int) []byte {
	data := make([]byte, n)
	for i := range data {
		data[i] = value
	}
	return data
}
