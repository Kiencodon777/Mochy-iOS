import SwiftUI
import UIKit

struct FullPlayerView: View {
    @EnvironmentObject private var playback: PlaybackManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showLyrics = false
    @State private var mode = "Player"
    @State private var scrub: Double?
    var body: some View {
        ZStack {
            MochyTheme.background.ignoresSafeArea()
            Artwork(url: playback.track?.artworkURL).blur(radius: 65).opacity(0.28).ignoresSafeArea().allowsHitTesting(false)
            ScrollView {
                VStack(spacing: 22) {
                    HStack {
                        Button { dismiss() } label: { Image(systemName: "chevron.down").padding(10) }.accessibilityLabel("Close player")
                        Spacer(); Text("NOW PLAYING").font(.caption.bold()).tracking(3); Spacer()
                        Button { showLyrics.toggle() } label: { Image(systemName: "quote.bubble").padding(10) }.accessibilityLabel("Toggle lyrics")
                    }
                    Picker("Player mode", selection: $mode) {
                        Text("Player").tag("Player"); Text("iPod").tag("iPod"); Text("Bedside").tag("Bedside")
                    }.pickerStyle(.segmented)
                    if let error = playback.error {
                        VStack(spacing: 10) {
                            Text(error).font(.callout).multilineTextAlignment(.center)
                            Button("Retry playback") { playback.retry() }
                        }.padding().mochyGlass()
                    }
                    if mode == "iPod" { IPodPlayerView() }
                    else if mode == "Bedside" { BedsideClockView() }
                    else {
                        if showLyrics { lyricsView.frame(height: 320) }
                        else {
                            Artwork(url: playback.track?.artworkURL).aspectRatio(1, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 28))
                                .shadow(color: .black.opacity(0.4), radius: 25, y: 15)
                                .scaleEffect(playback.isPlaying ? 1 : 0.94)
                                .animation(reduceMotion ? nil : .spring(duration: 0.5), value: playback.isPlaying)
                        }
                        VStack(spacing: 6) {
                            Text(playback.track?.title ?? "Nothing playing").font(.title2.bold()).multilineTextAlignment(.center)
                            Text(playback.track?.artist ?? "").foregroundStyle(MochyTheme.secondary)
                        }
                        VStack {
                            Slider(value: Binding(get: { scrub ?? playback.time }, set: { scrub = $0 }), in: 0...max(1, playback.duration), onEditingChanged: { editing in
                                if !editing, let scrub { playback.seek(scrub); self.scrub = nil }
                            }).disabled(playback.duration <= 0).accessibilityLabel("Playback position")
                            HStack { Text(playbackTime(scrub ?? playback.time)); Spacer(); Text(playbackTime(playback.duration)) }.font(.caption.monospacedDigit()).foregroundStyle(MochyTheme.secondary)
                        }
                        HStack(spacing: 26) {
                            Button { playback.shuffle.toggle() } label: { Image(systemName: "shuffle").foregroundStyle(playback.shuffle ? MochyTheme.accent : .white) }.accessibilityLabel("Shuffle").accessibilityValue(playback.shuffle ? "On" : "Off")
                            Button { playback.previous() } label: { Image(systemName: "backward.end.fill").font(.title) }.accessibilityLabel("Previous song")
                            Button { playback.toggle() } label: {
                                ZStack { Circle().fill(MochyTheme.accent).frame(width: 76, height: 76)
                                    if playback.isLoading { ProgressView().tint(.white) } else { Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill").font(.title) }
                                }
                            }.accessibilityLabel(playback.isPlaying ? "Pause" : "Play")
                            Button { playback.next() } label: { Image(systemName: "forward.end.fill").font(.title) }.accessibilityLabel("Next song")
                            Button { playback.repeatTrack.toggle() } label: { Image(systemName: "repeat.1").foregroundStyle(playback.repeatTrack ? MochyTheme.accent : .white) }.accessibilityLabel("Repeat song").accessibilityValue(playback.repeatTrack ? "On" : "Off")
                        }.buttonStyle(.plain)
                    }
                }.padding(24).frame(maxWidth: 580).frame(maxWidth: .infinity)
            }
        }.foregroundStyle(.white)
            .onChange(of: playback.track?.id) { _, _ in scrub = nil }
    }
    private var lyricsView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if playback.lines.isEmpty { Text(playback.plainLyrics).font(.title3).padding() }
                else {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(playback.lines) { line in
                            Button { playback.seek(line.timestamp) } label: {
                                Text(line.text.isEmpty ? "♪" : line.text).font(.title2.weight(playback.activeLyricID == line.id ? .bold : .medium))
                                    .foregroundStyle(playback.activeLyricID == line.id ? .white : .white.opacity(0.35))
                                    .scaleEffect(playback.activeLyricID == line.id ? 1 : 0.96, anchor: .leading)
                                    .multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.plain).id(line.id)
                        }
                    }.padding(.vertical, 100).padding(.horizontal, 8)
                }
            }.onChange(of: playback.activeLyricID) { _, id in
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { if let id { proxy.scrollTo(id, anchor: .center) } }
            }.onAppear { if let id = playback.activeLyricID { proxy.scrollTo(id, anchor: .center) } }
        }
    }
}

struct BedsideClockView: View {
    @EnvironmentObject private var playback: PlaybackManager
    var body: some View {
        VStack(spacing: 32) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(context.date, style: .time).font(.system(size: 64, weight: .ultraLight, design: .rounded)).minimumScaleFactor(0.5).monospacedDigit()
            }
            Text(playback.track?.title ?? "Mochy Music").font(.title3).multilineTextAlignment(.center)
            Button { playback.toggle() } label: { Image(systemName: playback.isPlaying ? "pause.circle" : "play.circle").font(.system(size: 56)) }.accessibilityLabel("Toggle playback")
        }.frame(maxWidth: .infinity).padding(.vertical, 80)
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}
