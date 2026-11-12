import AVFoundation
import MediaPlayer
import UIKit
import Combine

@MainActor
final class PlaybackManager: ObservableObject {
    @Published private(set) var track: Track?
    @Published private(set) var queue: [Track] = []
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    @Published private(set) var time: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var lines: [LyricLine] = []
    @Published private(set) var plainLyrics = ""
    @Published var error: String?
    @Published var repeatTrack = false
    @Published var shuffle = false
    let player = AVPlayer()
    private let service: InnerTubeService
    private let lyrics = LyricsManager()
    private var loadingTask: Task<Void, Never>?
    private var lyricTask: Task<Void, Never>?
    private var observer: Any?
    private var statusObservation: NSKeyValueObservation?
    private var rateObservation: NSKeyValueObservation?
    private var notifications: [NSObjectProtocol] = []
    private var remoteTargets: [(MPRemoteCommand, Any)] = []
    private var artwork: MPMediaItemArtwork?
    private var generation = UUID()
    private var wantsPlayback = false
    private var resumeAfterInterruption = false
    private var resolving = false

    init(service: InnerTubeService) {
        self.service = service
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.15, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.time = time.seconds.isFinite ? max(0, time.seconds) : 0
                let length = self.player.currentItem?.duration.seconds ?? 0
                if length.isFinite, length > 0 { self.duration = length }
                self.updateNowPlaying()
            }
        }
        rateObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                self.isPlaying = self.player.timeControlStatus == .playing
                self.isLoading = self.resolving || self.player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                self.updateNowPlaying()
            }
        }
        notifications.append(NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] note in
            guard let item = note.object as? AVPlayerItem else { return }
            Task { @MainActor in
                guard let self, item === self.player.currentItem else { return }
                if self.repeatTrack { self.seek(0); self.play() } else { self.next() }
            }
        })
        notifications.append(NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor in
                guard let self else { return }
                if type == AVAudioSession.InterruptionType.began.rawValue {
                    self.resumeAfterInterruption = self.wantsPlayback
                    self.pause()
                } else if self.resumeAfterInterruption && AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) {
                    self.play()
                }
            }
        })
        notifications.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { Task { @MainActor in self?.pause() } }
        })
        configureRemoteCommands()
    }

    deinit {
        if let observer { player.removeTimeObserver(observer) }
        notifications.forEach(NotificationCenter.default.removeObserver)
        for (command, target) in remoteTargets { command.removeTarget(target) }
        loadingTask?.cancel()
        lyricTask?.cancel()
    }

    var activeLyricID: Int? { lines.last(where: { $0.timestamp <= time })?.id }

    func select(_ track: Track, in tracks: [Track]) {
        queue = tracks.isEmpty ? [track] : tracks
        load(track)
    }

    private func load(_ newTrack: Track) {
        loadingTask?.cancel(); lyricTask?.cancel()
        generation = UUID()
        let token = generation
        player.pause(); player.replaceCurrentItem(with: nil)
        statusObservation = nil
        track = newTrack; time = 0; duration = newTrack.duration ?? 0
        lines = []; plainLyrics = "Loading lyrics…"; artwork = nil
        error = nil; resolving = true; isLoading = true; isPlaying = false; wantsPlayback = true
        updateNowPlaying()
        loadingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let url = try await service.streamURL(for: newTrack.id)
                try Task.checkCancellation()
                guard generation == token else { return }
                resolving = false
                let item = AVPlayerItem(url: url)
                statusObservation = item.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
                    Task { @MainActor in
                        guard let self, self.generation == token else { return }
                        if item.status == .failed {
                            self.error = item.error?.localizedDescription ?? "Audio could not be loaded. Try this track again."
                            self.isLoading = false; self.wantsPlayback = false
                        } else if item.status == .readyToPlay { self.isLoading = false }
                    }
                }
                player.replaceCurrentItem(with: item)
                if wantsPlayback { play() }
            } catch is CancellationError {} catch {
                guard generation == token else { return }
                self.error = error.localizedDescription; resolving = false; isLoading = false; wantsPlayback = false
            }
        }
        lyricTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await lyrics.fetch(for: newTrack, duration: newTrack.duration)
                try Task.checkCancellation()
                guard generation == token else { return }
                lines = result.lines; plainLyrics = result.plain
            } catch is CancellationError {} catch {
                if generation == token { plainLyrics = "Lyrics could not be loaded. \(error.localizedDescription)" }
            }
            if let url = newTrack.artworkURL,
               let (data, _) = try? await URLSession.shared.data(from: url),
               let image = UIImage(data: data), generation == token, !Task.isCancelled {
                artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                updateNowPlaying()
            }
        }
    }

    func play() {
        guard track != nil else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            wantsPlayback = true
            player.play()
        } catch { self.error = error.localizedDescription }
    }
    func pause() { wantsPlayback = false; player.pause(); isPlaying = false; updateNowPlaying() }
    func toggle() { wantsPlayback ? pause() : play() }
    func seek(_ seconds: Double) {
        guard seconds.isFinite else { return }
        let target = min(max(0, seconds), max(0, duration))
        time = target
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        updateNowPlaying()
    }
    func previous() {
        if time > 3 { seek(0); return }
        guard let track, let index = queue.firstIndex(of: track), index > 0 else { seek(0); return }
        load(queue[index - 1])
    }
    func next() {
        guard let track, let index = queue.firstIndex(of: track) else { return }
        if shuffle, let candidate = queue.filter({ $0.id != track.id }).randomElement() { load(candidate) }
        else if index + 1 < queue.count { load(queue[index + 1]) }
        else { pause() }
    }
    func adjustVolume(_ delta: Float) { player.volume = min(1, max(0, player.volume + delta)) }
    func retry() { if let track { load(track) } }

    private func updateNowPlaying() {
        guard let track else { return }
        var info: [String: Any] = [MPMediaItemPropertyTitle: track.title, MPMediaItemPropertyArtist: track.artist,
                                  MPMediaItemPropertyPlaybackDuration: duration, MPNowPlayingInfoPropertyElapsedPlaybackTime: time,
                                  MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
                                  MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue]
        if let artwork { info[MPMediaItemPropertyArtwork] = artwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        func register(_ command: MPRemoteCommand, action: @escaping @MainActor () -> Void) {
            command.isEnabled = true
            let target = command.addTarget { [weak self] _ in
                Task { @MainActor in if self?.track != nil { action() } }
                return .success
            }
            remoteTargets.append((command, target))
        }
        register(center.playCommand) { [weak self] in self?.play() }
        register(center.pauseCommand) { [weak self] in self?.pause() }
        register(center.togglePlayPauseCommand) { [weak self] in self?.toggle() }
        register(center.nextTrackCommand) { [weak self] in self?.next() }
        register(center.previousTrackCommand) { [weak self] in self?.previous() }
        center.changePlaybackPositionCommand.isEnabled = true
        let target = center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = event.positionTime
            Task { @MainActor in self?.seek(position) }
            return .success
        }
        remoteTargets.append((center.changePlaybackPositionCommand, target))
    }
}
