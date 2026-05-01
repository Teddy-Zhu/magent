package protocol

import (
	"encoding/json"
	"sync"
)

type JSONRPCRequest struct {
	JSONRPC string `json:"jsonrpc"`
	Method  string `json:"method"`
	ID      *int64 `json:"id,omitempty"`
	Params  any    `json:"params,omitempty"`
}

type JSONRPCResponse struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      *int64          `json:"id,omitempty"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *JSONRPCError   `json:"error,omitempty"`
	Method  string          `json:"method,omitempty"`
	Params  json.RawMessage `json:"params,omitempty"`
}

type JSONRPCError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    any    `json:"data,omitempty"`
}

type RequestIDGenerator struct {
	counter int64
	mu      sync.Mutex
}

func (g *RequestIDGenerator) Next() int64 {
	g.mu.Lock()
	defer g.mu.Unlock()
	g.counter++
	return g.counter
}
