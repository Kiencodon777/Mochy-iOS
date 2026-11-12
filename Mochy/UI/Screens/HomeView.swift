import SwiftUI

public struct HomeView: View {
    @StateObject private var playback = PlaybackManager.shared
    @State private var searchText = ""
    @State private var searchResults: [Track] = []
    @State private var isSearching = false
    @State private var showFullPlayer = false

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            MochyTheme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mochy Music")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(MochyTheme.textPrimary)
                        Text("Stream your universe")
                            .font(.system(size: 14))
                            .foregroundColor(MochyTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 16)

                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(MochyTheme.textSecondary)
                    TextField("Search songs, artists, albums...", text: $searchText)
                        .foregroundColor(MochyTheme.textPrimary)
                        .onSubmit {
                            performSearch()
                        }
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(MochyTheme.textSecondary)
                        }
                    }
                }
                .padding(14)
                .background(MochyTheme.surface)
                .cornerRadius(16)
                .padding(.horizontal)

                if isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: MochyTheme.accent))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(searchResults) { track in
                            Button(action: {
                                playback.play(track: track)
                            }) {
                                HStack(spacing: 14) {
                                    AsyncImage(url: track.thumbnailUrl) { phase in
                                        if let img = phase.image {
                                            img.resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 54, height: 54)
                                                .cornerRadius(10)
                                        } else {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(MochyTheme.surfaceHighlight)
                                                .frame(width: 54, height: 54)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(track.title)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(MochyTheme.textPrimary)
                                            .lineLimit(1)
                                        Text(track.artist)
                                            .font(.system(size: 13))
                                            .foregroundColor(MochyTheme.textSecondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(MochyTheme.accent)
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(MochyTheme.surfaceHighlight)
                        }
                    }
                    .listStyle(.plain)
                }

                Spacer()
            }

            // Mini Player Bar
            if playback.currentTrack != nil {
                MiniPlayerBar()
                    .onTapGesture {
                        showFullPlayer = true
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showFullPlayer) {
            FullPlayerView()
        }
    }

    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        Task {
            if let results = try? await InnerTubeService.shared.search(query: searchText) {
                self.searchResults = results
            }
            self.isSearching = false
        }
    }
}

public struct MiniPlayerBar: View {
    @ObservedObject var playback = PlaybackManager.shared

    public var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: playback.currentTrack?.thumbnailUrl) { phase in
                if let img = phase.image {
                    img.resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(MochyTheme.surfaceHighlight)
                        .frame(width: 44, height: 44)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(playback.currentTrack?.title ?? "")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(MochyTheme.textPrimary)
                    .lineLimit(1)

                Text(playback.currentTrack?.artist ?? "")
                    .font(.system(size: 12))
                    .foregroundColor(MochyTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: { playback.togglePlayPause() }) {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
                    .foregroundColor(MochyTheme.textPrimary)
                    .padding(8)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(MochyTheme.surface.opacity(0.95))
                .shadow(color: Color.black.opacity(0.4), radius: 10, y: 5)
        )
    }
}
