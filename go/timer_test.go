package main

import (
	"testing"
	"time"
)

func testClock(start time.Time) (func() time.Time, *time.Time) {
	now := start
	return func() time.Time { return now }, &now
}

func TestWorkToBreakToWork(t *testing.T) {
	now, _ := testClock(time.Now())
	tm := NewTimer(5, 5, now)
	for i := 0; i < 5; i++ {
		tm.Tick()
	}
	if tm.Phase != PhaseOnBreak {
		t.Fatalf("want onBreak, got %v", tm.Phase)
	}
	if tm.Remaining != 5 {
		t.Fatalf("want 5s break, got %v", tm.Remaining)
	}
	for i := 0; i < 5; i++ {
		tm.Tick()
	}
	if tm.Phase != PhaseWork || tm.Remaining != 5 {
		t.Fatalf("want fresh work/5s, got %v/%v", tm.Phase, tm.Remaining)
	}
}

func TestResetRestartsWork(t *testing.T) {
	now, _ := testClock(time.Now())
	tm := NewTimer(5, 5, now)
	for i := 0; i < 5; i++ {
		tm.Tick()
	}
	tm.Reset()
	if tm.Phase != PhaseWork || tm.Remaining != 5 {
		t.Fatalf("want work/5s, got %v/%v", tm.Phase, tm.Remaining)
	}
}

func TestPauseFreezesCountdown(t *testing.T) {
	now, _ := testClock(time.Now())
	tm := NewTimer(10, 5, now)
	tm.Tick()
	tm.Pause()
	before := tm.Remaining
	tm.Tick()
	if tm.Remaining != before {
		t.Fatalf("paused timer advanced: %v -> %v", before, tm.Remaining)
	}
	tm.Resume()
	tm.Tick()
	if tm.Remaining != before-1 {
		t.Fatalf("resumed timer did not advance, got %v", tm.Remaining)
	}
}

func TestLargeGapRestartsWorkNoBacklog(t *testing.T) {
	now, cur := testClock(time.Now())
	tm := NewTimer(20*60, 20, now)
	*cur = cur.Add(2 * time.Hour) // slept through everything
	tm.Tick()
	if tm.Phase != PhaseWork || tm.Remaining != 20*60 {
		t.Fatalf("want fresh work cycle, got %v/%v", tm.Phase, tm.Remaining)
	}
}

func TestUpdateDurationsClampsAndResets(t *testing.T) {
	now, _ := testClock(time.Now())
	tm := NewTimer(5, 5, now)
	tm.UpdateDurations(600, 30)
	if tm.WorkDuration != 600 || tm.BreakDuration != 30 {
		t.Fatalf("want 600/30, got %v/%v", tm.WorkDuration, tm.BreakDuration)
	}
	tm.UpdateDurations(1, 1)
	if tm.WorkDuration != 60 || tm.BreakDuration != 5 {
		t.Fatalf("want clamped 60/5, got %v/%v", tm.WorkDuration, tm.BreakDuration)
	}
}

func TestSkipBreakNoopDuringWork(t *testing.T) {
	now, _ := testClock(time.Now())
	tm := NewTimer(10, 5, now)
	tm.SkipBreak()
	if tm.Phase != PhaseWork || tm.Remaining != 10 {
		t.Fatalf("skip during work must no-op, got %v/%v", tm.Phase, tm.Remaining)
	}
	for i := 0; i < 10; i++ {
		tm.Tick()
	}
	tm.SkipBreak()
	if tm.Phase != PhaseWork || tm.Remaining != 10 {
		t.Fatalf("want fresh work, got %v/%v", tm.Phase, tm.Remaining)
	}
}

func TestFormat(t *testing.T) {
	if got := Format(125); got != "2:05" {
		t.Fatalf("want 2:05, got %s", got)
	}
	if got := Format(20); got != "0:20" {
		t.Fatalf("want 0:20, got %s", got)
	}
}
