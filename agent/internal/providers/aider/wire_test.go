package aider

import (
	"errors"
	"testing"

	"github.com/Teddy-Zhu/magent/agent/internal/provider"
	"github.com/Teddy-Zhu/magent/agent/internal/runner"
)

func TestAiderArgs(t *testing.T) {
	req := provider.CreateSessionRequest{Model: "gpt-4o"}

	got := aiderArgs(req)
	want := []string{"--yes", "--no-git", "--no-auto-commits", "--model", "gpt-4o"}
	if len(got) != len(want) {
		t.Fatalf("args = %#v, want %#v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("args = %#v, want %#v", got, want)
		}
	}
}

func TestAiderRunnerEvent(t *testing.T) {
	tests := []struct {
		name     string
		event    runner.RunnerEvent
		wantType provider.EventType
		wantKey  string
		want     any
	}{
		{
			name:     "output",
			event:    runner.RunnerEvent{Type: "output", Data: []byte("hello")},
			wantType: provider.EventOutput,
			wantKey:  "content",
			want:     "hello",
		},
		{
			name:     "exit",
			event:    runner.RunnerEvent{Type: "exit", ExitCode: 2},
			wantType: provider.EventExited,
			wantKey:  "exit_code",
			want:     2,
		},
		{
			name:     "error",
			event:    runner.RunnerEvent{Type: "error", Err: errors.New("boom")},
			wantType: provider.EventError,
			wantKey:  "error",
			want:     "boom",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, ok := aiderRunnerEvent("s1", tt.event)
			if !ok {
				t.Fatal("expected mapped event")
			}
			if got.Type != string(tt.wantType) {
				t.Fatalf("type = %q, want %q", got.Type, tt.wantType)
			}
			payload := got.Payload.(map[string]any)
			if payload[tt.wantKey] != tt.want {
				t.Fatalf("payload[%s] = %#v, want %#v", tt.wantKey, payload[tt.wantKey], tt.want)
			}
		})
	}
}
