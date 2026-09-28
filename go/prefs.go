package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strconv"
)

// Prefs mirrors EyeRestSettings: durations in seconds plus sound picks,
// persisted locally. No network, no sync.
type Prefs struct {
	WorkDuration   float64 `json:"workDuration"`
	BreakDuration  float64 `json:"breakDuration"`
	PingSound      string  `json:"pingSound"`
	BreakOverSound string  `json:"breakOverSound"`

	path string
}

// WorkPresets and BreakPresets mirror the Swift menu presets.
var WorkPresets = []int{5, 15, 20, 30, 45}
var BreakPresets = []int{20, 30, 60}

// DefaultPrefsPath lives under Application Support, like a good citizen.
func DefaultPrefsPath() string {
	dir, err := os.UserHomeDir()
	if err != nil {
		dir = "."
	}
	return filepath.Join(dir, "Library", "Application Support", "EyeRestGo", "prefs.json")
}

// LoadPrefs reads prefs from path, falling back to 20 min / 20 sec / system.
func LoadPrefs(path string) *Prefs {
	p := &Prefs{WorkDuration: 20 * 60, BreakDuration: 20, PingSound: "system", BreakOverSound: "system", path: path}
	if data, err := os.ReadFile(path); err == nil {
		var saved Prefs
		if json.Unmarshal(data, &saved) == nil {
			if saved.WorkDuration > 0 {
				p.WorkDuration = saved.WorkDuration
			}
			if saved.BreakDuration > 0 {
				p.BreakDuration = saved.BreakDuration
			}
			if saved.PingSound != "" {
				p.PingSound = saved.PingSound
			}
			if saved.BreakOverSound != "" {
				p.BreakOverSound = saved.BreakOverSound
			}
		}
	}
	return p
}

func (p *Prefs) save() {
	data, err := json.MarshalIndent(p, "", "  ")
	if err != nil {
		return
	}
	_ = os.MkdirAll(filepath.Dir(p.path), 0o755)
	_ = os.WriteFile(p.path, data, 0o644)
}

func (p *Prefs) SetWorkMinutes(m int) {
	p.WorkDuration = float64(m * 60)
	p.save()
}

func (p *Prefs) SetBreakSeconds(s int) {
	p.BreakDuration = float64(s)
	p.save()
}

func (p *Prefs) SetPingSound(name string) {
	p.PingSound = name
	p.save()
}

func (p *Prefs) SetBreakOverSound(name string) {
	p.BreakOverSound = name
	p.save()
}

// ApplyEnvOverrides mirrors applyEnvironmentOverrides: EYE_REST_WORK_SECONDS
// / EYE_REST_BREAK_SECONDS adjust without persisting. Takes env explicitly so
// tests never depend on the process environment.
func (p *Prefs) ApplyEnvOverrides(env map[string]string) {
	if raw, ok := env["EYE_REST_WORK_SECONDS"]; ok {
		if v, err := strconv.ParseFloat(raw, 64); err == nil && v >= 1 {
			p.WorkDuration = v
		}
	}
	if raw, ok := env["EYE_REST_BREAK_SECONDS"]; ok {
		if v, err := strconv.ParseFloat(raw, 64); err == nil && v >= 1 {
			p.BreakDuration = v
		}
	}
}
