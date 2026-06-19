import SwiftUI
import Combine

/// User-tunable look & feel for the overlay card. Backed by UserDefaults so the
/// chosen opacity, size, and track-name visibility (and the window position,
/// handled in AppDelegate) survive relaunches.
final class OverlaySettings: ObservableObject {

    private enum Key {
        static let backgroundOpacity = "overlay.backgroundOpacity"
        static let scale = "overlay.scale"
        static let showTrackName = "overlay.showTrackName"
    }

    /// Allowed size range, as a multiplier on the base card dimensions.
    static let minScale = 0.6
    static let maxScale = 1.8

    /// 0 = fully see-through card (just floating text), 1 = solid frosted card.
    @Published var backgroundOpacity: Double {
        didSet { UserDefaults.standard.set(backgroundOpacity, forKey: Key.backgroundOpacity) }
    }

    /// Uniform size multiplier applied to the window and the card's typography.
    @Published var scale: Double {
        didSet { UserDefaults.standard.set(scale, forKey: Key.scale) }
    }

    /// Whether the "Title — Artist" header line is shown.
    @Published var showTrackName: Bool {
        didSet { UserDefaults.standard.set(showTrackName, forKey: Key.showTrackName) }
    }

    init() {
        let defaults = UserDefaults.standard

        let storedOpacity = defaults.object(forKey: Key.backgroundOpacity) as? Double
        backgroundOpacity = storedOpacity.map { min(max($0, 0), 1) } ?? 0.85

        let storedScale = defaults.object(forKey: Key.scale) as? Double
        scale = storedScale.map { min(max($0, Self.minScale), Self.maxScale) } ?? 1.0

        showTrackName = (defaults.object(forKey: Key.showTrackName) as? Bool) ?? true
    }
}
