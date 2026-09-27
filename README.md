# Eye Rest

Menu-bar macOS app for 20-20-20 eye breaks. 20-minute countdown, break ping, 20-second rest, repeat. Local only: no network, no analytics, durations in UserDefaults.

## Requirements

- macOS 13+, Swift 6 toolchain (`xcode-select --install` suffices).

## Build and test

- `swift build`, `swift test` (10 tests).
- `./Scripts/make-app.sh` assembles signed `.build/EyeRest.app` (bundle required, raw binaries crash on notifications).
- `open .build/EyeRest.app` to run. First launch asks notification permission once.
- Fast check: `open --env EYE_REST_WORK_SECONDS=10 --env EYE_REST_BREAK_SECONDS=5 .build/EyeRest.app`.

## Menu

Pause/Resume, Reset (Cmd+R), Skip break, Work presets 5/15/20/30/45 min, Break presets 20/30/60 sec, test notification, permission readout, Quit (Cmd+Q).

## Troubleshooting

- No prompt or banner: menu shows permission state; enable in System Settings, Notifications, Eye Rest. Unsigned bundles are ignored by the system, always run the script-built app.
- Stale generic banner icon: bump `CFBundleVersion`, rebuild, `sudo rm -rf /Library/Caches/com.apple.iconservices.store`, reboot.
- Logs: `log stream --predicate 'subsystem == "com.local.eye-rest"'`.
