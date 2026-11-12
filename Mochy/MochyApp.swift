import SwiftUI

@main
struct MochyApp: App {
    private let service: InnerTubeService
    @StateObject private var playback: PlaybackManager
    init() {
        let service = InnerTubeService()
        self.service = service
        _playback = StateObject(wrappedValue: PlaybackManager(service: service))
    }
    var body: some Scene {
        WindowGroup {
            HomeView(service: service).environmentObject(playback)
                .preferredColorScheme(.dark).tint(MochyTheme.accent)
        }
    }
}
