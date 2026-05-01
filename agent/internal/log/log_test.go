package log

import (
	"testing"
)

func TestComponentLevelOverride(t *testing.T) {
	InitWithLevels("debug", map[string]string{"gitwatcher": "off"})
	t.Cleanup(func() { InitWithLevels("info", nil) })

	if got := GetLevel(); got != LevelDebug {
		t.Fatalf("global level = %v, want %v", got, LevelDebug)
	}
	got, ok := GetComponentLevel("gitwatcher")
	if !ok {
		t.Fatal("gitwatcher override not found")
	}
	if got != LevelOff {
		t.Fatalf("gitwatcher level = %v, want %v", got, LevelOff)
	}
}

func TestApplyComponentLevels(t *testing.T) {
	InitWithLevels("info", nil)
	t.Cleanup(func() { InitWithLevels("info", nil) })

	ApplyComponentLevels("gitwatcher=error,codex:debug")

	if got, ok := GetComponentLevel("gitwatcher"); !ok || got != LevelError {
		t.Fatalf("gitwatcher level = %v ok=%v, want %v", got, ok, LevelError)
	}
	if got, ok := GetComponentLevel("codex"); !ok || got != LevelDebug {
		t.Fatalf("codex level = %v ok=%v, want %v", got, ok, LevelDebug)
	}
}
