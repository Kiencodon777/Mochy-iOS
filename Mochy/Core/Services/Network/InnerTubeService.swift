import Foundation

actor InnerTubeService {
    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    private func request(_ endpoint: String, body: [String: Any]) async throws -> [String: Any] {
        let url = URL(string: "https://music.youtube.com/youtubei/v1/\(endpoint)?prettyPrint=false")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MochyError.message("Music service request failed. Please try again.")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MochyError.message("Music service returned an unexpected response.")
        }
        if json["error"] != nil { throw MochyError.message("Music service rejected this request.") }
        return json
    }

    func search(_ query: String) async throws -> [Track] {
        let json = try await request("search", body: [
            "context": ["client": ["clientName": "WEB_REMIX", "clientVersion": "1.20261110.01.00", "hl": "en", "gl": "US"]],
            "query": query, "params": "EgWKAQIIAWoKEAkQBRAKEAMQBA%3D%3D"
        ])
        var tracks: [Track] = []
        func walk(_ value: Any) {
            if let dict = value as? [String: Any] {
                if let row = dict["musicResponsiveListItemRenderer"] as? [String: Any],
                   let columns = row["flexColumns"] as? [[String: Any]] {
                    let runs = columns.map { column -> [[String: Any]] in
                        let renderer = column["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any]
                        return (renderer?["text"] as? [String: Any])?["runs"] as? [[String: Any]] ?? []
                    }
                    let overlay = row["overlay"] as? [String: Any]
                    var videoID = (row["playlistItemData"] as? [String: Any])?["videoId"] as? String
                    func findID(_ value: Any) {
                        if let d = value as? [String: Any] {
                            if let w = d["watchEndpoint"] as? [String: Any], let id = w["videoId"] as? String { videoID = videoID ?? id }
                            for v in d.values { findID(v) }
                        } else if let a = value as? [Any] { a.forEach(findID) }
                    }
                    if let overlay { findID(overlay) }
                    if let first = runs.first { findID(first) }
                    let title = runs.first?.compactMap { $0["text"] as? String }.joined() ?? ""
                    let details = runs.dropFirst().flatMap { $0 }.compactMap { $0["text"] as? String }
                    let artist = details.first ?? "Unknown artist"
                    let duration = details.compactMap(Self.duration).last
                    let thumbnail = ((row["thumbnail"] as? [String: Any])?["musicThumbnailRenderer"] as? [String: Any])?["thumbnail"] as? [String: Any]
                    let thumbs = thumbnail?["thumbnails"] as? [[String: Any]]
                    if let id = videoID, !title.isEmpty {
                        tracks.append(Track(id: id, title: title, artist: artist, duration: duration,
                                            artworkURL: (thumbs?.last?["url"] as? String).flatMap(URL.init(string:))))
                    }
                }
                for v in dict.values { walk(v) }
            } else if let array = value as? [Any] { array.forEach(walk) }
        }
        walk(json)
        var seen = Set<String>()
        return tracks.filter { seen.insert($0.id).inserted }
    }

    private static func duration(_ text: String) -> TimeInterval? {
        let parts = text.split(separator: ":")
        guard (2...3).contains(parts.count), parts.allSatisfy({ Int($0) != nil }) else { return nil }
        return parts.reduce(0) { $0 * 60 + (Double($1) ?? 0) }
    }

    func streamURL(for id: String) async throws -> URL {
        let clients = [
            ["clientName": "IOS", "clientVersion": "21.26.4", "deviceMake": "Apple", "deviceModel": "iPhone16,2", "osName": "iPhone", "osVersion": "18.3.2.22D82"],
            ["clientName": "VISIONOS", "clientVersion": "1.02", "deviceMake": "Apple", "deviceModel": "RealityDevice17,1"],
            ["clientName": "WEB_REMIX", "clientVersion": "1.20261110.01.00"]
        ]
        var failure = "No compatible direct audio stream is available. YouTube may require authentication or a playback token."
        for client in clients {
            try Task.checkCancellation()
            do {
                let json = try await request("player", body: ["context": ["client": client], "videoId": id, "contentCheckOk": true, "racyCheckOk": true])
                let status = json["playabilityStatus"] as? [String: Any]
                if let reason = status?["reason"] as? String { failure = reason }
                let streaming = json["streamingData"] as? [String: Any]
                let formats = streaming?["adaptiveFormats"] as? [[String: Any]] ?? []
                // AVPlayer cannot reliably decode YouTube WebM/Opus containers. Prefer native AAC.
                let audio = formats.filter { ($0["mimeType"] as? String)?.hasPrefix("audio/mp4") == true }
                    .sorted { ($0["bitrate"] as? Int ?? 0) > ($1["bitrate"] as? Int ?? 0) }
                for format in audio {
                    if let text = format["url"] as? String, let url = URL(string: text), url.scheme == "https" { return url }
                }
            } catch is CancellationError { throw CancellationError() }
              catch { failure = error.localizedDescription }
        }
        throw MochyError.message(failure)
    }
}
