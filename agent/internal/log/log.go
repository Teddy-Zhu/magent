package log

import (
	"fmt"
	"os"
	"sync"
	"time"
)

type Level int

const (
	LevelDebug Level = iota
	LevelInfo
	LevelWarn
	LevelError
)

var levelNames = map[Level]string{
	LevelDebug: "DBG",
	LevelInfo:  "INF",
	LevelWarn:  "WRN",
	LevelError: "ERR",
}

var (
	currentLevel = LevelInfo
	mu           sync.RWMutex
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

func parseLevel(s string) Level {
	switch s {
	case "debug", "DEBUG", "dbg":
		return LevelDebug
	case "warn", "WARN":
		return LevelWarn
	case "error", "ERROR":
		return LevelError
	default:
		return LevelInfo
	}
}

func Init(levelStr string) {
	if levelStr != "" {
		SetLevel(parseLevel(levelStr))
	} else {
		if env := os.Getenv("MAGENT_LOG_LEVEL"); env != "" {
			SetLevel(parseLevel(env))
		}
	}
}

func output(level Level, component, msg string, args ...any) {
	mu.RLock()
	l := currentLevel
	mu.RUnlock()

	if level < l {
		return
	}

	ts := time.Now().Format("15:04:05.000")
	formatted := msg
	if len(args) > 0 {
		formatted = fmt.Sprintf(msg, args...)
	}
	fmt.Fprintf(os.Stderr, "%s [%s] %s: %s\n", ts, levelNames[level], component, formatted)
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
