package gitservice

import (
	"container/list"
	"sync"
)

const defaultDiffCacheCap = 64

type diffCache struct {
	capacity int
	mu       sync.Mutex
	ll       *list.List
	items    map[string]*list.Element
}

type diffCacheEntry struct {
	key   string
	lines []DiffLine
}

func newDiffCache(capacity int) *diffCache {
	if capacity <= 0 {
		capacity = defaultDiffCacheCap
	}
	return &diffCache{
		capacity: capacity,
		ll:       list.New(),
		items:    make(map[string]*list.Element),
	}
}

func (c *diffCache) Get(key string) ([]DiffLine, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	elem, ok := c.items[key]
	if !ok {
		return nil, false
	}
	c.ll.MoveToFront(elem)
	entry := elem.Value.(*diffCacheEntry)
	return cloneDiffLines(entry.lines), true
}

func (c *diffCache) Add(key string, lines []DiffLine) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if elem, ok := c.items[key]; ok {
		c.ll.MoveToFront(elem)
		elem.Value.(*diffCacheEntry).lines = cloneDiffLines(lines)
		return
	}
	elem := c.ll.PushFront(&diffCacheEntry{
		key:   key,
		lines: cloneDiffLines(lines),
	})
	c.items[key] = elem
	if c.ll.Len() <= c.capacity {
		return
	}
	tail := c.ll.Back()
	if tail == nil {
		return
	}
	c.ll.Remove(tail)
	delete(c.items, tail.Value.(*diffCacheEntry).key)
}

func cloneDiffLines(lines []DiffLine) []DiffLine {
	if lines == nil {
		return nil
	}
	cloned := make([]DiffLine, len(lines))
	copy(cloned, lines)
	return cloned
}
