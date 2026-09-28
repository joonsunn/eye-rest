// Package main is a Go spike of the eye-rest menu-bar app: 20-minute work
// countdown, break ping, 20-second rest, repeat. No Swift, no Xcode IDE.
package main

import "time"

// Phase of the 20-20-20 cycle.
type Phase int

const (
	PhaseWork Phase = iota
	PhaseOnBreak
)

// gapResetThreshold mirrors EyeRestTimer.timeGapResetThreshold: a wall-clock
// gap bigger than this restarts a fresh work cycle with no backlog.
const gapResetThreshold = 60.0

// Timer is a direct port of EyeRestTimer. Durations are seconds. Call Tick
// once per second from a ticker; tests drive it manually.
type Timer struct {
	Phase         Phase
	Remaining     float64
	Paused        bool
	WorkDuration  float64
	BreakDuration float64
	OnPhaseChange func(Phase)

	lastTick time.Time
	now      func() time.Time
}

// NewTimer builds a work-phase timer. Pass nil now for wall-clock time.
func NewTimer(work, rest float64, now func() time.Time) *Timer {
	if now == nil {
		now = time.Now
	}
	return &Timer{
		Phase:         PhaseWork,
		Remaining:     work,
		WorkDuration:  work,
		BreakDuration: rest,
		lastTick:      now(),
		now:           now,
	}
}

// Tick advances the countdown by one second. Safe to call in a loop.
func (t *Timer) Tick() {
	current := t.now()
	gap := current.Sub(t.lastTick).Seconds()
	t.lastTick = current

	if t.Paused {
		return
	}

	// Slept-through or otherwise missed time: restart fresh work, no backlog.
	if gap > gapResetThreshold {
		t.Phase = PhaseWork
		t.Remaining = t.WorkDuration
		return
	}

	t.Remaining--
	if t.Remaining <= 0 {
		switch t.Phase {
		case PhaseWork:
			t.Phase = PhaseOnBreak
			t.Remaining = t.BreakDuration
		case PhaseOnBreak:
			t.Phase = PhaseWork
			t.Remaining = t.WorkDuration
		}
		if t.OnPhaseChange != nil {
			t.OnPhaseChange(t.Phase)
		}
	}
}

func (t *Timer) Pause()       { t.Paused = true; t.lastTick = t.now() }
func (t *Timer) Resume()      { t.Paused = false; t.lastTick = t.now() }
func (t *Timer) TogglePause() { t.Paused = !t.Paused; t.lastTick = t.now() }

// Reset restarts a fresh work cycle from any phase. No notification fires.
func (t *Timer) Reset() {
	t.Phase = PhaseWork
	t.Remaining = t.WorkDuration
	t.lastTick = t.now()
}

// UpdateDurations replaces durations (clamped) and restarts fresh work.
func (t *Timer) UpdateDurations(work, rest float64) {
	t.WorkDuration = min(max(work, 60), 4*60*60)
	t.BreakDuration = min(max(rest, 5), 30*60)
	t.Reset()
}

// SkipBreak restarts the work cycle. No-op during work.
func (t *Timer) SkipBreak() {
	if t.Phase != PhaseOnBreak {
		return
	}
	t.Phase = PhaseWork
	t.Remaining = t.WorkDuration
	t.lastTick = t.now()
	if t.OnPhaseChange != nil {
		t.OnPhaseChange(PhaseWork)
	}
}
