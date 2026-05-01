package provider

import (
	"context"
	"fmt"
	"sync"
)

type Registry struct {
	providers map[string]Provider
	mu        sync.RWMutex
}

func NewRegistry() *Registry {
	return &Registry{
		providers: make(map[string]Provider),
	}
}

func (r *Registry) Register(name string, p Provider) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.providers[name] = p
}

func (r *Registry) Get(name string) (Provider, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	p, ok := r.providers[name]
	if !ok {
		return nil, fmt.Errorf("provider %q not found", name)
	}
	return p, nil
}

// ListProviders returns all registered providers.
func (r *Registry) ListProviders() []Provider {
	r.mu.RLock()
	defer r.mu.RUnlock()
	var result []Provider
	for _, p := range r.providers {
		result = append(result, p)
	}
	return result
}

func (r *Registry) List() []ProviderInfo {
	r.mu.RLock()
	defer r.mu.RUnlock()
	var infos []ProviderInfo
	for _, p := range r.providers {
		info, err := p.Detect(context.Background())
		if err != nil {
			infos = append(infos, ProviderInfo{
				Name:   p.Name(),
				Status: "unavailable",
				Error:  err.Error(),
			})
		} else {
			infos = append(infos, *info)
		}
	}
	return infos
}
