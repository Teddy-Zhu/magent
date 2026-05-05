package provider

import (
	"context"
	"fmt"
	"time"
)

type Provider interface {
	Name() string
	Detect(ctx context.Context) (*ProviderInfo, error)
	CreateSession(ctx context.Context, req CreateSessionRequest) (*Session, error)
	ResumeSession(ctx context.Context, sessionID, threadID string) error
	ForkSession(ctx context.Context, sessionID, threadID string) (string, error)
	SendInput(ctx context.Context, sessionID string, input SendInputRequest) error
	InterruptSession(ctx context.Context, sessionID string) error
	StopSession(ctx context.Context, sessionID string) error
	CompactSession(ctx context.Context, sessionID string) error
	RollbackSession(ctx context.Context, sessionID string, turns int) error
	ListThreads(ctx context.Context, cwd string, limit int) ([]Session, error)
	HasSession(sessionID string) bool
	ReadThreadEvents(ctx context.Context, threadID, cursor string, limit int) (*EventPage, error)
	ReadThreadItems(ctx context.Context, threadID, cursor string, limit int) (*ItemPage, error)
	ResolveApproval(ctx context.Context, sessionID, approvalID string, decision ApprovalDecision) error
	Subscribe(sessionID string) <-chan ProviderEvent
	Unsubscribe(sessionID string)
	Capabilities() ProviderCapabilities
	Config() ProviderConfig
	Close() error
}

type ThreadItemSnapshotReader interface {
	ReadThreadItemsSnapshot(ctx context.Context, threadID string, limit int) (*ItemPage, error)
}

type SessionMetadataUpdater interface {
	UpdateSessionMetadata(session Session)
}

type ThreadListOptions struct {
	CWD      string
	Limit    int
	Archived bool
}

type ThreadListerWithOptions interface {
	ListThreadsWithOptions(ctx context.Context, opts ThreadListOptions) ([]Session, error)
}

type ThreadArchiver interface {
	ArchiveSession(ctx context.Context, sessionID string) error
	UnarchiveSession(ctx context.Context, sessionID string) (*Session, error)
}

type ThreadDeleter interface {
	DeleteSession(ctx context.Context, sessionID string) error
}

type ModelInfo struct {
	ID               string   `json:"id"`
	Name             string   `json:"name"`
	Default          bool     `json:"default,omitempty"`
	ReasoningEfforts []string `json:"reasoning_efforts,omitempty"`
}

type ProviderConfig struct {
	Models           []ModelInfo `json:"models,omitempty"`
	ApprovalPolicies []string    `json:"approval_policies,omitempty"`
	SandboxModes     []string    `json:"sandbox_modes,omitempty"`
	Requirements     any         `json:"requirements,omitempty"`
	Skills           any         `json:"skills,omitempty"`
	MCPServers       any         `json:"mcp_servers,omitempty"`
}

type CreateSessionRequest struct {
	ProjectID      string         `json:"project_id"`
	Purpose        string         `json:"purpose,omitempty"`
	Workdir        string         `json:"workdir"`
	Model          string         `json:"model"`
	Effort         string         `json:"effort,omitempty"`
	ApprovalPolicy string         `json:"approval_policy"`
	SandboxMode    string         `json:"sandbox_mode"`
	Prompt         string         `json:"prompt"`
	Config         map[string]any `json:"config,omitempty"`
}

type InputItem map[string]any

type SendInputRequest struct {
	Input string      `json:"input"`
	Items []InputItem `json:"items,omitempty"`
	Mode  string      `json:"mode,omitempty"`

	// 以下字段用于"per-send 设置覆盖"。客户端持有当前会话的 model / effort /
	// approval / sandbox 选择并随每次发送上传；后端不持久化，仅作用于本次启动
	// 的 turn。空字符串表示"按 provider 既有设置（sessionMeta）"。
	Model          string `json:"model,omitempty"`
	Effort         string `json:"effort,omitempty"`
	ApprovalPolicy string `json:"approval_policy,omitempty"`
	SandboxMode    string `json:"sandbox_mode,omitempty"`
}

func (r *CreateSessionRequest) ApplyDefaults(cfg ProviderConfig) {
	if r.Model == "" {
		for _, model := range cfg.Models {
			if model.Default && model.ID != "" {
				r.Model = model.ID
				break
			}
		}
		if r.Model == "" {
			for _, model := range cfg.Models {
				if model.ID != "" {
					r.Model = model.ID
					break
				}
			}
		}
	}
	r.ApprovalPolicy = NormalizeApprovalPolicy(r.ApprovalPolicy)
	r.SandboxMode = NormalizeSandboxMode(r.SandboxMode)
}

func (r CreateSessionRequest) Validate() error {
	if r.Workdir == "" {
		return fmt.Errorf("workdir is required")
	}
	return nil
}

type ProviderEvent struct {
	SessionID string    `json:"session_id"`
	Cursor    string    `json:"cursor,omitempty"`
	Type      string    `json:"type"`
	ItemID    string    `json:"item_id,omitempty"`
	TurnID    string    `json:"turn_id,omitempty"`
	Payload   any       `json:"payload"`
	Timestamp time.Time `json:"timestamp"`
}

type EventPage struct {
	SessionID string          `json:"session_id"`
	Cursor    string          `json:"cursor"`
	HasMore   bool            `json:"has_more"`
	Events    []ProviderEvent `json:"events"`
}

type SessionItem struct {
	Cursor    string    `json:"cursor,omitempty"`
	ItemID    string    `json:"item_id"`
	TurnID    string    `json:"turn_id,omitempty"`
	Index     int       `json:"index"`
	Revision  int64     `json:"revision,omitempty"`
	Type      string    `json:"type"`
	Status    string    `json:"status,omitempty"`
	Role      string    `json:"role,omitempty"`
	Summary   string    `json:"summary,omitempty"`
	Content   any       `json:"content,omitempty"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

type ItemPage struct {
	SessionID string        `json:"session_id"`
	Cursor    string        `json:"cursor"`
	HasMore   bool          `json:"has_more"`
	Items     []SessionItem `json:"items"`
}

type ApprovalDecision struct {
	Action  string `json:"action"`
	Message string `json:"message,omitempty"`
	Raw     any    `json:"-"`
}

type ProviderInfo struct {
	Name         string               `json:"name"`
	Version      string               `json:"version"`
	Binary       string               `json:"binary"`
	Status       string               `json:"status"`
	RunMode      string               `json:"run_mode"`
	Error        string               `json:"error,omitempty"`
	Capabilities ProviderCapabilities `json:"capabilities"`
}

type ProviderCapabilities struct {
	Protocol               string `json:"protocol"`
	SupportsResume         bool   `json:"supports_resume"`
	SupportsFork           bool   `json:"supports_fork"`
	SupportsSteer          bool   `json:"supports_steer"`
	SupportsInterrupt      bool   `json:"supports_interrupt"`
	SupportsCompact        bool   `json:"supports_compact"`
	SupportsRollback       bool   `json:"supports_rollback"`
	SupportsApproval       bool   `json:"supports_approval"`
	SupportsFileSystem     bool   `json:"supports_file_system"`
	SupportsMCP            bool   `json:"supports_mcp"`
	SupportsCommand        bool   `json:"supports_command"`
	SupportsModelSwitch    bool   `json:"supports_model_switch"`
	SupportsSandboxConfig  bool   `json:"supports_sandbox_config"`
	SupportsApprovalPolicy bool   `json:"supports_approval_policy"`
	StructuredOutput       bool   `json:"structured_output"`
	StreamingOutput        bool   `json:"streaming_output"`
	SupportsPTY            bool   `json:"supports_pty"`
}

type Session struct {
	ID             string         `json:"id"`
	ProviderID     string         `json:"provider_id"`
	ThreadID       string         `json:"thread_id"`
	ProjectID      string         `json:"project_id"`
	Purpose        string         `json:"purpose,omitempty"`
	Title          string         `json:"title"`
	Workdir        string         `json:"workdir"`
	Status         string         `json:"status"`
	RunnerType     string         `json:"runner_type"`
	Source         string         `json:"source,omitempty"`
	Model          string         `json:"model"`
	Effort         string         `json:"effort,omitempty"`
	ApprovalPolicy string         `json:"approval_policy"`
	SandboxMode    string         `json:"sandbox_mode"`
	Config         map[string]any `json:"config,omitempty"`
	CreatedAt      time.Time      `json:"created_at"`
	UpdatedAt      time.Time      `json:"updated_at"`
	ExitedAt       *time.Time     `json:"exited_at,omitempty"`
	ArchivedAt     *time.Time     `json:"archived_at,omitempty"`
}
