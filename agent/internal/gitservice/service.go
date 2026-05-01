package gitservice

import (
	"context"
	"os/exec"
	"sync"

	"github.com/magent/agent/internal/storage"
)

type Service struct {
	db        *storage.SQLite
	watchers  map[string]*GitWatcher
	diffCache *diffCache
	mu        sync.RWMutex
}

func NewService(db *storage.SQLite) *Service {
	return &Service{
		db:        db,
		watchers:  make(map[string]*GitWatcher),
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

func (s *Service) StartWatcher(projectID, projectPath string, onChange func(*GitSummary)) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, ok := s.watchers[projectID]; ok {
		return nil
	}

	watcher, err := NewGitWatcher(projectID, projectPath, s, onChange)
	if err != nil {
		return err
	}

	s.watchers[projectID] = watcher
	return nil
}

func (s *Service) StopWatcher(projectID string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if watcher, ok := s.watchers[projectID]; ok {
		watcher.Close()
		delete(s.watchers, projectID)
	}
}
