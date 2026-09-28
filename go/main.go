package main

import (
	"fmt"
	"log"
	"math"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/getlantern/systray"
)

// Format mirrors EyeRestApp.format: ceiling to whole seconds, m:ss.
func Format(seconds float64) string {
	total := int(math.Ceil(math.Max(0, seconds)))
	return fmt.Sprintf("%d:%02d", total/60, total%60)
}

// App owns every menu item. All mutations run on the loop goroutine, fed by
// an action channel, so clicks and ticks never race.
type App struct {
	prefs   *Prefs
	timer   *Timer
	debug   bool
	actions chan func(*App)

	statusItem       *systray.MenuItem
	pauseItem        *systray.MenuItem
	resetItem        *systray.MenuItem
	skipItem         *systray.MenuItem
	previewItem      *systray.MenuItem
	previewOverItem  *systray.MenuItem
	pingMenu         *systray.MenuItem
	breakSoundMenu   *systray.MenuItem
	settingsItem     *systray.MenuItem
	notifyStatusItem *systray.MenuItem
	workMenu         *systray.MenuItem
	breakMenu        *systray.MenuItem
	loginItem        *systray.MenuItem
	quitItem         *systray.MenuItem

	pingItems       []*systray.MenuItem
	breakSoundItems []*systray.MenuItem
	workItems       []*systray.MenuItem
	breakItems      []*systray.MenuItem

	sounds       []string
	notifyStatus string
	loginEnabled bool
	loginError   string
}

func envMap() map[string]string {
	env := map[string]string{}
	for _, kv := range os.Environ() {
		if i := strings.IndexByte(kv, '='); i >= 0 {
			env[kv[:i]] = kv[i+1:]
		}
	}
	return env
}

func main() {
	prefs := LoadPrefs(DefaultPrefsPath())
	prefs.ApplyEnvOverrides(envMap())
	timer := NewTimer(prefs.WorkDuration, prefs.BreakDuration, nil)
	app := &App{
		prefs:   prefs,
		timer:   timer,
		debug:   os.Getenv("EYE_REST_GO_DEBUG") == "1",
		actions: make(chan func(*App), 16),
	}
	timer.OnPhaseChange = app.onPhaseChange

	go func() {
		ch := make(chan os.Signal, 1)
		signal.Notify(ch, syscall.SIGINT, syscall.SIGTERM)
		<-ch
		systray.Quit()
	}()

	systray.Run(app.onReady, app.onExit)
}

func (a *App) logf(format string, args ...any) {
	if a.debug {
		log.Printf(format, args...)
	}
}

func (a *App) onExit() { a.logf("exit") }

func (a *App) onReady() {
	RequestNotificationAuth()
	a.sounds = BundledSounds()
	a.notifyStatus = NotificationStatusLine(NotificationAuthStatus())
	a.loginEnabled = LoginItemEnabled()
	a.logf("ready sounds=%v status=%q login=%v", a.sounds, a.notifyStatus, a.loginEnabled)

	systray.SetTooltip("Eye Rest")

	a.statusItem = systray.AddMenuItem("", "")
	a.statusItem.Disable()
	systray.AddSeparator()

	a.pauseItem = systray.AddMenuItem("Pause", "Pause the countdown")
	a.resetItem = systray.AddMenuItem("Reset timer", "Restart a fresh work cycle")
	a.skipItem = systray.AddMenuItem("Skip break", "Skip the current break")
	a.previewItem = systray.AddMenuItem("Preview break ping", "Show how the break ping looks and sounds")
	a.previewOverItem = systray.AddMenuItem("Preview break-over ping", "Show how the break-over ping looks and sounds")

	a.pingMenu = systray.AddMenuItem("Ping sound", "")
	a.pingItems = a.addSoundSubmenu(a.pingMenu, true)
	a.breakSoundMenu = systray.AddMenuItem("Break-over sound", "")
	a.breakSoundItems = a.addSoundSubmenu(a.breakSoundMenu, false)

	a.settingsItem = systray.AddMenuItem("Open Notification Settings", "")
	a.notifyStatusItem = systray.AddMenuItem(a.notifyStatus, "")
	a.notifyStatusItem.Disable()

	a.workMenu = systray.AddMenuItem("Work length", "")
	for _, m := range WorkPresets {
		m := m
		it := a.workMenu.AddSubMenuItem(fmt.Sprintf("%d min", m), "")
		a.workItems = append(a.workItems, it)
		a.watch(it.ClickedCh, func(a *App) {
			a.prefs.SetWorkMinutes(m)
			a.timer.UpdateDurations(a.prefs.WorkDuration, a.prefs.BreakDuration)
			a.logf("work=%dmin", m)
		})
	}
	a.breakMenu = systray.AddMenuItem("Break length", "")
	for _, s := range BreakPresets {
		s := s
		it := a.breakMenu.AddSubMenuItem(fmt.Sprintf("%d sec", s), "")
		a.breakItems = append(a.breakItems, it)
		a.watch(it.ClickedCh, func(a *App) {
			a.prefs.SetBreakSeconds(s)
			a.timer.UpdateDurations(a.prefs.WorkDuration, a.prefs.BreakDuration)
			a.logf("break=%dsec", s)
		})
	}

	systray.AddSeparator()
	a.loginItem = systray.AddMenuItem("Launch at login", "")
	if appBundlePath() == "" {
		a.loginItem.Disable()
	}
	a.quitItem = systray.AddMenuItem("Quit eye-rest-go", "")

	a.watch(a.pauseItem.ClickedCh, func(a *App) { a.timer.TogglePause() })
	a.watch(a.resetItem.ClickedCh, func(a *App) { a.timer.Reset() })
	a.watch(a.skipItem.ClickedCh, func(a *App) { a.timer.SkipBreak() })
	a.watch(a.previewItem.ClickedCh, func(a *App) {
		PostNotification("Preview — break ping", "This is how the break ping looks and sounds.", ResolveSoundName(a.prefs.PingSound, a.sounds))
	})
	a.watch(a.previewOverItem.ClickedCh, func(a *App) {
		PostNotification("Preview — break over", "This is how the break-over ping looks and sounds.", ResolveSoundName(a.prefs.BreakOverSound, a.sounds))
	})
	a.watch(a.settingsItem.ClickedCh, func(a *App) { OpenNotificationSettings() })
	a.watch(a.loginItem.ClickedCh, func(a *App) {
		if err := SetLoginItemEnabled(!a.loginEnabled); err != nil {
			a.loginError = err.Error()
			a.logf("login item error: %v", err)
		} else {
			a.loginError = ""
		}
		a.loginEnabled = LoginItemEnabled()
	})
	a.watch(a.quitItem.ClickedCh, func(a *App) { systray.Quit() })

	a.refresh()
	go a.loop()
}

// watch forwards clicks to the loop goroutine.
func (a *App) watch(ch chan struct{}, act func(*App)) {
	go func() {
		for range ch {
			a.actions <- act
		}
	}()
}

func (a *App) addSoundSubmenu(parent *systray.MenuItem, ping bool) []*systray.MenuItem {
	items := []*systray.MenuItem{}
	sys := parent.AddSubMenuItem("Follow system", "")
	items = append(items, sys)
	a.watch(sys.ClickedCh, func(a *App) {
		if ping {
			a.prefs.SetPingSound("system")
		} else {
			a.prefs.SetBreakOverSound("system")
		}
	})
	for _, s := range BundledSounds() {
		s := s
		it := parent.AddSubMenuItem(s, "")
		items = append(items, it)
		a.watch(it.ClickedCh, func(a *App) {
			if ping {
				a.prefs.SetPingSound(s)
			} else {
				a.prefs.SetBreakOverSound(s)
			}
		})
	}
	return items
}

func checkmark(current, want string) string {
	if current == want {
		return " ✓"
	}
	return ""
}

// onPhaseChange runs on the loop goroutine (called synchronously from Tick).
func (a *App) onPhaseChange(phase Phase) {
	switch phase {
	case PhaseWork:
		PostNotification("Break over", "Back to work.", ResolveSoundName(a.prefs.BreakOverSound, a.sounds))
		a.logf("phase=work notify=break-over")
	case PhaseOnBreak:
		PostNotification("Time for an eye break", "Look 20 ft away for 20 seconds.", ResolveSoundName(a.prefs.PingSound, a.sounds))
		a.logf("phase=onBreak notify=break-start")
	}
}

func (a *App) loop() {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	slow := 0
	for {
		select {
		case act := <-a.actions:
			act(a)
			a.refresh()
		case <-ticker.C:
			a.timer.Tick()
			a.logf("tick phase=%v remaining=%.0f paused=%v", a.timer.Phase, a.timer.Remaining, a.timer.Paused)
			slow++
			if slow >= 30 {
				slow = 0
				a.notifyStatus = NotificationStatusLine(NotificationAuthStatus())
				a.loginEnabled = LoginItemEnabled()
			}
			a.refresh()
		}
	}
}

// refresh syncs every visible label with state. systray setters marshal to
// the main thread, so this is safe from the loop goroutine.
func (a *App) refresh() {
	var phaseText string
	switch a.timer.Phase {
	case PhaseWork:
		phaseText = "Work"
	case PhaseOnBreak:
		phaseText = "Break"
	}
	remaining := Format(a.timer.Remaining)
	a.statusItem.SetTitle(fmt.Sprintf("%s: %s", phaseText, remaining))
	if a.timer.Phase == PhaseOnBreak {
		systray.SetTitle("Break " + remaining)
	} else {
		systray.SetTitle(remaining)
	}

	if a.timer.Paused {
		a.pauseItem.SetTitle("Resume")
	} else {
		a.pauseItem.SetTitle("Pause")
	}
	if a.timer.Phase == PhaseOnBreak {
		a.skipItem.Enable()
	} else {
		a.skipItem.Disable()
	}

	a.pingMenu.SetTitle("Ping sound")
	for i, it := range a.pingItems {
		name := "system"
		if i > 0 {
			name = a.sounds[i-1]
		}
		base := "Follow system"
		if i > 0 {
			base = name
		}
		it.SetTitle(base + checkmark(a.prefs.PingSound, name))
	}
	for i, it := range a.breakSoundItems {
		name := "system"
		if i > 0 {
			name = a.sounds[i-1]
		}
		base := "Follow system"
		if i > 0 {
			base = name
		}
		it.SetTitle(base + checkmark(a.prefs.BreakOverSound, name))
	}

	a.notifyStatusItem.SetTitle(a.notifyStatus)

	for i, it := range a.workItems {
		m := WorkPresets[i]
		mark := ""
		if int(a.prefs.WorkDuration) == m*60 {
			mark = " ✓"
		}
		it.SetTitle(fmt.Sprintf("%d min%s", m, mark))
	}
	for i, it := range a.breakItems {
		s := BreakPresets[i]
		mark := ""
		if int(a.prefs.BreakDuration) == s {
			mark = " ✓"
		}
		it.SetTitle(fmt.Sprintf("%d sec%s", s, mark))
	}

	title := "Launch at login"
	if a.loginEnabled {
		title += " ✓"
	}
	if appBundlePath() == "" {
		title += " (needs .app)"
	}
	if a.loginError != "" {
		title += " — " + a.loginError
	}
	a.loginItem.SetTitle(title)
}
