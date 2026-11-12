import Foundation

public final class InnerTubeService {
    public static let shared = InnerTubeService()
    private let session = URLSession.shared

    private init() {}

    /// Tìm kiếm bài hát qua InnerTube API
    public func search(query: String) async throws -> [Track] {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/search") else {
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": "1.20231201.01.00",
                    "hl": "vi",
                    "gl": "VN"
                ]
            ],
            "query": query,
            "params": "Eg-KAQwIABAAGAAgACgAMABqChAEEAMQCRAFEAo%3D" // Filter: Songs
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }

        return parseSearchResults(data)
    }

    /// Trích xuất stream audio trực tiếp qua player API
    public func getStreamUrl(videoId: String) async throws -> URL? {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/player") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "IOS",
                    "clientVersion": "19.29.1",
                    "deviceMake": "Apple",
                    "deviceModel": "iPhone16,2"
                ]
            ],
            "videoId": videoId
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let streamingData = json["streamingData"] as? [String: Any],
           let adaptiveFormats = streamingData["adaptiveFormats"] as? [[String: Any]] {
            // Lọc định dạng audio có bitrate cao nhất (ưu tiên m4a/audio)
            let audioFormats = adaptiveFormats.filter {
                ($0["mimeType"] as? String)?.contains("audio") ?? false
            }

            if let best = audioFormats.sorted(by: { ($0["bitrate"] as? Int ?? 0) > ($1["bitrate"] as? Int ?? 0) }).first,
               let urlString = best["url"] as? String {
                return URL(string: urlString)
            }
        }

        return nil
    }

    private func parseSearchResults(_ data: Data) -> [Track] {
        var tracks: [Track] = []
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contents = json["contents"] as? [String: Any],
              let tabbedRenderer = contents["tabbedSearchResultsRenderer"] as? [String: Any],
              let tabs = tabbedRenderer["tabs"] as? [[String: Any]],
              let firstTab = tabs.first,
              let tabRenderer = firstTab["tabRenderer"] as? [String: Any],
              let content = tabRenderer["content"] as? [String: Any],
              let sectionList = content["sectionListRenderer"] as? [String: Any],
              let sectionContents = sectionList["contents"] as? [[String: Any]] else {
            return []
        }

        for sec in sectionContents {
            if let shelf = sec["musicCardShelfRenderer"] as? [String: Any] {
                // Card nổi bật
                if let track = extractTrack(from: shelf) {
                    tracks.append(track)
                }
            } else if let shelf = sec["musicShelfRenderer"] as? [String: Any],
                      let items = shelf["contents"] as? [[String: Any]] {
                for item in items {
                    if let itemRenderer = item["musicResponsiveListItemRenderer"] as? [String: Any],
                       let track = extractTrack(from: itemRenderer) {
                        tracks.append(track)
                    }
                }
            }
        }

        return tracks
    }

    private func extractTrack(from dict: [String: Any]) -> Track? {
        var videoId: String? = nil
        var title: String = "Unknown Title"
        var artist: String = "Unknown Artist"
        var thumbUrl: URL? = nil

        // Lấy videoId
        if let playlistItemData = dict["playlistItemData"] as? [String: Any],
           let vid = playlistItemData["videoId"] as? String {
            videoId = vid
        }

        // Lấy Tiêu đề
        if let flexColumns = dict["flexColumns"] as? [[String: Any]] {
            if let firstCol = flexColumns.first,
               let rend = firstCol["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
               let textDict = rend["text"] as? [String: Any],
               let runs = textDict["runs"] as? [[String: Any]],
               let firstRun = runs.first {
                title = firstRun["text"] as? String ?? title
                if videoId == nil,
                   let nav = firstRun["navigationEndpoint"] as? [String: Any],
                   let watch = nav["watchEndpoint"] as? [String: Any],
                   let vid = watch["videoId"] as? String {
                    videoId = vid
                }
            }

            // Lấy Nghệ sĩ
            if flexColumns.count > 1 {
                let secondCol = flexColumns[1]
                if let rend = secondCol["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
                   let textDict = rend["text"] as? [String: Any],
                   let runs = textDict["runs"] as? [[String: Any]],
                   let firstRun = runs.first {
                    artist = firstRun["text"] as? String ?? artist
                }
            }
        }

        // Lấy Thumbnail
        if let thumbnail = dict["thumbnail"] as? [String: Any],
           let musicThumb = thumbnail["musicThumbnailRenderer"] as? [String: Any],
           let thumb = musicThumb["thumbnail"] as? [String: Any],
           let thumbnails = thumb["thumbnails"] as? [[String: Any]],
           let lastThumb = thumbnails.last,
           let urlString = lastThumb["url"] as? String {
            thumbUrl = URL(string: urlString)
        }

        guard let id = videoId else { return nil }
        return Track(id: id, title: title, artist: artist, durationSeconds: 210, thumbnailUrl: thumbUrl)
    }
}
