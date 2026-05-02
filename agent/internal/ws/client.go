package ws

import (
	"encoding/json"
	"sync"
	"time"

	"github.com/Teddy-Zhu/magent/agent/internal/log"
	"github.com/gorilla/websocket"
)

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = 30 * time.Second
	maxMessageSize = 1 << 20 // 1MB
)

type Client struct {
	hub        *Hub
	conn       *websocket.Conn
	send       chan []byte
	tokenName  string
	lastPong   time.Time
	sessionsMu sync.RWMutex
	sessions   map[string]string
}

func NewClient(hub *Hub, conn *websocket.Conn, tokenName string) *Client {
	return &Client{
		hub:       hub,
		conn:      conn,
		send:      make(chan []byte, 256),
		tokenName: tokenName,
		lastPong:  time.Now(),
		sessions:  make(map[string]string),
	}
}

func (c *Client) Send(msg []byte) {
	select {
	case c.send <- msg:
	default:
		log.Warn("ws", "send queue full token=%s, unregistering client", c.tokenName)
		go func() {
			c.hub.unregister <- c
		}()
	}
}

func (c *Client) MessagesForTest() <-chan []byte {
	return c.send
}

func (c *Client) ShouldReceive(msg []byte) bool {
	var envelope struct {
		SessionID string `json:"session_id"`
		Data      struct {
			SessionID string `json:"session_id"`
		} `json:"data"`
	}
	if err := json.Unmarshal(msg, &envelope); err != nil {
		return true
	}
	sessionID := envelope.SessionID
	if sessionID == "" {
		sessionID = envelope.Data.SessionID
	}
	if sessionID == "" {
		return true
	}
	c.sessionsMu.RLock()
	defer c.sessionsMu.RUnlock()
	if len(c.sessions) == 0 {
		return true
	}
	_, ok := c.sessions[sessionID]
	return ok
}

func (c *Client) ReadPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()
	c.conn.SetReadLimit(maxMessageSize)
	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		c.lastPong = time.Now()
		c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})
	for {
		_, msg, err := c.conn.ReadMessage()
		if err != nil {
			break
		}
		c.handleMessage(msg)
	}
}

func (c *Client) handleMessage(data []byte) {
	var msg struct {
		Type         string `json:"type"`
		SessionID    string `json:"session_id"`
		Cursor       string `json:"cursor"`
		OpenSessions []struct {
			SessionID string `json:"session_id"`
			Cursor    string `json:"cursor"`
		} `json:"open_sessions"`
	}
	if err := json.Unmarshal(data, &msg); err != nil {
		log.Warn("ws", "invalid client message token=%s err=%v", c.tokenName, err)
		c.sendJSON(map[string]any{"type": "error", "code": "INVALID_MESSAGE", "message": "invalid json"})
		return
	}

	switch msg.Type {
	case "client.hello":
		c.sessionsMu.Lock()
		for _, session := range msg.OpenSessions {
			if session.SessionID != "" {
				c.sessions[session.SessionID] = session.Cursor
			}
		}
		c.sessionsMu.Unlock()
		c.sendJSON(map[string]any{
			"type":          "server.hello",
			"subscriptions": c.sessionIDs(),
		})
		for _, session := range msg.OpenSessions {
			if session.SessionID != "" {
				c.hub.ReplaySession(c, session.SessionID, session.Cursor)
			}
		}
	case "session.subscribe":
		if msg.SessionID != "" {
			c.sessionsMu.Lock()
			c.sessions[msg.SessionID] = msg.Cursor
			c.sessionsMu.Unlock()
		}
		c.sendJSON(map[string]any{
			"type":       "session.subscribed",
			"session_id": msg.SessionID,
		})
		c.hub.ReplaySession(c, msg.SessionID, msg.Cursor)
	case "session.unsubscribe":
		c.sessionsMu.Lock()
		delete(c.sessions, msg.SessionID)
		c.sessionsMu.Unlock()
		c.sendJSON(map[string]any{
			"type":       "session.unsubscribed",
			"session_id": msg.SessionID,
		})
	default:
		c.sendJSON(map[string]any{"type": "error", "code": "UNKNOWN_MESSAGE_TYPE", "message": "unknown message type"})
	}
}

func (c *Client) sessionIDs() []string {
	c.sessionsMu.RLock()
	defer c.sessionsMu.RUnlock()
	ids := make([]string, 0, len(c.sessions))
	for id := range c.sessions {
		ids = append(ids, id)
	}
	return ids
}

func (c *Client) sendJSON(event any) {
	data, err := json.Marshal(event)
	if err != nil {
		return
	}
	c.Send(data)
}

func (c *Client) WritePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()
	for {
		select {
		case msg, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			c.conn.WriteMessage(websocket.TextMessage, msg)
		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
