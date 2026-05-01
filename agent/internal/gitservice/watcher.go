package gitservice

import (
	"context"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/fsnotify/fsnotify"
	"github.com/magent/agent/internal/log"
)

type GitWatcher struct {
	projectID   string
	projectPath string
	service     *Service
	fsWatcher   *fsnotify.Watcher
	debounce    time.Duration
	timer       *time.Timer
	mu          sync.Mutex
	onChange    func(*GitSummary)
	lastVersion int64
}

func NewGitWatcher(projectID, projectPath string, service *Service, onChange func(*GitSummary)) (*GitWatcher, error) {
	fsWatcher, err := fsnotify.NewWatcher()
	if err != nil {
		return nil, err
	}

	log.Debug("gitwatcher", "starting project=%s path=%s", projectID, projectPath)
	w := &GitWatcher{
		projectID:   projectID,
		projectPath: projectPath,
		service:     service,
		fsWatcher:   fsWatcher,
		debounce:    500 * time.Millisecond,
		onChange:    onChange,
	}

	if summary, err := service.GetSummary(context.Background(), projectID, projectPath); err == nil {
		w.lastVersion = summary.Version
	}
	w.addInitialWatches()

	go w.loop()
	return w, nil
}

func (w *GitWatcher) loop() {
	for {
		select {
		case event, ok := <-w.fsWatcher.Events:
			if !ok {
				return
			}
			log.Debug("gitwatcher", "event project=%s op=%s file=%s", w.projectID, event.Op, event.Name)
			if event.Op&fsnotify.Create != 0 {
				w.addDirectoryIfNeeded(event.Name)
			}
			w.scheduleRefresh()
		case err, ok := <-w.fsWatcher.Errors:
			if !ok {
				return
			}
			log.Error("gitwatcher", "error project=%s: %v", w.projectID, err)
		}
	}
}

func (w *GitWatcher) addInitialWatches() {
	w.addIfExists(filepath.Join(w.projectPath, ".git", "index"))
	w.addIfExists(filepath.Join(w.projectPath, ".git", "HEAD"))
	w.addRecursive(filepath.Join(w.projectPath, ".git", "refs"), true)
	w.addRecursive(w.projectPath, false)
}

func (w *GitWatcher) addIfExists(path string) {
	if _, err := os.Stat(path); err != nil {
		return
	}
	if err := w.fsWatcher.Add(path); err != nil {
		log.Warn("gitwatcher", "watch add failed project=%s path=%s err=%v", w.projectID, path, err)
	}
}

func (w *GitWatcher) addRecursive(root string, includeGit bool) {
	_ = filepath.WalkDir(root, func(path string, d os.DirEntry, err error) error {
		if err != nil || !d.IsDir() {
			return nil
		}
		if !includeGit && path != root && w.shouldSkipDir(d.Name()) {
			return filepath.SkipDir
		}
		if err := w.fsWatcher.Add(path); err != nil {
			log.Warn("gitwatcher", "watch add failed project=%s path=%s err=%v", w.projectID, path, err)
		}
		return nil
	})
}

func (w *GitWatcher) addDirectoryIfNeeded(path string) {
	info, err := os.Stat(path)
	if err != nil || !info.IsDir() {
		return
	}
	if w.shouldSkipDir(filepath.Base(path)) {
		return
	}
	w.addRecursive(path, false)
}

func (w *GitWatcher) shouldSkipDir(name string) bool {
	switch name {
	case ".git", "node_modules", ".dart_tool", "build", "dist", ".next", "target", "vendor":
		return true
	default:
		return false
	}
}

func (w *GitWatcher) scheduleRefresh() {
	w.mu.Lock()
	defer w.mu.Unlock()
	if w.timer != nil {
		w.timer.Stop()
	}
	w.timer = time.AfterFunc(w.debounce, w.refresh)
}

func (w *GitWatcher) refresh() {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	log.Debug("gitwatcher", "refresh project=%s", w.projectID)
	summary, err := w.service.GetSummary(ctx, w.projectID, w.projectPath)
	if err != nil {
		log.Error("gitwatcher", "refresh failed project=%s: %v", w.projectID, err)
		return
	}

	w.mu.Lock()
	if summary.Version == w.lastVersion {
		w.mu.Unlock()
		return
	}
	w.lastVersion = summary.Version
	w.mu.Unlock()

	if w.onChange != nil {
		w.onChange(summary)
	}
}

func (w *GitWatcher) Close() {
	w.mu.Lock()
	if w.timer != nil {
		w.timer.Stop()
	}
	w.mu.Unlock()
	w.fsWatcher.Close()
}
