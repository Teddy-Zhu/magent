package ws

import (
	"context"
	"encoding/json"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/Teddy-Zhu/magent/agent/internal/log"
)

const defaultReplayCap = 512

type Hub struct {
	clients     map[*Client]bool
	register    chan *Client
	unregister  chan *Client
	broadcast   chan []byte
	mu          sync.RWMutex
	maxPerToken int

	replayMu  sync.RWMutex
	replayID  string
	replaySeq uint64
	replayCap int
	replay    map[string][]replayMessage
}

type replayMessage struct {
	seq  uint64
	data []byte
}

func NewHub() *Hub {
	return &Hub{
		clients:     make(map[*Client]bool),
		register:    make(chan *Client),
		unregister:  make(chan *Client),
		broadcast:   make(chan []byte, 256),
		maxPerToken: 5,
		replayID:    strconv.FormatInt(time.Now().UnixNano(), 36),
		replayCap:   defaultReplayCap,
		replay:      make(map[string][]replayMessage),
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
				if client.ShouldReceive(msg) {
					client.Send(msg)
				}
			}
			h.mu.RUnlock()
		case <-ctx.Done():
			log.Debug("ws", "hub stopped")
			return
		}
	}
}

func (h *Hub) Broadcast(event any) {
	data := h.prepareBroadcast(event)
	log.Debug("ws", "broadcast len=%d clients=%d", len(data), h.ClientCount())
	h.broadcast <- data
}

func (h *Hub) prepareBroadcast(event any) []byte {
	data, _ := json.Marshal(event)

	var envelope map[string]any
	if err := json.Unmarshal(data, &envelope); err != nil {
		return data
	}

	sessionID := sessionIDFromEnvelope(envelope)
	if sessionID == "" {
		return data
	}

	h.replayMu.Lock()
	defer h.replayMu.Unlock()

	h.replaySeq++
	seq := h.replaySeq
	envelope["ws_epoch"] = h.replayID
	envelope["ws_seq"] = seq
	envelope["ws_cursor"] = h.replayCursor(seq)

	data, _ = json.Marshal(envelope)
	messages := append(h.replay[sessionID], replayMessage{seq: seq, data: data})
	if len(messages) > h.replayCap {
		messages = messages[len(messages)-h.replayCap:]
	}
	h.replay[sessionID] = messages
	return data
}

func sessionIDFromEnvelope(envelope map[string]any) string {
	if id, ok := envelope["session_id"].(string); ok && id != "" {
		return id
	}
	if data, ok := envelope["data"].(map[string]any); ok {
		if id, ok := data["session_id"].(string); ok && id != "" {
			return id
		}
	}
	return ""
}

func (h *Hub) ReplaySession(client *Client, sessionID, cursor string) {
	if sessionID == "" || cursor == "" {
		return
	}

	epoch, seq, err := h.parseReplayCursor(cursor)
	if err != nil {
		h.sendSyncRequired(client, sessionID, cursor, "invalid_cursor", 0, h.latestReplaySeq())
		return
	}
	if epoch != "" && epoch != h.replayID {
		h.sendSyncRequired(client, sessionID, cursor, "replay_epoch_changed", 0, h.latestReplaySeq())
		return
	}

	h.replayMu.RLock()
	messages := h.replay[sessionID]
	latest := h.replaySeq
	if len(messages) == 0 {
		h.replayMu.RUnlock()
		if seq > 0 {
			h.sendSyncRequired(client, sessionID, cursor, "replay_unavailable", 0, latest)
		}
		return
	}

	oldest := messages[0].seq
	newest := messages[len(messages)-1].seq
	if seq > latest || seq+1 < oldest {
		h.replayMu.RUnlock()
		h.sendSyncRequired(client, sessionID, cursor, "replay_gap", oldest, latest)
		return
	}

	replay := make([][]byte, 0, len(messages))
	for _, msg := range messages {
		if msg.seq > seq {
			data := make([]byte, len(msg.data))
			copy(data, msg.data)
			replay = append(replay, data)
		}
	}
	h.replayMu.RUnlock()

	for _, data := range replay {
		client.Send(data)
	}

	client.sendJSON(map[string]any{
		"type":          "session.replay_complete",
		"session_id":    sessionID,
		"ws_epoch":      h.replayID,
		"from_ws_seq":   seq,
		"latest_ws_seq": newest,
		"replayed":      len(replay),
	})
}

func (h *Hub) replayCursor(seq uint64) string {
	return h.replayID + ":" + strconv.FormatUint(seq, 10)
}

func (h *Hub) parseReplayCursor(cursor string) (string, uint64, error) {
	if before, after, ok := strings.Cut(cursor, ":"); ok {
		seq, err := strconv.ParseUint(after, 10, 64)
		return before, seq, err
	}
	seq, err := strconv.ParseUint(cursor, 10, 64)
	return "", seq, err
}

func (h *Hub) latestReplaySeq() uint64 {
	h.replayMu.RLock()
	defer h.replayMu.RUnlock()
	return h.replaySeq
}

func (h *Hub) sendSyncRequired(client *Client, sessionID, cursor, reason string, oldest, latest uint64) {
	client.sendJSON(map[string]any{
		"type":          "session.sync_required",
		"session_id":    sessionID,
		"ws_epoch":      h.replayID,
		"cursor":        cursor,
		"reason":        reason,
		"oldest_ws_seq": oldest,
		"latest_ws_seq": latest,
	})
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
