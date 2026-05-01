package gitservice

import "testing"

func TestDiffCacheEvictsLeastRecentlyUsed(t *testing.T) {
	cache := newDiffCache(2)
	cache.Add("a", []DiffLine{{Type: "add", Content: "a"}})
	cache.Add("b", []DiffLine{{Type: "add", Content: "b"}})
	if _, ok := cache.Get("a"); !ok {
		t.Fatalf("expected a in cache")
	}
	cache.Add("c", []DiffLine{{Type: "add", Content: "c"}})
	if _, ok := cache.Get("b"); ok {
		t.Fatalf("expected b to be evicted")
	}
	if _, ok := cache.Get("a"); !ok {
		t.Fatalf("expected a to remain after recent access")
	}
	if _, ok := cache.Get("c"); !ok {
		t.Fatalf("expected c in cache")
	}
}

func TestDiffCacheReturnsClones(t *testing.T) {
	cache := newDiffCache(1)
	cache.Add("a", []DiffLine{{Type: "add", Content: "original"}})
	lines, ok := cache.Get("a")
	if !ok {
		t.Fatalf("expected cache hit")
	}
	lines[0].Content = "mutated"
	lines, ok = cache.Get("a")
	if !ok {
		t.Fatalf("expected cache hit")
	}
	if lines[0].Content != "original" {
		t.Fatalf("cache returned mutable backing slice")
	}
}
