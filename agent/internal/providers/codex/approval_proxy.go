package codex

import (
	"context"
	"database/sql"
	"encoding/json"
	"sync"
	"time"

	"github.com/magent/agent/internal/provider"
	"github.com/magent/agent/internal/storage"
	"github.com/magent/agent/internal/ws"
)

type ApprovalProxy struct {
	wsHub     *ws.Hub
	store     *storage.SQLite
	pending   map[string]chan provider.ApprovalDecision
	pendingMu sync.RWMutex
}

type ApprovalRequest struct {
	ID        string `json:"id"`
	SessionID string `json:"session_id"`
	ThreadID  string `json:"thread_id"`
	TurnID    string `json:"turn_id,omitempty"`
	ItemID    string `json:"item_id,omitempty"`
	Type      string `json:"type"`
	Command   string `json:"command,omitempty"`
	FilePath  string `json:"file_path,omitempty"`
	CWD       string `json:"cwd,omitempty"`
	RequestID int64  `json:"-"`
}

func NewApprovalProxy(hub *ws.Hub, store *storage.SQLite) *ApprovalProxy {
	return &ApprovalProxy{
		wsHub:   hub,
		store:   store,
		pending: make(map[string]chan provider.ApprovalDecision),
	}
}

func (p *ApprovalProxy) HandleRequest(ctx context.Context, req ApprovalRequest) provider.ApprovalDecision {
	return p.forwardToMobile(ctx, req)
}

func (p *ApprovalProxy) forwardToMobile(ctx context.Context, req ApprovalRequest) provider.ApprovalDecision {
	ch := make(chan provider.ApprovalDecision, 1)
	p.pendingMu.Lock()
	p.pending[req.ID] = ch
	p.pendingMu.Unlock()
	p.savePending(req)

	defer func() {
		p.pendingMu.Lock()
		delete(p.pending, req.ID)
		p.pendingMu.Unlock()
	}()

	p.wsHub.Broadcast(map[string]any{
		"type":       "approval.requested",
		"session_id": req.SessionID,
		"data":       req,
	})

	select {
	case decision := <-ch:
		p.markResolved(req.ID, decision.Action)
		p.broadcastResolved(req, decision)
		return decision
	case <-time.After(120 * time.Second):
		decision := provider.ApprovalDecision{Action: "decline", Message: "approval timeout"}
		p.markResolved(req.ID, decision.Action)
		p.broadcastResolved(req, decision)
		return decision
	case <-ctx.Done():
		decision := provider.ApprovalDecision{Action: "cancel"}
		p.markResolved(req.ID, decision.Action)
		p.broadcastResolved(req, decision)
		return decision
	}
}

func (p *ApprovalProxy) Resolve(approvalID string, decision provider.ApprovalDecision) bool {
	p.pendingMu.RLock()
	ch, ok := p.pending[approvalID]
	p.pendingMu.RUnlock()
	if ok {
		ch <- decision
	}
	return ok
}

func (p *ApprovalProxy) savePending(req ApprovalRequest) {
	if p.store == nil {
		return
	}
	body, _ := json.Marshal(req)
	now := time.Now().Unix()
	_, _ = p.store.DB().Exec(`
		INSERT INTO pending_approvals (
			approval_id, session_id, thread_id, turn_id, item_id, codex_request_id,
			type, request_json, status, created_at, resolved_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, NULL)
		ON CONFLICT(approval_id) DO UPDATE SET
			session_id = excluded.session_id,
			thread_id = excluded.thread_id,
			turn_id = excluded.turn_id,
			item_id = excluded.item_id,
			type = excluded.type,
			request_json = excluded.request_json,
			status = 'pending',
			created_at = excluded.created_at,
			resolved_at = NULL`,
		req.ID, req.SessionID, req.ThreadID, nullableString(req.TurnID), nullableString(req.ItemID), req.RequestID,
		req.Type, string(body), now)
}

func (p *ApprovalProxy) markResolved(approvalID, decision string) {
	if p.store == nil {
		return
	}
	_, _ = p.store.DB().Exec(`
		UPDATE pending_approvals SET status = ?, resolved_at = ?
		WHERE approval_id = ? AND status = 'pending'`,
		"resolved:"+decision, time.Now().Unix(), approvalID)
}

func (p *ApprovalProxy) broadcastResolved(req ApprovalRequest, decision provider.ApprovalDecision) {
	p.wsHub.Broadcast(map[string]any{
		"type":        "approval.resolved",
		"session_id":  req.SessionID,
		"approval_id": req.ID,
		"decision":    decision.Action,
		"resolved_at": time.Now().Unix(),
	})
}

func nullableString(value string) sql.NullString {
	if value == "" {
		return sql.NullString{}
	}
	return sql.NullString{String: value, Valid: true}
}
