package codex

import (
	"context"
	"sync"
	"time"

	"github.com/magent/agent/internal/ws"
)

type ApprovalProxy struct {
	wsHub        *ws.Hub
	pending      map[string]chan ApprovalDecision
	pendingMu    sync.RWMutex
	sessionRules map[string]map[string]bool
	mu           sync.RWMutex
}

type ApprovalRequest struct {
	ID        string `json:"id"`
	SessionID string `json:"session_id"`
	ThreadID  string `json:"thread_id"`
	Type      string `json:"type"`
	Command   string `json:"command,omitempty"`
	FilePath  string `json:"file_path,omitempty"`
	CWD       string `json:"cwd,omitempty"`
}

type ApprovalDecision struct {
	Action  string `json:"action"`
	Message string `json:"message,omitempty"`
}

func NewApprovalProxy(hub *ws.Hub) *ApprovalProxy {
	return &ApprovalProxy{
		wsHub:        hub,
		pending:      make(map[string]chan ApprovalDecision),
		sessionRules: make(map[string]map[string]bool),
	}
}

func (p *ApprovalProxy) HandleRequest(ctx context.Context, req ApprovalRequest) ApprovalDecision {
	p.mu.RLock()
	if rules, ok := p.sessionRules[req.SessionID]; ok {
		if allowed, exists := rules[req.Command]; exists && allowed {
			p.mu.RUnlock()
			return ApprovalDecision{Action: "accept"}
		}
	}
	p.mu.RUnlock()

	return p.forwardToMobile(ctx, req)
}

func (p *ApprovalProxy) forwardToMobile(ctx context.Context, req ApprovalRequest) ApprovalDecision {
	ch := make(chan ApprovalDecision, 1)
	p.pendingMu.Lock()
	p.pending[req.ID] = ch
	p.pendingMu.Unlock()

	defer func() {
		p.pendingMu.Lock()
		delete(p.pending, req.ID)
		p.pendingMu.Unlock()
	}()

	p.wsHub.Broadcast(map[string]any{
		"type": "session.approval_request",
		"data": req,
	})

	select {
	case decision := <-ch:
		if decision.Action == "acceptForSession" {
			p.mu.Lock()
			if p.sessionRules[req.SessionID] == nil {
				p.sessionRules[req.SessionID] = make(map[string]bool)
			}
			p.sessionRules[req.SessionID][req.Command] = true
			p.mu.Unlock()
			decision.Action = "accept"
		}
		return decision
	case <-time.After(120 * time.Second):
		return ApprovalDecision{Action: "decline", Message: "approval timeout"}
	case <-ctx.Done():
		return ApprovalDecision{Action: "cancel"}
	}
}

func (p *ApprovalProxy) Resolve(approvalID string, decision ApprovalDecision) {
	p.pendingMu.RLock()
	ch, ok := p.pending[approvalID]
	p.pendingMu.RUnlock()
	if ok {
		ch <- decision
	}
}
