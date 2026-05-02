package gitservice

import (
	"context"
	"os/exec"

	"github.com/Teddy-Zhu/magent/agent/internal/storage"
)

type Service struct {
	db        *storage.SQLite
	diffCache *diffCache
}

func NewService(db *storage.SQLite) *Service {
	return &Service{
		db:        db,
		diffCache: newDiffCache(defaultDiffCacheCap),
	}
}

func (s *Service) Git(ctx context.Context, dir string, args ...string) ([]byte, error) {
	// -c core.quotepath=false: prevent git from escaping non-ASCII paths (e.g. Chinese filenames)
	// -c log.showSignature=false: skip GPG signature verification in log output
	fullArgs := append([]string{"-c", "core.quotepath=false", "-c", "log.showSignature=false"}, args...)
	cmd := exec.CommandContext(ctx, "git", fullArgs...)
	cmd.Dir = dir
	return cmd.CombinedOutput()
}
