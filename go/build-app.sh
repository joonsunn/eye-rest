#!/bin/sh
# Assemble EyeRestGo.app from the Go spike. Mirrors Scripts/make-app.sh:
# UNUserNotificationCenter needs a real signed bundle, raw binaries get the
# app's notifications ignored. Only needs Go + clang (CLT), no Xcode IDE.
set -eu
cd "$(dirname "$0")"
go build -o .build/EyeRestGo.app/Contents/MacOS/eye-rest-go .
APP=".build/EyeRestGo.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
go build -o "$APP/Contents/MacOS/eye-rest-go" .
cp "Info.plist" "$APP/Contents/Info.plist"
cp "../Sources/eye-rest/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
# Ping sounds come from the build machine's own /System/Library/Sounds.
# Never commit Apple's files; missing sounds fall back to .default at runtime.
for f in /System/Library/Sounds/*.aiff; do
    [ -f "$f" ] && cp "$f" "$APP/Contents/Resources/"
done
# Ad-hoc sign: usernotificationsd silently ignores unsigned bundles.
codesign --force --deep --sign - "$APP"
echo "Built $APP — run: open $APP"
