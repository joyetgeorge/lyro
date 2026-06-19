import Foundation

/// One timed line of lyrics. `text` may be empty for instrumental breaks.
struct LyricLine: Equatable {
    let time: Double // seconds from start of track
    let text: String
}

struct LyricsResult {
    let synced: [LyricLine]
    let plain: String?
}

enum LyricsError: Error {
    case notFound
    case network
}

/// Fetches lyrics from lrclib.net — a free, key-less lyrics API that serves
/// time-synced (LRC) lyrics. Tries an exact signature match first, then a search.
final class LyricsService {

    // lrclib asks clients to identify themselves via User-Agent.
    private let userAgent = "Lyro/1.0 (macOS overlay; +https://lrclib.net)"
    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 12
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: cfg)
    }()

    func fetch(_ track: SpotifyTrack, completion: @escaping (Result<LyricsResult, Error>) -> Void) {
        var comps = URLComponents(string: "https://lrclib.net/api/get")!
        comps.queryItems = [
            URLQueryItem(name: "artist_name", value: track.artist),
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "album_name", value: track.album),
            URLQueryItem(name: "duration", value: String(Int(track.duration.rounded())))
        ]

        getJSON(comps.url!) { [weak self] data, status in
            guard let self else { return }
            if status == 200, let data, let result = self.decodeSingle(data) {
                completion(.success(result))
            } else {
                // Exact match failed — fall back to a fuzzy search.
                self.search(track, completion: completion)
            }
        }
    }

    private func search(_ track: SpotifyTrack, completion: @escaping (Result<LyricsResult, Error>) -> Void) {
        var comps = URLComponents(string: "https://lrclib.net/api/search")!
        comps.queryItems = [
            URLQueryItem(name: "track_name", value: track.title),
            URLQueryItem(name: "artist_name", value: track.artist)
        ]

        getJSON(comps.url!) { [weak self] data, status in
            guard let self else { return }
            guard status == 200, let data,
                  let items = try? JSONDecoder().decode([LRCLibTrack].self, from: data),
                  !items.isEmpty else {
                completion(.failure(LyricsError.notFound))
                return
            }

            // Prefer the first result that actually carries synced lyrics.
            let best = items.first(where: { ($0.syncedLyrics?.isEmpty == false) }) ?? items[0]
            completion(.success(self.makeResult(from: best)))
        }
    }

    private func decodeSingle(_ data: Data) -> LyricsResult? {
        guard let item = try? JSONDecoder().decode(LRCLibTrack.self, from: data) else { return nil }
        return makeResult(from: item)
    }

    private func makeResult(from item: LRCLibTrack) -> LyricsResult {
        let synced = item.syncedLyrics.map(LyricsService.parseLRC) ?? []
        return LyricsResult(synced: synced, plain: item.plainLyrics)
    }

    private func getJSON(_ url: URL, completion: @escaping (Data?, Int) -> Void) {
        var req = URLRequest(url: url)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        session.dataTask(with: req) { data, response, _ in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            completion(data, status)
        }.resume()
    }

    // MARK: - LRC parsing

    private static let tagRegex = try! NSRegularExpression(
        pattern: "\\[(\\d{1,3}):(\\d{1,2})(?:[.:](\\d{1,3}))?\\]"
    )

    /// Parses LRC text into sorted, timed lines. Metadata tags like `[ar:...]`
    /// are ignored because they don't match the `mm:ss` numeric pattern.
    static func parseLRC(_ lrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []

        for rawLine in lrc.components(separatedBy: .newlines) {
            let ns = rawLine as NSString
            let matches = tagRegex.matches(in: rawLine, range: NSRange(location: 0, length: ns.length))
            guard let last = matches.last else { continue }

            let textStart = last.range.location + last.range.length
            let text = ns.substring(from: textStart).trimmingCharacters(in: .whitespaces)

            for m in matches {
                let minutes = Double(ns.substring(with: m.range(at: 1))) ?? 0
                let seconds = Double(ns.substring(with: m.range(at: 2))) ?? 0
                var fraction = 0.0
                if m.range(at: 3).location != NSNotFound {
                    let fStr = ns.substring(with: m.range(at: 3))
                    fraction = (Double(fStr) ?? 0) / pow(10.0, Double(fStr.count))
                }
                lines.append(LyricLine(time: minutes * 60 + seconds + fraction, text: text))
            }
        }

        return lines.sorted { $0.time < $1.time }
    }
}

private struct LRCLibTrack: Decodable {
    let syncedLyrics: String?
    let plainLyrics: String?
    let instrumental: Bool?
}
