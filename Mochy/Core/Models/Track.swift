import Foundation

struct Track: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let artist: String
    let duration: TimeInterval?
    let artworkURL: URL?
}

enum MochyError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let message): return message }
    }
}
