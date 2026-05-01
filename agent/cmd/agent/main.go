package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/magent/agent/internal/api"
	"github.com/magent/agent/internal/config"
	"github.com/magent/agent/internal/log"
	"github.com/magent/agent/internal/storage"
	"github.com/spf13/cobra"
)

func main() {
	var cfgFile string

	rootCmd := &cobra.Command{
		Use:   "magent",
		Short: "Magent - Remote AI Code Agent",
	}

	serveCmd := &cobra.Command{
		Use:   "serve",
		Short: "Start the agent server",
		RunE: func(cmd *cobra.Command, args []string) error {
			logLevel, _ := cmd.Flags().GetString("log-level")
			logLevels, _ := cmd.Flags().GetString("log-levels")

			log.Info("main", "loading config from %q", cfgFile)
			cfg, err := config.Load(cfgFile)
			if err != nil {
				return fmt.Errorf("failed to load config: %w", err)
			}

			// CLI flag > config file > env > default
			effectiveLogLevel := cfg.LogLevel
			if logLevel != "" {
				effectiveLogLevel = logLevel
			}
			log.InitWithLevels(effectiveLogLevel, cfg.LogLevels)
			if logLevels != "" {
				log.ApplyComponentLevels(logLevels)
			}

			log.Debug("main", "config loaded: host=%s port=%d rate_limit=%d log_level=%s log_levels=%v",
				cfg.Server.Host, cfg.Server.Port, cfg.Server.RateLimitPerMin, effectiveLogLevel, cfg.LogLevels)

			log.Info("main", "opening database magent.db")
			store, err := storage.Open("magent.db")
			if err != nil {
				return fmt.Errorf("failed to open storage: %w", err)
			}
			defer store.Close()

			ctx, cancel := context.WithCancel(context.Background())
			defer cancel()

			// 处理信号
			sigCh := make(chan os.Signal, 1)
			signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
			go func() {
				<-sigCh
				cancel()
			}()

			log.Info("main", "creating server")
			server := api.NewServer(cfg, store)
			log.Info("main", "starting server on %s:%d", cfg.Server.Host, cfg.Server.Port)
			return server.Start(ctx)
		},
	}

	initCmd := &cobra.Command{
		Use:   "init",
		Short: "Initialize configuration",
		RunE: func(cmd *cobra.Command, args []string) error {
			cfg, err := config.Load("")
			if err != nil {
				return err
			}
			fmt.Printf("Configuration initialized. Token: %s\n", cfg.Auth.Tokens[0].Token)
			return nil
		},
	}

	serveCmd.Flags().StringVarP(&cfgFile, "config", "c", "", "config file path")
	serveCmd.Flags().String("log-level", "", "global log level: debug, info, warn, error, off")
	serveCmd.Flags().String("log-levels", "", "component log levels, e.g. gitwatcher=off,codex=debug")
	rootCmd.AddCommand(serveCmd, initCmd)

	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
