package gitservice

import (
	"context"
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
	timers      map[string]*time.Timer
	mu          sync.Mutex
	onChange    func(*GitSummary)
}

func NewGitWatcher(projectID, projectPath string, service *Service, onChange func(*GitSummary)) (*GitWatcher, error) {
	fsWatcher, err := fsnotify.NewWatcher()
	if err != nil {
		return nil, err
	}

	fsWatcher.Add(filepath.Join(projectPath, ".git", "index"))
	fsWatcher.Add(filepath.Join(projectPath, ".git", "HEAD"))
	fsWatcher.Add(filepath.Join(projectPath, ".git", "refs"))

	log.Debug("gitwatcher", "starting project=%s path=%s", projectID, projectPath)
	w := &GitWatcher{
		projectID:   projectID,
		projectPath: projectPath,
		service:     service,
		fsWatcher:   fsWatcher,
		debounce:    500 * time.Millisecond,
		timers:      make(map[string]*time.Timer),
		onChange:    onChange,
	}

	go w.loop()
	return w, nil
}

func (w *GitWatcher) loop() {
	for {
		select {
		case event := <-w.fsWatcher.Events:
			log.Debug("gitwatcher", "event project=%s op=%s file=%s", w.projectID, event.Op, event.Name)
			w.mu.Lock()
			if timer, ok := w.timers[event.Name]; ok {
				timer.Stop()
			}
			w.timers[event.Name] = time.AfterFunc(w.debounce, func() {
				w.refresh()
			})
			w.mu.Unlock()
		case err := <-w.fsWatcher.Errors:
			log.Error("gitwatcher", "error project=%s: %v", w.projectID, err)
		}
	}
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

	if w.onChange != nil {
		w.onChange(summary)
	}
}

func (w *GitWatcher) Close() {
	w.fsWatcher.Close()
}
