#!/bin/sh
# Assemble EyeRest.app from a release build. UNUserNotificationCenter needs
# a real bundle, raw .build binaries crash with bundleProxyForCurrentProcess nil.
set -eu
cd "$(dirname "$0")/.."
swift build -c release
APP=".build/EyeRest.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/eye-rest" "$APP/Contents/MacOS/eye-rest"
cp "Sources/eye-rest/Info.plist" "$APP/Contents/Info.plist"
cp "Sources/eye-rest/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
# Ping sounds come from the build machine's own /System/Library/Sounds.
# Never commit Apple's files; missing sounds fall back to .default at runtime.
for f in /System/Library/Sounds/*.aiff; do
    [ -f "$f" ] && cp "$f" "$APP/Contents/Resources/"
done
# Ad-hoc sign: usernotificationsd silently ignores unsigned bundles,
# no prompt, no banner, status stuck notDetermined.
codesign --force --deep --sign - "$APP"
echo "Built $APP — run: open $APP"
