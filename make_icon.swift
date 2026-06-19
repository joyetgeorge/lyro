#!/usr/bin/env swift
import AppKit

// Renders AppIcon.iconset (and you then run iconutil) for Spotify Lyrics Overlay:
// a rounded "squircle" with a green gradient and a centered white music note.
// Usage:  swift make_icon.swift <output-iconset-dir>

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
    let out = NSImage(size: image.size)
    out.lockFocus()
    let rect = NSRect(origin: .zero, size: image.size)
    image.draw(in: rect, from: rect, operation: .sourceOver, fraction: 1)
    color.set()
    rect.fill(using: .sourceAtop)
    out.unlockFocus()
    out.isTemplate = false
    return out
}

func render(_ px: Int) -> Data {
    let size = CGFloat(px)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)

    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx

    // Squircle background with a small transparent margin (macOS style).
    let margin = size * 0.085
    let rect = NSRect(x: margin, y: margin, width: size - 2 * margin, height: size - 2 * margin)
    let radius = rect.width * 0.2237
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    // Drop shadow under the squircle.
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = size * 0.04
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.02)
    shadow.set()
    NSColor.black.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Green gradient fill (Spotify-ish: bright green → deep teal).
    path.addClip()
    let top = NSColor(srgbRed: 30/255, green: 215/255, blue: 96/255, alpha: 1)
    let bottom = NSColor(srgbRed: 12/255, green: 110/255, blue: 86/255, alpha: 1)
    NSGradient(starting: top, ending: bottom)?.draw(in: rect, angle: -90)

    // Subtle top highlight for a glassy feel.
    let highlight = NSGradient(
        colors: [NSColor.white.withAlphaComponent(0.28), NSColor.white.withAlphaComponent(0.0)]
    )
    highlight?.draw(in: NSRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2), angle: -90)

    // Centered white music note (SF Symbol).
    let noteConfig = NSImage.SymbolConfiguration(pointSize: size * 0.46, weight: .semibold)
    if let symbol = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)?
        .withSymbolConfiguration(noteConfig) {
        let white = tinted(symbol, .white)
        let s = white.size
        let scale = (size * 0.52) / max(s.width, s.height)
        let drawSize = NSSize(width: s.width * scale, height: s.height * scale)
        let origin = NSPoint(x: (size - drawSize.width) / 2, y: (size - drawSize.height) / 2)

        NSGraphicsContext.saveGraphicsState()
        let glow = NSShadow()
        glow.shadowColor = NSColor.black.withAlphaComponent(0.30)
        glow.shadowBlurRadius = size * 0.02
        glow.shadowOffset = NSSize(width: 0, height: -size * 0.008)
        glow.set()
        white.draw(in: NSRect(origin: origin, size: drawSize),
                   from: NSRect(origin: .zero, size: s), operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// Standard iconset members.
let members: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for (name, px) in members {
    let data = render(px)
    let url = URL(fileURLWithPath: outDir).appendingPathComponent("\(name).png")
    try! data.write(to: url)
}

print("Wrote \(members.count) PNGs to \(outDir)")
