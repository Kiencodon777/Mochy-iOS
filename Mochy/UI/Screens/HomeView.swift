import SwiftUI

struct HomeView: View {
    let service: InnerTubeService
    @EnvironmentObject private var playback: PlaybackManager
    @State private var query = ""
    @State private var results: [Track] = []
    @State private var searching = false
    @State private var searchError: String?
    @State private var expanded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack { Text("MOCHY").font(.largeTitle.bold()); Spacer(); Image(systemName: "waveform").foregroundStyle(MochyTheme.accent) }
                    Text("Find your next obsession.").foregroundStyle(MochyTheme.secondary)
                    HStack {
                        Image(systemName: "magnifyingglass")
                        TextField("Songs, artists, moods", text: $query).submitLabel(.search).autocorrectionDisabled()
                        if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Clear search") }
                    }.padding().mochyGlass()
                    Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Discover · Trending songs" : "Search results").font(.title2.bold())
                    if searching { ProgressView().frame(maxWidth: .infinity).padding() }
                    if let searchError {
                        ContentUnavailableView("Couldn’t load music", systemImage: "wifi.exclamationmark", description: Text(searchError))
                        Button("Retry") { Task { await search() } }
                    } else if results.isEmpty && !searching {
                        ContentUnavailableView("No songs found", systemImage: "music.note", description: Text("Try another title or artist."))
                    }
                    LazyVStack(spacing: 12) {
                        ForEach(results) { track in
                            Button { playback.select(track, in: results) } label: {
                                HStack(spacing: 14) {
                                    Artwork(url: track.artworkURL).frame(width: 58, height: 58).clipShape(RoundedRectangle(cornerRadius: 12))
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(track.title).font(.headline).lineLimit(2).foregroundStyle(.white)
                                        Text(track.artist).font(.subheadline).foregroundStyle(MochyTheme.secondary).lineLimit(1)
                                    }
                                    Spacer()
                                    if playback.track?.id == track.id { Image(systemName: "waveform").foregroundStyle(MochyTheme.accent) }
                                    else if let duration = track.duration { Text(playbackTime(duration)).font(.caption).foregroundStyle(MochyTheme.secondary) }
                                }.padding(10).background(MochyTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(20)
            }.background(MochyTheme.background)
                .safeAreaInset(edge: .bottom) {
                    if let track = playback.track {
                        HStack(spacing: 12) {
                            Button { expanded = true } label: {
                                HStack {
                                    Artwork(url: track.artworkURL).frame(width: 46, height: 46).clipShape(RoundedRectangle(cornerRadius: 10))
                                    VStack(alignment: .leading) { Text(track.title).font(.subheadline.bold()).lineLimit(1); Text(track.artist).font(.caption).foregroundStyle(MochyTheme.secondary).lineLimit(1) }
                                    Spacer(minLength: 0)
                                }.contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel("Open player: \(track.title)")
                            if playback.isLoading { ProgressView() }
                            Button { playback.toggle() } label: { Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill").frame(width: 40, height: 44) }.accessibilityLabel(playback.isPlaying ? "Pause" : "Play")
                            Button { playback.next() } label: { Image(systemName: "forward.end.fill").frame(width: 32, height: 44) }.accessibilityLabel("Next song")
                        }.padding(12).mochyGlass().padding(.horizontal, 12).padding(.bottom, 6)
                            .gesture(DragGesture().onEnded { if $0.translation.height < -30 { expanded = true } })
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
        }
        .task(id: query) {
            do { try await Task.sleep(for: .milliseconds(350)); await search() } catch {}
        }
        .sheet(isPresented: $expanded) { FullPlayerView().environmentObject(playback) }
        .alert("Playback unavailable", isPresented: Binding(get: { playback.error != nil }, set: { if !$0 { playback.error = nil } })) {
            Button("Retry") { playback.retry() }
            Button("OK", role: .cancel) { playback.error = nil }
        } message: { Text(playback.error ?? "") }
    }

    private func search() async {
        searching = true; searchError = nil
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let tracks = try await service.search(text.isEmpty ? "trending songs" : text)
            try Task.checkCancellation()
            results = tracks; searching = false
        } catch is CancellationError {} catch {
            guard !Task.isCancelled else { return }
            results = []; searchError = error.localizedDescription; searching = false
        }
    }
}
