import Foundation

struct LyricsResult: Sendable {
    let lines: [LyricLine]
    let plain: String
}

actor LyricsManager {
    private var cache: [String: LyricsResult] = [:]
    func fetch(for track: Track, duration: TimeInterval?) async throws -> LyricsResult {
        if let cached = cache[track.id] { return cached }
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [URLQueryItem(name: "track_name", value: track.title), URLQueryItem(name: "artist_name", value: track.artist)]
        if let duration = duration ?? track.duration, duration.isFinite, duration > 0 {
            components.queryItems?.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
        }
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 20
        request.setValue("MochyMusic/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw MochyError.message("Lyrics response is invalid.") }
        if http.statusCode == 404 { return LyricsResult(lines: [], plain: "Lyrics unavailable for this track.") }
        guard (200..<300).contains(http.statusCode) else { throw MochyError.message("Lyrics service is unavailable.") }
        struct Response: Decodable { let syncedLyrics: String?; let plainLyrics: String?; let instrumental: Bool? }
        let result = try JSONDecoder().decode(Response.self, from: data)
        let lyrics = LyricsResult(lines: Self.parse(result.syncedLyrics ?? ""), plain: result.instrumental == true ? "Instrumental" : result.plainLyrics ?? "Lyrics unavailable for this track.")
        cache[track.id] = lyrics
        return lyrics
    }

    nonisolated static func parse(_ lrc: String) -> [LyricLine] {
        let regex = try! NSRegularExpression(pattern: #"\[(\d+):(\d{2})(?:\.(\d{1,3}))?\]"#)
        let offsetRegex = try! NSRegularExpression(pattern: #"(?i)\[offset:([+-]?\d+)\]"#)
        let source = lrc as NSString
        let offsetMatch = offsetRegex.firstMatch(in: lrc, range: NSRange(location: 0, length: source.length))
        let offset = offsetMatch.flatMap { Double(source.substring(with: $0.range(at: 1))) }.map { $0 / 1000 } ?? 0
        var values: [(Double, String)] = []
        for row in lrc.components(separatedBy: .newlines) {
            let text = row as NSString
            let matches = regex.matches(in: row, range: NSRange(location: 0, length: text.length))
            guard let last = matches.last else { continue }
            let lyric = text.substring(from: NSMaxRange(last.range)).trimmingCharacters(in: .whitespaces)
            for match in matches {
                let minutes = Double(text.substring(with: match.range(at: 1))) ?? 0
                let seconds = Double(text.substring(with: match.range(at: 2))) ?? 0
                guard seconds < 60 else { continue }
                let fraction = match.range(at: 3).location == NSNotFound ? 0 : Double("0." + text.substring(with: match.range(at: 3))) ?? 0
                values.append((max(0, minutes * 60 + seconds + fraction + offset), lyric))
            }
        }
        return values.enumerated().sorted { $0.element.0 == $1.element.0 ? $0.offset < $1.offset : $0.element.0 < $1.element.0 }
            .enumerated().map { LyricLine(id: $0.offset, timestamp: $0.element.element.0, text: $0.element.element.1) }
    }
}
