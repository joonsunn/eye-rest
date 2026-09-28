# EyeRestGo — Go spike of the eye-rest menu-bar app

Same product (20-20-20 timer, tray countdown, break pings, launch at login),
zero Swift, zero Xcode IDE. Lives on the `spike/go` branch for comparison;
the Swift app is untouched.

## Prerequisites

- Go 1.27+ and the Xcode CLT (clang). Verify with `make check`.
- Pure-Go builds need no Apple toolchain, but this app compiles ObjC via cgo (tray icon plus the notification bridge), so clang is mandatory. A missing clang fails the build loudly, never silently.
- Most dev machines already qualify: Homebrew refuses to work without the CLT, and macOS's git shim prompts for it on first clone.

## Build and test

- `make build`, `make test`, `make vet`, `make fmt` (10 tests).
- `make app` assembles ad-hoc-signed `.build/EyeRestGo.app`.
- `make run` opens the built app. First launch asks notification permission once, same as the Swift app.
- `make smoke` runs the bundled binary 25s with 10s/5s cycles and debug logging, then quits and prints the log.
- `make dist` builds the app and zips it as `.build/eye-rest-go-<version>-darwin-<arch>.zip`, ready to upload to a GitHub release. Override with `make dist VERSION=1.0 ARCH=arm64`.
- `make clean` removes build output.

## Quick start (correct setup)

1. `make check`, then `make app`.
2. Move `.build/EyeRestGo.app` to `/Applications` and open it from there. The login-item entry points at the bundle path, so set up autostart only once the app is in its final home.
3. Grant the one-time notification permission when prompted.
4. Toggle "Launch at login" in the menu. First toggle asks for Automation control of System Events; approve in System Settings, Privacy and Security, Automation. Toggling is idempotent: on twice (or off when absent) is a no-op, never a duplicate entry.
5. If the toggle fails, check the Automation approval above; a Deny there can only be undone manually in Settings.

## Uninstall

1. Quit the app from its menu.
2. Remove autostart: toggle "Launch at login" off before quitting, or delete the EyeRestGo entry under System Settings, General, Login Items. Headless: `osascript -e 'tell application "System Events" to delete login item "EyeRestGo"'`.
3. Delete `/Applications/EyeRestGo.app`.
4. Delete prefs: `rm -rf ~/Library/Application\ Support/EyeRestGo`.
5. Optional: reset the notification permission: `tccutil reset Notifications com.local.eye-rest-go`.

## How each Swift piece maps

- Menu bar: `getlantern/systray` (tray icon, title countdown, submenus, manual ✓ marks). No SwiftUI; all state mutations run on one goroutine fed by an action channel, the Go equivalent of `@MainActor`.
- Timer: line-for-line port of `EyeRestTimer`, including the sleep-gap reset with no backlog.
- Notifications: ~40 lines of ObjC (`notify_darwin.m`) calling `UNUserNotificationCenter` from the Go process via cgo. Same bundle-identity rules apply: real signed `.app` or the system ignores you, ad-hoc sign is the floor. Sounds resolve exactly like `resolveSound`, including the live NSGlobalDomain beep pick.
- Persistence: JSON at `~/Library/Application Support/EyeRestGo/prefs.json` instead of UserDefaults. Same defaults, same env overrides for testing.
- Settings pane link, permission status line, presets: all mirrored.
- Launch at login: osascript `System Events` login items instead of `SMAppService` (Go has no ServiceManagement binding). Works, but see below.

## MDM-relevant findings

- Build machine needs Go plus clang for cgo (systray and the notify bridge both compile ObjC). That is the CLT, not the Xcode IDE: `xcode-select --install` red tape, not App Store red tape.
- `codesign -s -` ships with macOS itself. No Apple toolchain needed for signing.
- The osascript login-item path costs a TCC Automation prompt (control of System Events) on first toggle. `SMAppService` has no such prompt. For MDM fleets that block Automation approvals, prefer shipping a LaunchAgent plist or accept the one-time prompt.
- Login-item toggle not smoke-tested here on purpose: it writes to the machine's real login items and pops the TCC prompt. Toggle it once manually to verify.
- Banner delivery still needs the one-time user grant, identical to the Swift app. The smoke run posted through the notify path with no crash (Swift raw binaries crash here for lack of bundle identity; the bundled Go binary does not).

## Gaps vs the Swift app

- No Dock/menu-bar SwiftUI niceties: status text is a disabled menu item, checkmarks are manual.
- Icon reused from `Sources/eye-rest/AppIcon.icns`.
- Bundle id is `com.local.eye-rest-go`, so notification permission and prefs do not clash with the Swift build.
