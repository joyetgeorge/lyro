import AppKit

// Entry point. SwiftPM treats top-level code in main.swift as the executable's
// entry, so we wire up the NSApplication and its delegate here.
let app = NSApplication.shared
// Menu-bar-only (no Dock icon). Set here, before run(), rather than via the
// LSUIElement Info.plist flag — LSUIElement would hide the app from Spotlight
// and Launchpad, but this runtime call keeps it Dock-less while still indexable.
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
