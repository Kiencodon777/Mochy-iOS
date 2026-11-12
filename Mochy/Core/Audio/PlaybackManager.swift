import Foundation
import AVFoundation
import MediaPlayer
import Combine

@MainActor
public final class PlaybackManager: ObservableObject {
    public static let shared = PlaybackManager()

    @Published public var currentTrack: Track?
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: Double = 0.0
    @Published public var duration: Double = 0.0
    @Published public var queue: [Track] = []
    @Published public var lyrics: [LyricLine] = []
    @Published public var currentLyricIndex: Int = 0

    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupAudioSession()
        setupRemoteCommands()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to configure AVAudioSession: \(error)")
        }
    }

    public func play(track: Track) {
        self.currentTrack = track
        self.currentTime = 0.0
        self.duration = track.durationSeconds

        Task {
            // Lấy stream URL
            if let streamUrl = try? await InnerTubeService.shared.getStreamUrl(videoId: track.id) {
                var updated = track
                updated.streamUrl = streamUrl
                self.currentTrack = updated
                self.startPlayer(with: streamUrl)
            }

            // Tải lời bài hát đồng thời
            if let fetchedLyrics = try? await LyricsManager.shared.fetchLyrics(
                trackName: track.title,
                artistName: track.artist,
                duration: track.durationSeconds
            ) {
                self.lyrics = fetchedLyrics
            }
        }
    }

    private func startPlayer(with url: URL) {
        player?.pause()
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        // Quan sát thời gian phát
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            if let dur = self.player?.currentItem?.duration.seconds, !dur.isNaN {
                self.duration = dur
            }
            self.updateCurrentLyricIndex()
            self.updateNowPlayingInfo()
        }

        player?.play()
        self.isPlaying = true
        setupNowPlayingInfo()
    }

    public func togglePlayPause() {
        guard let p = player else { return }
        if isPlaying {
            p.pause()
            isPlaying = false
        } else {
            p.play()
            isPlaying = true
        }
        updateNowPlayingInfo()
    }

    public func seek(to seconds: Double) {
        let target = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: target)
        currentTime = seconds
    }

    private func updateCurrentLyricIndex() {
        guard !lyrics.isEmpty else { return }
        for (index, line) in lyrics.enumerated() {
            if currentTime >= line.timestamp {
                if index == lyrics.count - 1 || currentTime < lyrics[index + 1].timestamp {
                    self.currentLyricIndex = index
                    break
                }
            }
        }
    }

    // MARK: - Lock Screen & Control Center
    private func setupNowPlayingInfo() {
        guard let track = currentTrack else { return }
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func updateNowPlayingInfo() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let positionEvent = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: positionEvent.positionTime)
                return .success
            }
            return .commandFailed
        }
    }
}
