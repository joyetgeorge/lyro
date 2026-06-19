import Foundation
import Combine

enum DisplayMode {
    case lyrics   // karaoke: previous / current / next
    case message  // a single status line (loading, no lyrics, paused, etc.)
}

private enum LyricsState {
    case idle
    case loading
    case synced
    case plainOnly
    case none
}

/// Owns the polling + timing logic and exposes the strings the overlay renders.
/// Two timers run on the main run loop:
///   • a 1s poll that asks Spotify for the track + authoritative playhead
///   • a 0.1s tick that interpolates the playhead and picks the active line
final class LyricsViewModel: ObservableObject {

    // Rendered state (consumed by OverlayView).
    @Published var mode: DisplayMode = .message
    @Published var headerText: String = ""
    @Published var message: String = "Starting…"
    @Published var previousLine: String?
    @Published var currentLine: String?
    @Published var nextLine: String?

    /// Invoked on the main thread whenever state changes (used to refresh the menu).
    var onUpdate: (() -> Void)?

    private let spotify = SpotifyController()
    private let lyricsService = LyricsService()
    private let pollQueue = DispatchQueue(label: "com.joyetgeorge.spotify.poll")

    private var pollTimer: Timer?
    private var tickTimer: Timer?

    // Track / lyrics state.
    private var currentTrack: SpotifyTrack?
    private var lyrics: [LyricLine] = []
    private var lyricsState: LyricsState = .idle
    private var playerState: PlayerState = .stopped
    private var permissionDenied = false

    // Playhead interpolation: anchor a known position to a monotonic clock reading.
    private var anchorPosition: Double = 0
    private var anchorClock: Double = 0

    // For menu display.
    private(set) var trackDescription: String = "Nothing playing"
    private(set) var statusDescription: String = ""

    func start() {
        poll()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        tickTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recompute()
        }
    }

    /// Force a fresh lyrics fetch for the current track (menu action).
    func reload() {
        guard let track = currentTrack else { return }
        loadLyrics(for: track)
    }

    // MARK: - Polling

    private func poll() {
        pollQueue.async { [weak self] in
            guard let self else { return }
            let snapshot = self.spotify.snapshot()
            DispatchQueue.main.async { self.apply(snapshot) }
        }
    }

    private func apply(_ snapshot: SpotifySnapshot) {
        permissionDenied = (snapshot.state == .denied)
        playerState = snapshot.state

        if let track = snapshot.track {
            anchorPosition = snapshot.position
            anchorClock = ProcessInfo.processInfo.systemUptime

            if track.id != currentTrack?.id {
                currentTrack = track
                loadLyrics(for: track)
            }
        } else {
            currentTrack = nil
            lyrics = []
            lyricsState = .idle
        }

        recompute()
    }

    private func loadLyrics(for track: SpotifyTrack) {
        lyrics = []
        lyricsState = .loading
        recompute()

        lyricsService.fetch(track) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                // Ignore stale responses if the track changed mid-flight.
                guard self.currentTrack?.id == track.id else { return }

                switch result {
                case .success(let res):
                    if !res.synced.isEmpty {
                        self.lyrics = res.synced
                        self.lyricsState = .synced
                    } else if let plain = res.plain, !plain.isEmpty {
                        self.lyricsState = .plainOnly
                    } else {
                        self.lyricsState = .none
                    }
                case .failure:
                    self.lyricsState = .none
                }
                self.recompute()
            }
        }
    }

    // MARK: - Timing + rendering

    private func estimatedPosition() -> Double {
        guard playerState == .playing else { return anchorPosition }
        let elapsed = ProcessInfo.processInfo.systemUptime - anchorClock
        return anchorPosition + max(0, elapsed)
    }

    private func indexForTime(_ t: Double) -> Int {
        var idx = -1
        for (i, line) in lyrics.enumerated() {
            if line.time <= t { idx = i } else { break }
        }
        return idx
    }

    private func displayText(_ s: String) -> String {
        s.isEmpty ? "♪" : s
    }

    private func recompute() {
        var newMode: DisplayMode = .message
        var newHeader = ""
        var newMessage = ""
        var newPrev: String?
        var newCur: String?
        var newNext: String?

        if permissionDenied {
            newMessage = "Allow automation for Spotify in System Settings ▸ Privacy & Security ▸ Automation, then choose Reload Lyrics."
        } else if currentTrack == nil {
            newMessage = (playerState == .stopped) ? "Nothing playing in Spotify" : "Waiting for Spotify…"
        } else {
            let track = currentTrack!
            newHeader = "\(track.title) — \(track.artist)"

            switch lyricsState {
            case .loading:
                newMessage = "Loading lyrics…"
            case .none:
                newMessage = "No lyrics found for this track"
            case .plainOnly:
                newMessage = "Synced lyrics unavailable for this track"
            case .idle:
                newMessage = "Waiting for Spotify…"
            case .synced:
                newMode = .lyrics
                let idx = indexForTime(estimatedPosition())
                newCur = idx >= 0 ? displayText(lyrics[idx].text) : "♪"
                newPrev = idx - 1 >= 0 ? displayText(lyrics[idx - 1].text) : nil
                newNext = idx + 1 < lyrics.count ? displayText(lyrics[idx + 1].text) : nil
            }
        }

        // Update menu strings.
        trackDescription = newHeader.isEmpty ? "Nothing playing" : newHeader
        statusDescription = lyricsStatusString()

        // Only publish when something actually changed to avoid redraw churn.
        var changed = false
        if mode != newMode { mode = newMode; changed = true }
        if headerText != newHeader { headerText = newHeader; changed = true }
        if message != newMessage { message = newMessage; changed = true }
        if previousLine != newPrev { previousLine = newPrev; changed = true }
        if currentLine != newCur { currentLine = newCur; changed = true }
        if nextLine != newNext { nextLine = newNext; changed = true }

        if changed { onUpdate?() }
    }

    private func lyricsStatusString() -> String {
        if permissionDenied { return "Automation permission needed" }
        switch playerState {
        case .stopped: return "Stopped"
        case .paused: return "Paused"
        case .denied: return "Automation permission needed"
        case .unknown: return "—"
        case .playing:
            switch lyricsState {
            case .synced: return "Synced lyrics"
            case .plainOnly: return "Plain lyrics only"
            case .loading: return "Loading…"
            case .none: return "No lyrics found"
            case .idle: return "Playing"
            }
        }
    }
}
