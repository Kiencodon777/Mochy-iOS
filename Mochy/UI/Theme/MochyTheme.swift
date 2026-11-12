import SwiftUI

enum MochyTheme {
    static let background = Color(red: 13/255, green: 13/255, blue: 17/255)
    static let surface = Color(red: 24/255, green: 24/255, blue: 32/255)
    static let accent = Color(red: 1, green: 77/255, blue: 121/255)
    static let secondary = Color(red: 142/255, green: 142/255, blue: 147/255)
}
extension View {
    func mochyGlass() -> some View {
        background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.08)))
    }
}

struct Artwork: View {
    let url: URL?
    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: {
                ZStack { MochyTheme.surface; Image(systemName: "music.note").font(.largeTitle).foregroundStyle(MochyTheme.accent) }
            }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.accessibilityHidden(true)
    }
}

func playbackTime(_ value: Double) -> String {
    guard value.isFinite, value >= 0 else { return "0:00" }
    let seconds = Int(min(value, 864000))
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
}
