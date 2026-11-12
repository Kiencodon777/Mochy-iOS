import SwiftUI

public struct FullPlayerView: View {
    @ObservedObject var playback = PlaybackManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var showLyrics = false

    public init() {}

    public var body: some View {
        ZStack {
            MochyTheme.background.ignoresSafeArea()

            // Dynamic Mesh/Blur Background
            if let url = playback.currentTrack?.thumbnailUrl {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 60)
                            .opacity(0.35)
                            .ignoresSafeArea()
                    }
                }
            }

            VStack(spacing: 24) {
                // Top Bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(MochyTheme.textPrimary)
                    }
                    Spacer()
                    Text("NOW PLAYING")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(MochyTheme.textSecondary)
                    Spacer()
                    Button(action: { withAnimation { showLyrics.toggle() } }) {
                        Image(systemName: showLyrics ? "music.note.list" : "quote.bubble.fill")
                            .font(.system(size: 18))
                            .foregroundColor(showLyrics ? MochyTheme.accent : MochyTheme.textPrimary)
                    }
                }
                .padding(.horizontal)

                Spacer()

                if showLyrics {
                    // Synced Lyrics View
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 20) {
                                ForEach(Array(playback.lyrics.enumerated()), id: \.element.id) { index, line in
                                    Text(line.text)
                                        .font(.system(size: 22, weight: playback.currentLyricIndex == index ? .bold : .medium))
                                        .foregroundColor(playback.currentLyricIndex == index ? MochyTheme.textPrimary : MochyTheme.textSecondary.opacity(0.5))
                                        .scaleEffect(playback.currentLyricIndex == index ? 1.05 : 1.0)
                                        .animation(.spring(response: 0.3), value: playback.currentLyricIndex)
                                        .id(index)
                                        .onTapGesture {
                                            playback.seek(to: line.timestamp)
                                        }
                                }
                            }
                            .padding()
                        }
                        .onChange(of: playback.currentLyricIndex) { newIndex in
                            withAnimation {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                    .frame(maxHeight: 400)
                } else {
                    // Album Artwork
                    AsyncImage(url: playback.currentTrack?.thumbnailUrl) { phase in
                        if let image = phase.image {
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 320, height: 320)
                                .cornerRadius(24)
                                .shadow(color: Color.black.opacity(0.6), radius: 25, x: 0, y: 15)
                        } else {
                            RoundedRectangle(cornerRadius: 24)
                                .fill(MochyTheme.surface)
                                .frame(width: 320, height: 320)
                        }
                    }
                }

                Spacer()

                // Track Info
                VStack(spacing: 6) {
                    Text(playback.currentTrack?.title ?? "No Song Playing")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(MochyTheme.textPrimary)
                        .lineLimit(1)

                    Text(playback.currentTrack?.artist ?? "Mochy Music")
                        .font(.system(size: 16))
                        .foregroundColor(MochyTheme.textSecondary)
                        .lineLimit(1)
                }
                .padding(.horizontal)

                // Progress Bar
                VStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { playback.currentTime },
                            set: { playback.seek(to: $0) }
                        ),
                        in: 0...max(playback.duration, 1.0)
                    )
                    .accentColor(MochyTheme.accent)

                    HStack {
                        Text(formatTime(playback.currentTime))
                        Spacer()
                        Text(formatTime(playback.duration))
                    }
                    .font(.caption)
                    .foregroundColor(MochyTheme.textSecondary)
                }
                .padding(.horizontal, 28)

                // Control Buttons
                HStack(spacing: 48) {
                    Button(action: {}) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 28))
                            .foregroundColor(MochyTheme.textPrimary)
                    }

                    Button(action: { playback.togglePlayPause() }) {
                        ZStack {
                            Circle()
                                .fill(MochyTheme.accent)
                                .frame(width: 72, height: 72)
                                .shadow(color: MochyTheme.accent.opacity(0.4), radius: 12)

                            Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .offset(x: playback.isPlaying ? 0 : 2)
                        }
                    }

                    Button(action: {}) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 28))
                            .foregroundColor(MochyTheme.textPrimary)
                    }
                }
                .padding(.bottom, 36)
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
