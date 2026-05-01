package log

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"strings"
	"sync"
	"time"
)

type Level int

const (
	LevelDebug Level = iota
	LevelInfo
	LevelWarn
	LevelError
	LevelOff
)

var levelNames = map[Level]string{
	LevelDebug: "DBG",
	LevelInfo:  "INF",
	LevelWarn:  "WRN",
	LevelError: "ERR",
	LevelOff:   "OFF",
}

var (
	currentLevel              = LevelInfo
	componentLevels           = map[string]Level{}
	outputWriter    io.Writer = os.Stderr
	mu              sync.RWMutex
)

func SetLevel(l Level) {
	mu.Lock()
	currentLevel = l
	mu.Unlock()
}

func GetLevel() Level {
	mu.RLock()
	defer mu.RUnlock()
	return currentLevel
}

func SetComponentLevel(component string, level Level) {
	component = normalizeComponent(component)
	if component == "" {
		return
	}
	mu.Lock()
	componentLevels[component] = level
	mu.Unlock()
}

func GetComponentLevel(component string) (Level, bool) {
	component = normalizeComponent(component)
	if component == "" {
		return LevelInfo, false
	}
	mu.RLock()
	defer mu.RUnlock()
	level, ok := componentLevels[component]
	return level, ok
}

func SetOutput(w io.Writer) {
	mu.Lock()
	if w == nil {
		outputWriter = os.Stderr
	} else {
		outputWriter = w
	}
	mu.Unlock()
}

func parseLevel(s string) Level {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case "debug", "dbg":
		return LevelDebug
	case "warn":
		return LevelWarn
	case "error":
		return LevelError
	case "off", "none", "disabled", "disable", "silent":
		return LevelOff
	default:
		return LevelInfo
	}
}

func Init(levelStr string) {
	InitWithLevels(levelStr, nil)
}

func InitWithLevels(levelStr string, overrides map[string]string) {
	mu.Lock()
	currentLevel = LevelInfo
	componentLevels = map[string]Level{}
	mu.Unlock()

	if env := os.Getenv("MAGENT_LOG_LEVEL"); env != "" && levelStr == "" {
		levelStr = env
	}
	if levelStr != "" {
		SetLevel(parseLevel(levelStr))
	}

	for component, level := range overrides {
		SetComponentLevel(component, parseLevel(level))
	}
	if env := os.Getenv("MAGENT_LOG_LEVELS"); env != "" {
		ApplyComponentLevels(env)
	}
}

func ApplyComponentLevels(spec string) {
	for _, item := range strings.Split(spec, ",") {
		item = strings.TrimSpace(item)
		if item == "" {
			continue
		}
		component, level, ok := strings.Cut(item, "=")
		if !ok {
			component, level, ok = strings.Cut(item, ":")
		}
		if !ok {
			continue
		}
		SetComponentLevel(component, parseLevel(level))
	}
}

func normalizeComponent(component string) string {
	return strings.ToLower(strings.TrimSpace(component))
}

func output(level Level, component, msg string, args ...any) {
	mu.RLock()
	l := currentLevel
	if componentLevel, ok := componentLevels[normalizeComponent(component)]; ok {
		l = componentLevel
	}
	w := outputWriter
	mu.RUnlock()

	if l == LevelOff || level < l {
		return
	}

	ts := time.Now().Format("15:04:05.000")
	formatted := msg
	if len(args) > 0 {
		formatted = fmt.Sprintf(msg, args...)
	}
	var buf bytes.Buffer
	fmt.Fprintf(&buf, "%s [%s] %s: %s\n", ts, levelNames[level], component, formatted)
	mu.Lock()
	_, _ = w.Write(buf.Bytes())
	mu.Unlock()
}

func Debug(component, msg string, args ...any) {
	output(LevelDebug, component, msg, args...)
}

func Info(component, msg string, args ...any) {
	output(LevelInfo, component, msg, args...)
}

func Warn(component, msg string, args ...any) {
	output(LevelWarn, component, msg, args...)
}

func Error(component, msg string, args ...any) {
	output(LevelError, component, msg, args...)
}
