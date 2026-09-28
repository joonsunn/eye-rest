package main

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// loginItemName is the label under System Settings, General, Login Items.
const loginItemName = "EyeRestGo"

var errOutsideBundle = errors.New("login items need the .app bundle; run the built app, not go run")

// appBundlePath returns the enclosing EyeRestGo.app when running from
// Contents/MacOS, or "" for raw binaries where registration is meaningless.
func appBundlePath() string {
	exe, err := os.Executable()
	if err != nil {
		return ""
	}
	if filepath.Base(filepath.Dir(exe)) != "MacOS" {
		return ""
	}
	bundle := filepath.Dir(filepath.Dir(filepath.Dir(exe)))
	if filepath.Ext(bundle) != ".app" {
		return ""
	}
	return bundle
}

func osascript(script string) (string, error) {
	out, err := exec.Command("osascript", "-e", script).CombinedOutput()
	return strings.TrimSpace(string(out)), err
}

// LoginItemEnabled reads System Events login items. First use prompts a TCC
// Automation approval — the MDM-relevant cost of skipping SMAppService.
func LoginItemEnabled() bool {
	out, err := osascript(`tell application "System Events" to get the name of every login item`)
	if err != nil {
		return false
	}
	for _, name := range strings.Split(out, ", ") {
		if name == loginItemName {
			return true
		}
	}
	return false
}

// SetLoginItemEnabled adds or removes this bundle's login item. Idempotent:
// enabling twice (or disabling when absent) is a no-op, unlike a bare
// osascript `make`, which would stack duplicate entries.
func SetLoginItemEnabled(enabled bool) error {
	if enabled {
		if LoginItemEnabled() {
			return nil
		}
		bundle := appBundlePath()
		if bundle == "" {
			return errOutsideBundle
		}
		_, err := osascript(`tell application "System Events" to make login item at end with properties {path:"` + bundle + `", hidden:false}`)
		return err
	}
	if !LoginItemEnabled() {
		return nil
	}
	_, err := osascript(`tell application "System Events" to delete login item "` + loginItemName + `"`)
	return err
}
