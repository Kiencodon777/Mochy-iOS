import SwiftUI
import UIKit

struct IPodPlayerView: View {
    @EnvironmentObject private var playback: PlaybackManager
    @State private var lastAngle: Double?
    @State private var accumulated = 0.0
    @State private var volumeMode = true
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 12) {
                HStack { Text("Mochy").bold(); Spacer(); Image(systemName: "battery.100") }.font(.caption)
                Artwork(url: playback.track?.artworkURL).frame(width: 130, height: 130).clipShape(RoundedRectangle(cornerRadius: 8))
                Text(playback.track?.title ?? "Choose a song").font(.headline).lineLimit(2)
                Text(playback.track?.artist ?? "").font(.caption).lineLimit(1)
                ProgressView(value: min(playback.time, max(1, playback.duration)), total: max(1, playback.duration))
                Text(volumeMode ? "Wheel: volume · Center: seek mode" : "Wheel: seek · Center: volume mode").font(.caption2)
            }.padding(16).frame(maxWidth: .infinity).background(Color(red: 0.18, green: 0.22, blue: 0.20), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black, lineWidth: 4))
            ZStack {
                Circle().fill(Color(white: 0.12))
                Circle().fill(Color(white: 0.24)).frame(width: 88, height: 88)
                Button { volumeMode.toggle(); haptic.impactOccurred() } label: { Color.clear.frame(width: 88, height: 88).contentShape(Circle()) }.accessibilityLabel("Toggle wheel between volume and seek")
                VStack {
                    Text("MENU").font(.caption.bold()).padding(.top, 22)
                    Spacer()
                    Button { playback.toggle(); haptic.impactOccurred() } label: { Image(systemName: "playpause.fill").frame(width: 70, height: 48) }.accessibilityLabel("Toggle playback")
                }
                HStack {
                    Button { playback.previous(); haptic.impactOccurred() } label: { Image(systemName: "backward.end.fill").frame(width: 60, height: 70) }.accessibilityLabel("Previous song")
                    Spacer()
                    Button { playback.next(); haptic.impactOccurred() } label: { Image(systemName: "forward.end.fill").frame(width: 60, height: 70) }.accessibilityLabel("Next song")
                }
            }.frame(width: 260, height: 260).buttonStyle(.plain)
                .simultaneousGesture(DragGesture(minimumDistance: 8).onChanged { value in
                    let x = value.location.x - 130, y = value.location.y - 130
                    guard hypot(x, y) > 48 else { lastAngle = nil; return }
                    let angle = atan2(y, x)
                    defer { lastAngle = angle }
                    guard let previous = lastAngle else { haptic.prepare(); return }
                    var delta = angle - previous
                    if delta > .pi { delta -= 2 * .pi }; if delta < -.pi { delta += 2 * .pi }
                    accumulated += delta
                    if abs(accumulated) > 0.12 {
                        if volumeMode { playback.adjustVolume(Float(accumulated / 5)) }
                        else { playback.seek(playback.time + accumulated * 15) }
                        accumulated = 0; haptic.impactOccurred(intensity: 0.5)
                    }
                }.onEnded { _ in lastAngle = nil; accumulated = 0 })
                .accessibilityElement(children: .contain)
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: volumeMode ? playback.adjustVolume(0.05) : playback.seek(playback.time + 5)
                    case .decrement: volumeMode ? playback.adjustVolume(-0.05) : playback.seek(playback.time - 5)
                    @unknown default: break
                    }
                }
        }.padding(22).background(Color(white: 0.3), in: RoundedRectangle(cornerRadius: 28))
    }
}
