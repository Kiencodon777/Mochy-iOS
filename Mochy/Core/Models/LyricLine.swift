import Foundation

struct LyricLine: Identifiable, Equatable, Sendable {
    let id: Int
    let timestamp: TimeInterval
    let text: String
}
