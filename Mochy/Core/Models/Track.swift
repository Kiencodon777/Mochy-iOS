import Foundation

public struct Track: Identifiable, Codable, Equatable, Hashable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String?
    public let durationSeconds: Double
    public let thumbnailUrl: URL?
    public var streamUrl: URL?

    public init(
        id: String,
        title: String,
        artist: String,
        album: String? = nil,
        durationSeconds: Double = 0.0,
        thumbnailUrl: URL? = nil,
        streamUrl: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.durationSeconds = durationSeconds
        self.thumbnailUrl = thumbnailUrl
        self.streamUrl = streamUrl
    }

    public var formattedDuration: String {
        let minutes = Int(durationSeconds) / 60
        let seconds = Int(durationSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

public struct LyricLine: Identifiable, Equatable {
    public let id = UUID()
    public let timestamp: TimeInterval
    public let text: String

    public init(timestamp: TimeInterval, text: String) {
        self.timestamp = timestamp
        self.text = text
    }
}
