import AppKit
import SwiftUI

/// Nine preset screen positions (a 3×3 grid), plus free-form dragging when unlocked.
private enum OverlayAnchor: String, CaseIterable {
    case topLeft, top, topRight
    case left, center, right
    case bottomLeft, bottom, bottomRight

    var title: String {
        switch self {
        case .topLeft:      return "Top Left"
        case .top:          return "Top"
        case .topRight:     return "Top Right"
        case .left:         return "Left"
        case .center:       return "Center"
        case .right:        return "Right"
        case .bottomLeft:   return "Bottom Left"
        case .bottom:       return "Bottom"
        case .bottomRight:  return "Bottom Right"
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let viewModel = LyricsViewModel()
    private let settings = OverlaySettings()
    private var window: NSWindow!
    private var statusItem: NSStatusItem!

    private var trackMenuItem: NSMenuItem!
    private var statusMenuItem: NSMenuItem!
    private var clickThroughItem: NSMenuItem!
    private var showTrackNameItem: NSMenuItem!

    private var clickThrough = true

    private let baseOverlaySize = CGSize(width: 780, height: 168)
    private let screenMargin: CGFloat = 24

    /// Current window size: the base dimensions scaled by the user's size setting.
    private var overlaySize: CGSize {
        CGSize(width: baseOverlaySize.width * CGFloat(settings.scale),
               height: baseOverlaySize.height * CGFloat(settings.scale))
    }

    // Persisted window origin (set whenever the card is moved or repositioned).
    private enum Key {
        static let originX = "overlay.originX"
        static let originY = "overlay.originY"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Accessory policy (no Dock icon) is set early in main.swift.
        setupWindow()
        setupStatusItem()

        viewModel.onUpdate = { [weak self] in self?.refreshMenu() }
        viewModel.start()
        refreshMenu()
    }

    // MARK: - Overlay window

    private func setupWindow() {
        let hosting = NSHostingView(
            rootView: OverlayView()
                .environmentObject(viewModel)
                .environmentObject(settings)
        )

        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: overlaySize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hosting
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false

        // Float above virtually everything, including other apps' full-screen spaces.
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        applyClickThrough()
        restorePosition()
        window.orderFrontRegardless()

        // Remember wherever the user drags the card to.
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification, object: window
        )
    }

    /// Restore the last saved origin, or fall back to the bottom-center anchor.
    private func restorePosition() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Key.originX) != nil,
           defaults.object(forKey: Key.originY) != nil {
            let origin = NSPoint(x: defaults.double(forKey: Key.originX),
                                 y: defaults.double(forKey: Key.originY))
            window.setFrame(NSRect(origin: clampToScreen(origin), size: overlaySize), display: true)
        } else {
            moveTo(.bottom, animate: false)
        }
    }

    private func moveTo(_ anchor: OverlayAnchor, animate: Bool) {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = overlaySize
        let w = size.width, h = size.height
        let m = screenMargin

        let x: CGFloat
        switch anchor {
        case .topLeft, .left, .bottomLeft:    x = visible.minX + m
        case .top, .center, .bottom:          x = visible.midX - w / 2
        case .topRight, .right, .bottomRight: x = visible.maxX - w - m
        }

        let y: CGFloat
        switch anchor {
        case .topLeft, .top, .topRight:       y = visible.maxY - h - m
        case .left, .center, .right:          y = visible.midY - h / 2
        case .bottomLeft, .bottom, .bottomRight: y = visible.minY + m
        }

        window.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true, animate: animate)
        saveOrigin()
    }

    /// Resize the window around its current center, then keep it on-screen.
    private func applyScale() {
        let size = overlaySize
        let old = window.frame
        let center = NSPoint(x: old.midX, y: old.midY)
        let origin = clampToScreen(NSPoint(x: center.x - size.width / 2,
                                           y: center.y - size.height / 2))
        window.setFrame(NSRect(origin: origin, size: size), display: true)
        saveOrigin()
    }

    /// Keep an origin within the current screen (handles display + size changes).
    private func clampToScreen(_ origin: NSPoint) -> NSPoint {
        guard let screen = window.screen ?? NSScreen.main else { return origin }
        let visible = screen.visibleFrame
        let size = overlaySize
        let maxX = max(visible.minX, visible.maxX - size.width)
        let maxY = max(visible.minY, visible.maxY - size.height)
        let x = min(max(origin.x, visible.minX), maxX)
        let y = min(max(origin.y, visible.minY), maxY)
        return NSPoint(x: x, y: y)
    }

    private func saveOrigin() {
        let origin = window.frame.origin
        UserDefaults.standard.set(Double(origin.x), forKey: Key.originX)
        UserDefaults.standard.set(Double(origin.y), forKey: Key.originY)
    }

    @objc private func windowDidMove() {
        saveOrigin()
    }

    private func applyClickThrough() {
        window.ignoresMouseEvents = clickThrough
        // When not click-through, let the user drag the card by its background.
        window.isMovableByWindowBackground = !clickThrough
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "music.note.list", accessibilityDescription: "Lyrics Overlay")
        }

        let menu = NSMenu()

        trackMenuItem = NSMenuItem(title: "Nothing playing", action: nil, keyEquivalent: "")
        trackMenuItem.isEnabled = false
        menu.addItem(trackMenuItem)

        statusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(.separator())

        clickThroughItem = NSMenuItem(title: "Click-through (lock)", action: #selector(toggleClickThrough(_:)), keyEquivalent: "")
        clickThroughItem.target = self
        clickThroughItem.state = clickThrough ? .on : .off
        menu.addItem(clickThroughItem)

        showTrackNameItem = NSMenuItem(title: "Show Track Name", action: #selector(toggleTrackName(_:)), keyEquivalent: "")
        showTrackNameItem.target = self
        showTrackNameItem.state = settings.showTrackName ? .on : .off
        menu.addItem(showTrackNameItem)

        // Position submenu (3×3 grid of presets).
        let positionItem = NSMenuItem(title: "Position", action: nil, keyEquivalent: "")
        let positionMenu = NSMenu()
        for anchor in OverlayAnchor.allCases {
            let item = NSMenuItem(title: anchor.title, action: #selector(setAnchor(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = anchor.rawValue
            positionMenu.addItem(item)
        }
        positionMenu.addItem(.separator())
        let dragHint = NSMenuItem(title: "Tip: uncheck lock, then drag the card", action: nil, keyEquivalent: "")
        dragHint.isEnabled = false
        positionMenu.addItem(dragHint)
        positionItem.submenu = positionMenu
        menu.addItem(positionItem)

        // Size + opacity sliders.
        menu.addItem(makeSliderMenuItem(
            title: "Size",
            value: settings.scale,
            min: OverlaySettings.minScale,
            max: OverlaySettings.maxScale,
            action: #selector(sizeChanged(_:))
        ))
        menu.addItem(makeSliderMenuItem(
            title: "Background Opacity",
            value: settings.backgroundOpacity,
            min: 0.0,
            max: 1.0,
            action: #selector(opacityChanged(_:))
        ))

        menu.addItem(.separator())

        let reloadItem = NSMenuItem(title: "Reload Lyrics", action: #selector(reloadLyrics), keyEquivalent: "r")
        reloadItem.target = self
        menu.addItem(reloadItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Lyrics Overlay", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    /// A custom menu item hosting a labeled slider.
    private func makeSliderMenuItem(title: String, value: Double, min: Double, max: Double, action: Selector) -> NSMenuItem {
        let item = NSMenuItem()
        let width: CGFloat = 220
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 44))

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.frame = NSRect(x: 14, y: 24, width: width - 28, height: 14)
        container.addSubview(label)

        let slider = NSSlider(value: value, minValue: min, maxValue: max, target: self, action: action)
        slider.isContinuous = true
        slider.frame = NSRect(x: 14, y: 6, width: width - 28, height: 18)
        container.addSubview(slider)

        item.view = container
        return item
    }

    private func refreshMenu() {
        trackMenuItem.title = viewModel.trackDescription
        statusMenuItem.title = viewModel.statusDescription
    }

    // MARK: - Actions

    @objc private func toggleClickThrough(_ sender: NSMenuItem) {
        clickThrough.toggle()
        sender.state = clickThrough ? .on : .off
        applyClickThrough()
    }

    @objc private func toggleTrackName(_ sender: NSMenuItem) {
        settings.showTrackName.toggle()
        sender.state = settings.showTrackName ? .on : .off
    }

    @objc private func setAnchor(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let anchor = OverlayAnchor(rawValue: raw) else { return }
        moveTo(anchor, animate: true)
    }

    @objc private func sizeChanged(_ sender: NSSlider) {
        settings.scale = sender.doubleValue
        applyScale()
    }

    @objc private func opacityChanged(_ sender: NSSlider) {
        settings.backgroundOpacity = sender.doubleValue
    }

    @objc private func reloadLyrics() {
        viewModel.reload()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
