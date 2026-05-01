package provider

import (
	"context"
	"time"
)

type Provider interface {
	Name() string
	Detect(ctx context.Context) (*ProviderInfo, error)
	CreateSession(ctx context.Context, req CreateSessionRequest) (*Session, error)
	ResumeSession(ctx context.Context, sessionID, threadID string) error
	ForkSession(ctx context.Context, sessionID, threadID string) (string, error)
	SendInput(ctx context.Context, sessionID, input string) error
	InterruptSession(ctx context.Context, sessionID string) error
	StopSession(ctx context.Context, sessionID string) error
	CompactSession(ctx context.Context, sessionID string) error
	RollbackSession(ctx context.Context, sessionID string, turns int) error
	Subscribe(sessionID string) <-chan ProviderEvent
	Unsubscribe(sessionID string)
	Capabilities() ProviderCapabilities
	Config() ProviderConfig
	Close() error
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
}

type CreateSessionRequest struct {
	ProjectID      string         `json:"project_id"`
	Workdir        string         `json:"workdir"`
	Model          string         `json:"model"`
	Effort         string         `json:"effort,omitempty"`
	ApprovalPolicy string         `json:"approval_policy"`
	SandboxMode    string         `json:"sandbox_mode"`
	Prompt         string         `json:"prompt"`
	Config         map[string]any `json:"config,omitempty"`
}

type ProviderEvent struct {
	SessionID string    `json:"session_id"`
	Type      string    `json:"type"`
	Payload   any       `json:"payload"`
	Timestamp time.Time `json:"timestamp"`
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
	Protocol           string `json:"protocol"`
	SupportsResume     bool   `json:"supports_resume"`
	SupportsFork       bool   `json:"supports_fork"`
	SupportsSteer      bool   `json:"supports_steer"`
	SupportsInterrupt  bool   `json:"supports_interrupt"`
	SupportsCompact    bool   `json:"supports_compact"`
	SupportsRollback   bool   `json:"supports_rollback"`
	SupportsApproval   bool   `json:"supports_approval"`
	SupportsFileSystem bool   `json:"supports_file_system"`
	SupportsMCP        bool   `json:"supports_mcp"`
	SupportsCommand    bool   `json:"supports_command"`
	SupportsModelSwitch    bool `json:"supports_model_switch"`
	SupportsSandboxConfig  bool `json:"supports_sandbox_config"`
	SupportsApprovalPolicy bool `json:"supports_approval_policy"`
	StructuredOutput   bool   `json:"structured_output"`
	StreamingOutput    bool   `json:"streaming_output"`
	SupportsPTY        bool   `json:"supports_pty"`
}

type Session struct {
	ID            string         `json:"id"`
	ProviderID    string         `json:"provider_id"`
	ThreadID      string         `json:"thread_id"`
	ProjectID     string         `json:"project_id"`
	Title         string         `json:"title"`
	Workdir       string         `json:"workdir"`
	Status        string         `json:"status"`
	RunnerType    string         `json:"runner_type"`
	Model         string         `json:"model"`
	ApprovalMode  string         `json:"approval_mode"`
	SandboxMode   string         `json:"sandbox_mode"`
	Config        map[string]any `json:"config,omitempty"`
	LastSeq       int64          `json:"last_seq"`
	CreatedAt     time.Time      `json:"created_at"`
	UpdatedAt     time.Time      `json:"updated_at"`
	ExitedAt      *time.Time     `json:"exited_at,omitempty"`
}
