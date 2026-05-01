package config

import (
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/google/uuid"
	"github.com/spf13/viper"
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

func Load(cfgFile string) (*Config, error) {
	if cfgFile != "" {
		viper.SetConfigFile(cfgFile)
	} else {
		home, err := os.UserHomeDir()
		if err != nil {
			return nil, err
		}

		viper.AddConfigPath(filepath.Join(home, ".magent"))
		viper.AddConfigPath(".")
		viper.SetConfigType("yaml")
		viper.SetConfigName("default")
	}

	// 环境变量覆盖
	viper.SetEnvPrefix("MAGENT")
	viper.AutomaticEnv()

	// 设置默认值
	viper.SetDefault("server.host", "127.0.0.1")
	viper.SetDefault("server.port", 9000)
	viper.SetDefault("server.read_timeout", 30*time.Second)
	viper.SetDefault("server.write_timeout", 30*time.Second)
	viper.SetDefault("server.rate_limit_per_min", 120)
	viper.SetDefault("log_level", "info")
	viper.SetDefault("log_levels", map[string]string{})

	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return nil, err
		}
	}

	var cfg Config
	if err := viper.Unmarshal(&cfg); err != nil {
		return nil, err
	}

	// 自动生成Token
	if len(cfg.Auth.Tokens) == 0 || cfg.Auth.Tokens[0].Token == "" {
		cfg.Auth.Tokens = []TokenConfig{
			{
				Name:        "default",
				Token:       uuid.New().String(),
				Permissions: []string{"*"},
			},
		}
		// 写回配置文件
		viper.Set("auth.tokens", cfg.Auth.Tokens)
		configFile := viper.ConfigFileUsed()
		if configFile == "" {
			home, _ := os.UserHomeDir()
			configFile = filepath.Join(home, ".magent", "default.yaml")
			os.MkdirAll(filepath.Dir(configFile), 0755)
		}
		if err := viper.WriteConfigAs(configFile); err != nil {
			fmt.Printf("Warning: failed to write token to config: %v\n", err)
		}
		fmt.Printf("Generated auth token: %s\n", cfg.Auth.Tokens[0].Token)
	}

	return &cfg, nil
}
