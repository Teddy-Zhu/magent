package project

import (
	"context"
	"database/sql"
	"errors"
	"path/filepath"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/Teddy-Zhu/magent/agent/internal/storage"
)

var (
	ErrPathTraversal = errors.New("path traversal detected")
	ErrPathNotAllowed = errors.New("path not in allowed directories")
)

type Manager struct {
	store         *storage.SQLite
	allowedDirs   []string
	excludedPatterns []string
}

func NewManager(store *storage.SQLite, allowedDirs, excludedPatterns []string) *Manager {
	return &Manager{
		store:           store,
		allowedDirs:     allowedDirs,
		excludedPatterns: excludedPatterns,
	}
}

func (m *Manager) Create(ctx context.Context, name, path string) (*Project, error) {
	if err := m.validatePath(path); err != nil {
		return nil, err
	}

	now := time.Now()
	p := &Project{
		ID:              uuid.New().String(),
		Name:            name,
		Path:            path,
		DefaultProvider: "codex",
		CreatedAt:       now,
		UpdatedAt:       now,
	}

	_, err := m.store.DB().ExecContext(ctx,
		`INSERT INTO projects (id, name, path, default_provider, created_at, updated_at)
		 VALUES (?, ?, ?, ?, ?, ?)`,
		p.ID, p.Name, p.Path, p.DefaultProvider, p.CreatedAt.Unix(), p.UpdatedAt.Unix(),
	)
	if err != nil {
		return nil, err
	}

	return p, nil
}

func (m *Manager) List(ctx context.Context) ([]Project, error) {
	rows, err := m.store.DB().QueryContext(ctx,
		`SELECT id, name, path, default_provider, created_at, updated_at FROM projects ORDER BY updated_at DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var projects []Project
	for rows.Next() {
		var p Project
		var createdAt, updatedAt int64
		if err := rows.Scan(&p.ID, &p.Name, &p.Path, &p.DefaultProvider, &createdAt, &updatedAt); err != nil {
			return nil, err
		}
		p.CreatedAt = time.Unix(createdAt, 0)
		p.UpdatedAt = time.Unix(updatedAt, 0)
		projects = append(projects, p)
	}

	return projects, nil
}

func (m *Manager) Get(ctx context.Context, id string) (*Project, error) {
	var p Project
	var createdAt, updatedAt int64
	err := m.store.DB().QueryRowContext(ctx,
		`SELECT id, name, path, default_provider, created_at, updated_at FROM projects WHERE id = ?`,
		id).Scan(&p.ID, &p.Name, &p.Path, &p.DefaultProvider, &createdAt, &updatedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	p.CreatedAt = time.Unix(createdAt, 0)
	p.UpdatedAt = time.Unix(updatedAt, 0)
	return &p, nil
}

func (m *Manager) Update(ctx context.Context, p *Project) error {
	p.UpdatedAt = time.Now()
	_, err := m.store.DB().ExecContext(ctx,
		`UPDATE projects SET name = ?, path = ?, default_provider = ?, updated_at = ? WHERE id = ?`,
		p.Name, p.Path, p.DefaultProvider, p.UpdatedAt.Unix(), p.ID)
	return err
}

func (m *Manager) Delete(ctx context.Context, id string) error {
	_, err := m.store.DB().ExecContext(ctx, `DELETE FROM projects WHERE id = ?`, id)
	return err
}

func (m *Manager) validatePath(path string) error {
	cleaned := filepath.Clean(path)
	if strings.Contains(cleaned, "..") {
		return ErrPathTraversal
	}

	// 如果设置了白名单，检查路径是否在白名单内
	if len(m.allowedDirs) > 0 {
		resolved, err := filepath.EvalSymlinks(cleaned)
		if err != nil {
			return err
		}
		allowed := false
		for _, dir := range m.allowedDirs {
			if strings.HasPrefix(resolved, filepath.Clean(dir)) {
				allowed = true
				break
			}
		}
		if !allowed {
			return ErrPathNotAllowed
		}
	}

	return nil
}
