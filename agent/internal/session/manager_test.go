package session

import "testing"

func TestCreateSessionRequestProviderName(t *testing.T) {
	tests := []struct {
		name string
		req  CreateSessionRequest
		want string
	}{
		{
			name: "uses canonical provider id",
			req:  CreateSessionRequest{ProviderID: "codex", Provider: "legacy"},
			want: "codex",
		},
		{
			name: "falls back to legacy provider",
			req:  CreateSessionRequest{Provider: "codex"},
			want: "codex",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := tt.req.ProviderName(); got != tt.want {
				t.Fatalf("ProviderName() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestCreateSessionRequestValidateRequiresProviderIDOrLegacyProvider(t *testing.T) {
	if err := (CreateSessionRequest{ProjectID: "p1"}).Validate(); err == nil {
		t.Fatal("Validate should require provider_id")
	}
	if err := (CreateSessionRequest{ProviderID: "codex", ProjectID: "p1"}).Validate(); err != nil {
		t.Fatalf("Validate canonical provider_id: %v", err)
	}
	if err := (CreateSessionRequest{Provider: "codex", ProjectID: "p1"}).Validate(); err != nil {
		t.Fatalf("Validate legacy provider: %v", err)
	}
}
