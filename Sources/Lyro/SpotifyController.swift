import Foundation

/// The currently loaded Spotify track.
struct SpotifyTrack: Equatable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: Double // seconds
}

enum PlayerState: String {
    case playing
    case paused
    case stopped
    case denied   // automation permission not granted
    case unknown
}

struct SpotifySnapshot {
    let state: PlayerState
    let track: SpotifyTrack?
    let position: Double // seconds into the current track
}

/// Talks to the Spotify macOS app over AppleScript (via `osascript`) to read the
/// currently playing track and playhead position. Runs the script in a child
/// process so it never blocks the main thread; call `snapshot()` off the main queue.
final class SpotifyController {

    // Note: `application "Spotify" is running` does NOT launch Spotify, so polling
    // while Spotify is closed won't force it open. Fields are tab-separated.
    // Spotify reports track `duration` in milliseconds and `player position` in seconds.
    private let source = """
    if application "Spotify" is running then
        tell application "Spotify"
            set playerState to (player state as text)
            if playerState is "stopped" then
                return "stopped"
            end if
            set t to current track
            set out to playerState & "\t" & (id of t as text) & "\t" & (name of t as text) ¬
                & "\t" & (artist of t as text) & "\t" & (album of t as text) ¬
                & "\t" & (duration of t as text) & "\t" & (player position as text)
            return out
        end tell
    else
        return "notrunning"
    end if
    """

    func snapshot() -> SpotifySnapshot {
        let result = runOSA(source)

        // Detect a denied / undecided automation permission (errAEEventNotPermitted).
        if let err = result.error,
           err.contains("-1743") || err.lowercased().contains("not authori") || err.lowercased().contains("not allowed") {
            return SpotifySnapshot(state: .denied, track: nil, position: 0)
        }

        guard let raw = result.output else {
            return SpotifySnapshot(state: .unknown, track: nil, position: 0)
        }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "notrunning" || trimmed.isEmpty {
            return SpotifySnapshot(state: .stopped, track: nil, position: 0)
        }
        if trimmed == "stopped" {
            return SpotifySnapshot(state: .stopped, track: nil, position: 0)
        }

        let parts = trimmed.components(separatedBy: "\t")
        guard parts.count >= 7 else {
            // Playing/paused but missing fields — treat as no usable track.
            let state = PlayerState(rawValue: parts.first ?? "") ?? .unknown
            return SpotifySnapshot(state: state, track: nil, position: 0)
        }

        let state = PlayerState(rawValue: parts[0]) ?? .unknown
        let durationMs = Double(parts[5]) ?? 0
        let position = Double(parts[6]) ?? 0
        let track = SpotifyTrack(
            id: parts[1],
            title: parts[2],
            artist: parts[3],
            album: parts[4],
            duration: durationMs / 1000.0
        )
        return SpotifySnapshot(state: state, track: track, position: position)
    }

    private func runOSA(_ script: String) -> (output: String?, error: String?) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        do {
            try proc.run()
        } catch {
            return (nil, error.localizedDescription)
        }

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()

        let out = String(data: outData, encoding: .utf8)
        let err = String(data: errData, encoding: .utf8)
        return (out, (err?.isEmpty ?? true) ? nil : err)
    }
}
