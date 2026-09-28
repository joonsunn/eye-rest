package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestPrefsDefaults(t *testing.T) {
	p := LoadPrefs(filepath.Join(t.TempDir(), "prefs.json"))
	if p.WorkDuration != 20*60 || p.BreakDuration != 20 {
		t.Fatalf("want 20min/20s, got %v/%v", p.WorkDuration, p.BreakDuration)
	}
	if p.PingSound != "system" || p.BreakOverSound != "system" {
		t.Fatalf("want system/system, got %s/%s", p.PingSound, p.BreakOverSound)
	}
}

func TestPrefsPersistAcrossLoads(t *testing.T) {
	path := filepath.Join(t.TempDir(), "prefs.json")
	first := LoadPrefs(path)
	first.SetWorkMinutes(30)
	first.SetBreakSeconds(60)
	first.SetPingSound("Glass")
	first.SetBreakOverSound("Ping")
	second := LoadPrefs(path)
	if second.WorkDuration != 30*60 || second.BreakDuration != 60 {
		t.Fatalf("want 30min/60s, got %v/%v", second.WorkDuration, second.BreakDuration)
	}
	if second.PingSound != "Glass" || second.BreakOverSound != "Ping" {
		t.Fatalf("want Glass/Ping, got %s/%s", second.PingSound, second.BreakOverSound)
	}
}

func TestPrefsEnvOverridesWithoutPersist(t *testing.T) {
	path := filepath.Join(t.TempDir(), "prefs.json")
	p := LoadPrefs(path)
	p.ApplyEnvOverrides(map[string]string{
		"EYE_REST_WORK_SECONDS":  "10",
		"EYE_REST_BREAK_SECONDS": "5",
	})
	if p.WorkDuration != 10 || p.BreakDuration != 5 {
		t.Fatalf("want 10/5, got %v/%v", p.WorkDuration, p.BreakDuration)
	}
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Fatal("env overrides must not write the prefs file")
	}
}
