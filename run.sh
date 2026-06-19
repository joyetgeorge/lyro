#!/bin/bash
# Build, install to /Applications (so Spotlight/Launchpad can find it), then launch.
set -e
cd "$(dirname "$0")"

APP="Lyro"
BUNDLE="$APP.app"

./build.sh

# Install to /Applications (falls back to ~/Applications if that isn't writable),
# so the app is discoverable in Spotlight & Launchpad and relaunchable after quitting.
DEST="/Applications/$BUNDLE"
if ! { rm -rf "$DEST" && cp -R "$BUNDLE" "$DEST"; } 2>/dev/null; then
    mkdir -p "$HOME/Applications"
    DEST="$HOME/Applications/$BUNDLE"
    rm -rf "$DEST"
    cp -R "$BUNDLE" "$DEST"
fi
echo "==> Installed to $DEST"

# Register with Launch Services and nudge Spotlight so the icon/metadata refresh.
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
[ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$DEST" >/dev/null 2>&1 || true
mdimport "$DEST" >/dev/null 2>&1 || true

# Relaunch the freshly installed copy (kill any running instance first so the new
# binary actually starts rather than just re-activating the old one).
pkill -x "$APP" 2>/dev/null || true
sleep 1
echo "==> Launching…"
open "$DEST"
