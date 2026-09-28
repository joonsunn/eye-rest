package main

/*
#cgo LDFLAGS: -framework Foundation -framework UserNotifications
#include <stdlib.h>
void EyeRestRequestAuth(void);
int EyeRestAuthStatus(void);
void EyeRestNotify(const char *title, const char *body, const char *soundName);
*/
import "C"

import (
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"unsafe"
)

// RequestNotificationAuth asks once; the system remembers the answer.
func RequestNotificationAuth() { C.EyeRestRequestAuth() }

// NotificationAuthStatus returns the UNAuthorizationStatus raw value.
func NotificationAuthStatus() int { return int(C.EyeRestAuthStatus()) }

// PostNotification queues a banner. soundFile is "Glass.aiff" or "" for default.
func PostNotification(title, body, soundFile string) {
	ct, cb := C.CString(title), C.CString(body)
	defer C.free(unsafe.Pointer(ct))
	defer C.free(unsafe.Pointer(cb))
	if soundFile == "" {
		C.EyeRestNotify(ct, cb, nil)
		return
	}
	cs := C.CString(soundFile)
	defer C.free(unsafe.Pointer(cs))
	C.EyeRestNotify(ct, cb, cs)
}

// ResourcesDir finds Contents/Resources for a bundled run, or the binary's
// own directory for raw `go run` / `go build` runs.
func ResourcesDir() string {
	exe, err := os.Executable()
	if err != nil {
		return "."
	}
	macos := filepath.Dir(exe)
	if filepath.Base(macos) == "MacOS" {
		if res := filepath.Join(filepath.Dir(filepath.Dir(exe)), "Resources"); dirExists(res) {
			return res
		}
	}
	return macos
}

func dirExists(path string) bool {
	fi, err := os.Stat(path)
	return err == nil && fi.IsDir()
}

// BundledSounds lists *.aiff basenames in Resources, mirroring the Swift
// bundledSounds list without hardcoding Apple-owned names. Missing files
// fall back to the default sound at post time.
func BundledSounds() []string {
	matches, _ := filepath.Glob(filepath.Join(ResourcesDir(), "*.aiff"))
	names := make([]string, 0, len(matches))
	for _, m := range matches {
		names = append(names, strings.TrimSuffix(filepath.Base(m), ".aiff"))
	}
	sort.Strings(names)
	return names
}

// SystemBeepName follows the NSGlobalDomain beep pick live, like resolveSound.
func SystemBeepName() string {
	out, err := exec.Command("defaults", "read", "NSGlobalDomain", "com.apple.sound.beep.sound").Output()
	if err != nil {
		return ""
	}
	base := strings.TrimSuffix(filepath.Base(strings.TrimSpace(string(out))), filepath.Ext(strings.TrimSpace(string(out))))
	return base
}

// ResolveSoundName maps a ping preference to a bundle sound file, or "" for
// the default sound. "system" follows the live beep pick.
func ResolveSoundName(preference string, bundled []string) string {
	name := preference
	if name == "system" {
		name = SystemBeepName()
	}
	for _, b := range bundled {
		if b == name {
			return name + ".aiff"
		}
	}
	return ""
}

// NotificationStatusLine mirrors EyeRestNotifications.statusLine.
func NotificationStatusLine(status int) string {
	var detail string
	switch status {
	case 2, 3, 4:
		detail = "on"
	case 1:
		detail = "off — enable in Settings"
	case 0:
		detail = "not asked yet — answer the prompt"
	default:
		detail = "unknown"
	}
	return "Notifications: " + detail
}

// OpenNotificationSettings deep-links the Settings pane, like the Swift app.
func OpenNotificationSettings() {
	_ = exec.Command("open", "x-apple.systempreferences:com.apple.Notifications-Settings.extension").Start()
}
