#!/bin/bash
# Builds the executable and assembles a proper .app bundle.
# The bundle (with Info.plist + ad-hoc signature) is what lets macOS attribute the
# Automation (Apple Events) permission to this app stably across rebuilds.
set -e
cd "$(dirname "$0")"

APP="Lyro"
BUNDLE="$APP.app"

echo "==> Building (release)…"
swift build -c release

BIN="$(swift build -c release --show-bin-path)/$APP"

echo "==> Assembling $BUNDLE…"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BIN" "$BUNDLE/Contents/MacOS/$APP"

# App icon (shown in Finder / Spotlight / Launchpad so it can be relaunched after quitting).
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$BUNDLE/Contents/Resources/AppIcon.icns"
fi

cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Lyro</string>
    <key>CFBundleDisplayName</key><string>Lyro</string>
    <key>CFBundleIdentifier</key><string>com.joyetgeorge.lyro</string>
    <key>CFBundleExecutable</key><string>$APP</string>
    <key>CFBundleVersion</key><string>1.0</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIconName</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <!-- Deliberately NOT LSUIElement: that flag hides the app from Spotlight and
         Launchpad. We become a menu-bar-only (accessory) app at runtime via
         setActivationPolicy(.accessory) in main.swift, which keeps it out of the
         Dock while still letting Spotlight index it (with its icon). -->
    <key>NSAppleEventsUsageDescription</key><string>Lyro reads the currently playing track from Spotify to display synced lyrics.</string>
</dict>
</plist>
PLIST

echo "==> Ad-hoc code signing…"
codesign --force --deep --sign - "$BUNDLE"

echo ""
echo "Built $BUNDLE"
echo "Launch it with:  open $BUNDLE      (or ./run.sh)"
echo "The first run will ask permission to control Spotify — click OK."
