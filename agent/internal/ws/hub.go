package ws

import (
	"context"
	"encoding/json"
	"sync"

	"github.com/magent/agent/internal/log"
)

type Hub struct {
	clients     map[*Client]bool
	register    chan *Client
	unregister  chan *Client
	broadcast   chan []byte
	mu          sync.RWMutex
	maxPerToken int
}

func NewHub() *Hub {
	return &Hub{
		clients:     make(map[*Client]bool),
		register:    make(chan *Client),
		unregister:  make(chan *Client),
		broadcast:   make(chan []byte, 256),
		maxPerToken: 5,
	}
}

func (h *Hub) canRegister(tokenName string) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	count := 0
	for c := range h.clients {
		if c.tokenName == tokenName {
			count++
		}
	}
	return count < h.maxPerToken
}

func (h *Hub) Run(ctx context.Context) {
	log.Debug("ws", "hub started")
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			h.clients[client] = true
			h.mu.Unlock()
			log.Debug("ws", "client registered token=%s total=%d", client.tokenName, len(h.clients))
		case client := <-h.unregister:
			h.mu.Lock()
			delete(h.clients, client)
			h.mu.Unlock()
			log.Debug("ws", "client unregistered token=%s total=%d", client.tokenName, len(h.clients))
		case msg := <-h.broadcast:
			h.mu.RLock()
			for client := range h.clients {
				client.Send(msg)
			}
			h.mu.RUnlock()
		case <-ctx.Done():
			log.Debug("ws", "hub stopped")
			return
		}
	}
}

func (h *Hub) Broadcast(event any) {
	data, _ := json.Marshal(event)
	log.Debug("ws", "broadcast len=%d clients=%d", len(data), h.ClientCount())
	h.broadcast <- data
}

func (h *Hub) SendTo(tokenName string, event any) {
	data, _ := json.Marshal(event)
	h.mu.RLock()
	defer h.mu.RUnlock()
	for client := range h.clients {
		if client.tokenName == tokenName {
			client.Send(data)
		}
	}
}

func (h *Hub) AddClient(client *Client) {
	h.register <- client
}

func (h *Hub) ClientCount() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.clients)
}
