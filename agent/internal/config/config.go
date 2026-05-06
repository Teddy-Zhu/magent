package config

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/spf13/viper"
)

const (
	defaultConfigFileName = "default.yaml"
	defaultHost           = "127.0.0.1"
	defaultPort           = 9000
	defaultRateLimit      = 120
	defaultLogLevel       = "info"
	defaultTokenName      = "default"
)

type Config struct {
	Server    ServerConfig      `mapstructure:"server"`
	Auth      AuthConfig        `mapstructure:"auth"`
	Workspace WorkspaceConfig   `mapstructure:"workspace"`
	LogLevel  string            `mapstructure:"log_level"`
	LogLevels map[string]string `mapstructure:"log_levels"`
}

type ServerConfig struct {
	Host            string        `mapstructure:"host"`
	Port            int           `mapstructure:"port"`
	ReadTimeout     time.Duration `mapstructure:"read_timeout"`
	WriteTimeout    time.Duration `mapstructure:"write_timeout"`
	RateLimitPerMin int           `mapstructure:"rate_limit_per_min"`
}

type AuthConfig struct {
	Tokens []TokenConfig `mapstructure:"tokens"`
}

type TokenConfig struct {
	Name        string   `mapstructure:"name"`
	Token       string   `mapstructure:"token"`
	Permissions []string `mapstructure:"permissions"`
}

type WorkspaceConfig struct {
	AllowedDirs     []string `mapstructure:"allowed_dirs"`
	ExcludedPattern []string `mapstructure:"excluded_patterns"`
}

type Overrides struct {
	Host  string
	Port  int
	Token string
}

func Load(cfgFile string, overrides Overrides) (*Config, error) {
	startupOverrides, err := collectStartupOverrides(overrides)
	if err != nil {
		return nil, err
	}

	configFile, err := ensureConfigFile(cfgFile, startupOverrides)
	if err != nil {
		return nil, err
	}

	v := viper.New()
	configure(v)
	v.SetConfigFile(configFile)

	if err := v.ReadInConfig(); err != nil {
		return nil, err
	}

	var cfg Config
	if err := v.Unmarshal(&cfg); err != nil {
		return nil, err
	}

	if len(cfg.Auth.Tokens) == 0 || cfg.Auth.Tokens[0].Token == "" {
		token := startupOverrides.Token
		if token == "" {
			token = uuid.New().String()
		}
		cfg.Auth.Tokens = defaultTokens(token)
		v.Set("auth.tokens", cfg.Auth.Tokens)
		if err := v.WriteConfigAs(configFile); err != nil {
			fmt.Printf("Warning: failed to write token to config: %v\n", err)
		}
	}

	applyEnvironmentOverrides(&cfg)
	applyRuntimeOverrides(&cfg, overrides)
	normalize(&cfg)

	if err := validate(&cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}

func configure(v *viper.Viper) {
	v.SetConfigType("yaml")
	v.SetEnvPrefix("MAGENT")
	v.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))
	v.AutomaticEnv()

	_ = v.BindEnv("server.host", "MAGENT_HOST", "MAGENT_SERVER_HOST")
	_ = v.BindEnv("server.port", "MAGENT_PORT", "MAGENT_SERVER_PORT")

	v.SetDefault("server.host", defaultHost)
	v.SetDefault("server.port", defaultPort)
	v.SetDefault("server.read_timeout", 30*time.Second)
	v.SetDefault("server.write_timeout", 30*time.Second)
	v.SetDefault("server.rate_limit_per_min", defaultRateLimit)
	v.SetDefault("log_level", defaultLogLevel)
	v.SetDefault("log_levels", map[string]string{})
	v.SetDefault("workspace.allowed_dirs", []string{})
	v.SetDefault("workspace.excluded_patterns", []string{".git", "node_modules", ".venv", "__pycache__"})
}

func ensureConfigFile(cfgFile string, startupOverrides Overrides) (string, error) {
	if cfgFile != "" {
		return ensureFileAt(cfgFile, startupOverrides)
	}

	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}

	homeConfig := filepath.Join(home, ".magent", defaultConfigFileName)
	if ok, err := isRegularFile(homeConfig); err != nil {
		return "", err
	} else if ok {
		return homeConfig, nil
	}

	cwdConfig, err := filepath.Abs(defaultConfigFileName)
	if err == nil {
		if ok, err := isRegularFile(cwdConfig); err != nil {
			return "", err
		} else if ok {
			return cwdConfig, nil
		}
	}

	return createDefaultConfig(homeConfig, startupOverrides)
}

func ensureFileAt(path string, startupOverrides Overrides) (string, error) {
	absPath, err := filepath.Abs(path)
	if err != nil {
		return "", err
	}
	if ok, err := isRegularFile(absPath); err != nil {
		return "", err
	} else if ok {
		return absPath, nil
	}
	return createDefaultConfig(absPath, startupOverrides)
}

func isRegularFile(path string) (bool, error) {
	info, err := os.Stat(path)
	if err == nil {
		if info.IsDir() {
			return false, fmt.Errorf("config path %s is a directory", path)
		}
		return true, nil
	}
	if errors.Is(err, os.ErrNotExist) {
		return false, nil
	}
	return false, err
}

func createDefaultConfig(path string, startupOverrides Overrides) (string, error) {
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return "", err
	}

	host := defaultHost
	if startupOverrides.Host != "" {
		host = strings.TrimSpace(startupOverrides.Host)
	}
	port := defaultPort
	if startupOverrides.Port != 0 {
		port = startupOverrides.Port
	}
	token := strings.TrimSpace(startupOverrides.Token)
	if token == "" {
		token = uuid.New().String()
	}

	content := fmt.Sprintf(`log_level: "info"  # debug, info, warn, error

server:
  host: %s
  port: %d
  read_timeout: 30s
  write_timeout: 30s
  rate_limit_per_min: %d

auth:
  tokens:
    - name: %s
      token: %s
      permissions: ["*"]

workspace:
  allowed_dirs: []
  excluded_patterns:
    - ".git"
    - "node_modules"
    - ".venv"
    - "__pycache__"
`, strconv.Quote(host), port, defaultRateLimit, strconv.Quote(defaultTokenName), strconv.Quote(token))

	if err := os.WriteFile(path, []byte(content), 0600); err != nil {
		return "", err
	}
	return path, nil
}

func collectStartupOverrides(overrides Overrides) (Overrides, error) {
	collected := Overrides{
		Host:  firstNonEmptyEnv("MAGENT_HOST", "MAGENT_SERVER_HOST"),
		Token: firstNonEmptyEnv("MAGENT_TOKEN", "MAGENT_AUTH_TOKEN"),
	}

	if portValue := firstNonEmptyEnv("MAGENT_PORT", "MAGENT_SERVER_PORT"); portValue != "" && overrides.Port == 0 {
		port, err := strconv.Atoi(portValue)
		if err != nil {
			return Overrides{}, fmt.Errorf("invalid MAGENT_PORT value %q: %w", portValue, err)
		}
		if err := validatePort(port); err != nil {
			return Overrides{}, err
		}
		collected.Port = port
	}

	if overrides.Host != "" {
		collected.Host = strings.TrimSpace(overrides.Host)
	}
	if overrides.Port != 0 {
		if err := validatePort(overrides.Port); err != nil {
			return Overrides{}, err
		}
		collected.Port = overrides.Port
	}
	if overrides.Token != "" {
		collected.Token = strings.TrimSpace(overrides.Token)
	}

	return collected, nil
}

func applyEnvironmentOverrides(cfg *Config) {
	if token := firstNonEmptyEnv("MAGENT_TOKEN", "MAGENT_AUTH_TOKEN"); token != "" {
		setPrimaryToken(cfg, token)
	}
}

func applyRuntimeOverrides(cfg *Config, overrides Overrides) {
	if overrides.Host != "" {
		cfg.Server.Host = strings.TrimSpace(overrides.Host)
	}
	if overrides.Port != 0 {
		cfg.Server.Port = overrides.Port
	}
	if overrides.Token != "" {
		setPrimaryToken(cfg, overrides.Token)
	}
}

func firstNonEmptyEnv(keys ...string) string {
	for _, key := range keys {
		value := strings.TrimSpace(os.Getenv(key))
		if value != "" {
			return value
		}
	}
	return ""
}

func setPrimaryToken(cfg *Config, token string) {
	token = strings.TrimSpace(token)
	if token == "" {
		return
	}
	if len(cfg.Auth.Tokens) == 0 {
		cfg.Auth.Tokens = defaultTokens(token)
		return
	}
	cfg.Auth.Tokens[0].Token = token
	if cfg.Auth.Tokens[0].Name == "" {
		cfg.Auth.Tokens[0].Name = defaultTokenName
	}
	if len(cfg.Auth.Tokens[0].Permissions) == 0 {
		cfg.Auth.Tokens[0].Permissions = []string{"*"}
	}
}

func defaultTokens(token string) []TokenConfig {
	return []TokenConfig{
		{
			Name:        defaultTokenName,
			Token:       token,
			Permissions: []string{"*"},
		},
	}
}

func normalize(cfg *Config) {
	cfg.Server.Host = strings.TrimSpace(cfg.Server.Host)
	if cfg.Server.Host == "" {
		cfg.Server.Host = defaultHost
	}
	if cfg.Server.Port == 0 {
		cfg.Server.Port = defaultPort
	}
	if cfg.Server.ReadTimeout == 0 {
		cfg.Server.ReadTimeout = 30 * time.Second
	}
	if cfg.Server.WriteTimeout == 0 {
		cfg.Server.WriteTimeout = 30 * time.Second
	}
	if cfg.Server.RateLimitPerMin == 0 {
		cfg.Server.RateLimitPerMin = defaultRateLimit
	}
	if cfg.LogLevel == "" {
		cfg.LogLevel = defaultLogLevel
	}
	if cfg.LogLevels == nil {
		cfg.LogLevels = map[string]string{}
	}
	if len(cfg.Workspace.ExcludedPattern) == 0 {
		cfg.Workspace.ExcludedPattern = []string{".git", "node_modules", ".venv", "__pycache__"}
	}
	if len(cfg.Auth.Tokens) == 0 {
		cfg.Auth.Tokens = defaultTokens(uuid.New().String())
	}
	setPrimaryToken(cfg, cfg.Auth.Tokens[0].Token)
}

func validate(cfg *Config) error {
	if err := validatePort(cfg.Server.Port); err != nil {
		return err
	}
	if len(cfg.Auth.Tokens) == 0 || strings.TrimSpace(cfg.Auth.Tokens[0].Token) == "" {
		return fmt.Errorf("auth token is empty")
	}
	return nil
}

func validatePort(port int) error {
	if port < 1 || port > 65535 {
		return fmt.Errorf("server.port must be between 1 and 65535, got %d", port)
	}
	return nil
}
