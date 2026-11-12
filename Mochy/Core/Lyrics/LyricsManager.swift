import Foundation

public final class LyricsManager {
    public static let shared = LyricsManager()
    private let session = URLSession.shared

    private init() {}

    /// Lấy lời bài hát đồng bộ từ LRCLib
    public func fetchLyrics(trackName: String, artistName: String, duration: Double) async throws -> [LyricLine] {
        guard var components = URLComponents(string: "https://lrclib.net/api/get") else {
            return []
        }

        components.queryItems = [
            URLQueryItem(name: "track_name", value: trackName),
            URLQueryItem(name: "artist_name", value: artistName),
            URLQueryItem(name: "duration", value: String(Int(duration)))
        ]

        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("MochyMusic-iOS/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }

        struct LRCLibResponse: Codable {
            let syncedLyrics: String?
            let plainLyrics: String?
        }

        let decoded = try JSONDecoder().decode(LRCLibResponse.self, from: data)

        if let synced = decoded.syncedLyrics, !synced.isEmpty {
            return parseLRC(synced)
        } else if let plain = decoded.plainLyrics, !plain.isEmpty {
            return plain.components(separatedBy: .newlines).map {
                LyricLine(timestamp: 0, text: $0)
            }
        }

        return []
    }

    /// Phân giải định dạng LRC ([mm:ss.xx] Text)
    public func parseLRC(_ lrcContent: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let regex = try? NSRegularExpression(pattern: "\\[(\\d+):(\\d+(?:\\.\\d+)?)\\](.*)")

        for rawLine in lrcContent.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let nsString = trimmed as NSString
            let matches = regex?.matches(in: trimmed, range: NSRange(location: 0, length: nsString.length)) ?? []

            for match in matches {
                if match.numberOfRanges >= 4 {
                    let minStr = nsString.substring(with: match.range(at: 1))
                    let secStr = nsString.substring(with: match.range(at: 2))
                    let textStr = nsString.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespaces)

                    if let min = Double(minStr), let sec = Double(secStr) {
                        let timestamp = min * 60.0 + sec
                        lines.append(LyricLine(timestamp: timestamp, text: textStr))
                    }
                }
            }
        }

        return lines.sorted { $0.timestamp < $1.timestamp }
    }
}
