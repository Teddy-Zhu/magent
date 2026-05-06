package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"runtime/debug"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/Teddy-Zhu/magent/agent/internal/api"
	"github.com/Teddy-Zhu/magent/agent/internal/config"
	"github.com/Teddy-Zhu/magent/agent/internal/log"
	"github.com/Teddy-Zhu/magent/agent/internal/storage"
	"github.com/kardianos/service"
	"github.com/spf13/cobra"
)

var (
	version   = "unknown"
	buildTime = "unknown"
	gitCommit = "unknown"
)

const (
	serviceName        = "magent"
	serviceDisplayName = "Magent Agent"
	serviceDescription = "Magent remote AI code agent service."
)

type serverOptions struct {
	ConfigFile string
	LogLevel   string
	LogLevels  string
	Overrides  config.Overrides
}

type serviceProgram struct {
	opts          serverOptions
	cancel        context.CancelFunc
	errCh         chan error
	started       atomic.Bool
	stopRequested atomic.Bool
}

func main() {
	applyBuildInfoDefaults()

	api.SetBuildInfo(api.BuildInfo{
		Version:   version,
		BuildTime: buildTime,
		GitCommit: gitCommit,
	})

	rootCmd := &cobra.Command{
		Use:   "magent",
		Short: "Magent - Remote AI Code Agent",
	}

	var serveOpts serverOptions
	serveCmd := &cobra.Command{
		Use:   "serve",
		Short: "Start the agent server",
		RunE: func(cmd *cobra.Command, args []string) error {
			if !service.Interactive() {
				svc, err := newMagentService(serveOpts, false)
				if err != nil {
					return err
				}
				return svc.Run()
			}

			ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
			defer stop()
			return runServer(ctx, serveOpts)
		},
	}

	installCmd := &cobra.Command{
		Use:   "install",
		Short: "Install the agent as a system service",
		RunE: func(cmd *cobra.Command, args []string) error {
			var opts serverOptions
			readServerFlags(cmd, &opts)
			if _, err := config.Load(opts.ConfigFile, opts.Overrides); err != nil {
				return fmt.Errorf("failed to initialize config: %w", err)
			}
			svc, err := newMagentService(opts, true)
			if err != nil {
				return err
			}
			return service.Control(svc, "install")
		},
	}

	versionCmd := &cobra.Command{
		Use:   "version",
		Short: "Print version information",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Printf("magent %s\n", version)
			fmt.Printf("build_time: %s\n", buildTime)
			fmt.Printf("git_commit: %s\n", gitCommit)
		},
	}

	addServerFlags(serveCmd, &serveOpts)
	addServerFlags(installCmd, nil)
	rootCmd.AddCommand(
		serveCmd,
		installCmd,
		newServiceControlCmd("uninstall", "Uninstall the system service"),
		newServiceControlCmd("start", "Start the system service"),
		newServiceControlCmd("stop", "Stop the system service"),
		newServiceControlCmd("restart", "Restart the system service"),
		versionCmd,
	)

	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func addServerFlags(cmd *cobra.Command, opts *serverOptions) {
	if opts == nil {
		cmd.Flags().StringP("config", "c", "", "config file path")
		cmd.Flags().String("host", "", "server host; overrides MAGENT_HOST and config file")
		cmd.Flags().Int("port", 0, "server port; overrides MAGENT_PORT and config file")
		cmd.Flags().String("token", "", "auth token; overrides MAGENT_TOKEN and config file")
		cmd.Flags().String("log-level", "", "global log level: debug, info, warn, error, off")
		cmd.Flags().String("log-levels", "", "component log levels, e.g. gitwatcher=off,codex=debug")
		return
	}
	cmd.Flags().StringVarP(&opts.ConfigFile, "config", "c", "", "config file path")
	cmd.Flags().StringVar(&opts.Overrides.Host, "host", "", "server host; overrides MAGENT_HOST and config file")
	cmd.Flags().IntVar(&opts.Overrides.Port, "port", 0, "server port; overrides MAGENT_PORT and config file")
	cmd.Flags().StringVar(&opts.Overrides.Token, "token", "", "auth token; overrides MAGENT_TOKEN and config file")
	cmd.Flags().StringVar(&opts.LogLevel, "log-level", "", "global log level: debug, info, warn, error, off")
	cmd.Flags().StringVar(&opts.LogLevels, "log-levels", "", "component log levels, e.g. gitwatcher=off,codex=debug")
}

func readServerFlags(cmd *cobra.Command, opts *serverOptions) {
	opts.ConfigFile, _ = cmd.Flags().GetString("config")
	opts.Overrides.Host, _ = cmd.Flags().GetString("host")
	opts.Overrides.Port, _ = cmd.Flags().GetInt("port")
	opts.Overrides.Token, _ = cmd.Flags().GetString("token")
	opts.LogLevel, _ = cmd.Flags().GetString("log-level")
	opts.LogLevels, _ = cmd.Flags().GetString("log-levels")
}

func runServer(ctx context.Context, opts serverOptions) error {
	cfg, err := config.Load(opts.ConfigFile, opts.Overrides)
	if err != nil {
		return fmt.Errorf("failed to load config: %w", err)
	}

	effectiveLogLevel := cfg.LogLevel
	if opts.LogLevel != "" {
		effectiveLogLevel = opts.LogLevel
	}
	log.InitWithLevels(effectiveLogLevel, cfg.LogLevels)
	if opts.LogLevels != "" {
		log.ApplyComponentLevels(opts.LogLevels)
	}

	log.Debug("main", "config loaded: file=%q host=%s port=%d rate_limit=%d log_level=%s log_levels=%v cli_log_levels=%q",
		opts.ConfigFile, cfg.Server.Host, cfg.Server.Port, cfg.Server.RateLimitPerMin, effectiveLogLevel, cfg.LogLevels, opts.LogLevels)

	log.Info("main", "opening database magent.db")
	store, err := storage.Open("magent.db")
	if err != nil {
		return fmt.Errorf("failed to open storage: %w", err)
	}
	defer store.Close()

	log.Info("main", "creating server")
	server := api.NewServer(cfg, store)
	log.Info("main", "starting server on %s:%d", cfg.Server.Host, cfg.Server.Port)
	return server.Start(ctx)
}

func newServiceControlCmd(action, short string) *cobra.Command {
	return &cobra.Command{
		Use:   action,
		Short: short,
		RunE: func(cmd *cobra.Command, args []string) error {
			svc, err := newMagentService(serverOptions{}, false)
			if err != nil {
				return err
			}
			return service.Control(svc, action)
		},
	}
}

func newMagentService(opts serverOptions, includeArgs bool) (service.Service, error) {
	svcConfig := &service.Config{
		Name:        serviceName,
		DisplayName: serviceDisplayName,
		Description: serviceDescription,
		Option:      service.KeyValue{"Restart": "always"},
	}
	if includeArgs {
		svcConfig.WorkingDirectory = serviceWorkingDirectory(opts.ConfigFile)
		svcConfig.Arguments = serviceArguments(opts)
		if opts.Overrides.Token != "" {
			svcConfig.EnvVars = map[string]string{
				"MAGENT_TOKEN": opts.Overrides.Token,
			}
		}
	}
	return service.New(&serviceProgram{opts: opts}, svcConfig)
}

func serviceArguments(opts serverOptions) []string {
	args := []string{"serve"}
	if opts.ConfigFile != "" {
		cfgFile := opts.ConfigFile
		if absPath, err := filepath.Abs(opts.ConfigFile); err == nil {
			cfgFile = absPath
		}
		args = append(args, "--config", cfgFile)
	}
	if opts.Overrides.Host != "" {
		args = append(args, "--host", opts.Overrides.Host)
	}
	if opts.Overrides.Port != 0 {
		args = append(args, "--port", fmt.Sprintf("%d", opts.Overrides.Port))
	}
	if opts.LogLevel != "" {
		args = append(args, "--log-level", opts.LogLevel)
	}
	if opts.LogLevels != "" {
		args = append(args, "--log-levels", opts.LogLevels)
	}
	return args
}

func serviceWorkingDirectory(cfgFile string) string {
	if cfgFile != "" {
		absPath, err := filepath.Abs(cfgFile)
		if err == nil {
			return filepath.Dir(absPath)
		}
	}

	home, err := os.UserHomeDir()
	if err == nil {
		dir := filepath.Join(home, ".magent")
		if mkErr := os.MkdirAll(dir, 0755); mkErr == nil {
			return dir
		}
	}

	exe, err := os.Executable()
	if err == nil {
		return filepath.Dir(exe)
	}
	return ""
}

func (p *serviceProgram) Start(s service.Service) error {
	ctx, cancel := context.WithCancel(context.Background())
	p.cancel = cancel
	p.errCh = make(chan error, 1)
	p.started.Store(false)
	p.stopRequested.Store(false)
	go func() {
		err := runServer(ctx, p.opts)
		p.errCh <- err
		if p.started.Load() && !p.stopRequested.Load() {
			if err != nil {
				log.Error("main", "service stopped unexpectedly: %v", err)
			}
			os.Exit(1)
		}
	}()

	select {
	case err := <-p.errCh:
		return err
	case <-time.After(500 * time.Millisecond):
		p.started.Store(true)
		return nil
	}
}

func (p *serviceProgram) Stop(s service.Service) error {
	p.stopRequested.Store(true)
	if p.cancel != nil {
		p.cancel()
	}
	if p.errCh == nil {
		return nil
	}
	select {
	case err := <-p.errCh:
		return err
	case <-time.After(10 * time.Second):
		return nil
	}
}

func applyBuildInfoDefaults() {
	info, ok := debug.ReadBuildInfo()
	if !ok {
		return
	}

	if (version == "" || version == "unknown") && info.Main.Version != "" && info.Main.Version != "(devel)" {
		version = info.Main.Version
	}

	for _, setting := range info.Settings {
		switch setting.Key {
		case "vcs.revision":
			if gitCommit == "" || gitCommit == "unknown" {
				gitCommit = setting.Value
				if len(gitCommit) > 12 {
					gitCommit = gitCommit[:12]
				}
			}
		case "vcs.time":
			if buildTime == "" || buildTime == "unknown" {
				buildTime = setting.Value
			}
		}
	}
}
