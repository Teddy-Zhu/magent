package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestLoadCreatesMissingConfigWithOverrides(t *testing.T) {
	cfgFile := filepath.Join(t.TempDir(), "nested", "default.yaml")

	cfg, err := Load(cfgFile, Overrides{
		Host:  "0.0.0.0",
		Port:  9101,
		Token: "cli-token",
	})
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}

	if cfg.Server.Host != "0.0.0.0" {
		t.Fatalf("host = %q, want %q", cfg.Server.Host, "0.0.0.0")
	}
	if cfg.Server.Port != 9101 {
		t.Fatalf("port = %d, want %d", cfg.Server.Port, 9101)
	}
	if got := cfg.Auth.Tokens[0].Token; got != "cli-token" {
		t.Fatalf("token = %q, want %q", got, "cli-token")
	}

	data, err := os.ReadFile(cfgFile)
	if err != nil {
		t.Fatalf("ReadFile() error = %v", err)
	}
	content := string(data)
	for _, want := range []string{`host: "0.0.0.0"`, "port: 9101", `token: "cli-token"`} {
		if !strings.Contains(content, want) {
			t.Fatalf("created config missing %q:\n%s", want, content)
		}
	}
}

func TestLoadEnvironmentAndRuntimeOverridePrecedence(t *testing.T) {
	t.Setenv("MAGENT_HOST", "env-host")
	t.Setenv("MAGENT_PORT", "9202")
	t.Setenv("MAGENT_TOKEN", "env-token")

	cfgFile := filepath.Join(t.TempDir(), "default.yaml")
	if err := os.WriteFile(cfgFile, []byte(`server:
  host: file-host
  port: 9001
  read_timeout: 30s
  write_timeout: 30s
auth:
  tokens:
    - name: default
      token: file-token
      permissions: ["*"]
workspace:
  allowed_dirs: []
  excluded_patterns: []
`), 0600); err != nil {
		t.Fatalf("WriteFile() error = %v", err)
	}

	cfg, err := Load(cfgFile, Overrides{
		Host:  "cli-host",
		Port:  9303,
		Token: "cli-token",
	})
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}

	if cfg.Server.Host != "cli-host" {
		t.Fatalf("host = %q, want %q", cfg.Server.Host, "cli-host")
	}
	if cfg.Server.Port != 9303 {
		t.Fatalf("port = %d, want %d", cfg.Server.Port, 9303)
	}
	if got := cfg.Auth.Tokens[0].Token; got != "cli-token" {
		t.Fatalf("token = %q, want %q", got, "cli-token")
	}
}

func TestLoadSupportsShortEnvironmentOverrides(t *testing.T) {
	t.Setenv("MAGENT_HOST", "env-host")
	t.Setenv("MAGENT_PORT", "9202")
	t.Setenv("MAGENT_TOKEN", "env-token")

	cfgFile := filepath.Join(t.TempDir(), "default.yaml")
	cfg, err := Load(cfgFile, Overrides{})
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}

	if cfg.Server.Host != "env-host" {
		t.Fatalf("host = %q, want %q", cfg.Server.Host, "env-host")
	}
	if cfg.Server.Port != 9202 {
		t.Fatalf("port = %d, want %d", cfg.Server.Port, 9202)
	}
	if got := cfg.Auth.Tokens[0].Token; got != "env-token" {
		t.Fatalf("token = %q, want %q", got, "env-token")
	}
}

func TestLoadRejectsInvalidPortBeforeCreatingConfig(t *testing.T) {
	cfgFile := filepath.Join(t.TempDir(), "default.yaml")

	_, err := Load(cfgFile, Overrides{Port: 70000})
	if err == nil {
		t.Fatal("Load() error = nil, want invalid port error")
	}
	if _, statErr := os.Stat(cfgFile); !os.IsNotExist(statErr) {
		t.Fatalf("config file should not be created, stat error = %v", statErr)
	}
}
