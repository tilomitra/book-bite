import Foundation
import AVFoundation
import MediaPlayer
import Combine

/// Service for managing audio playback with background support and lock screen controls
@MainActor
class AudioPlaybackService: NSObject, ObservableObject {
    static let shared = AudioPlaybackService()

    // MARK: - Published State

    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var playbackRate: Float = 1.0
    @Published private(set) var error: AudioPlaybackError?

    /// The book currently being played
    @Published private(set) var currentBook: Book?

    /// The summary containing audio info
    @Published private(set) var currentSummary: Summary?

    // MARK: - Private Properties

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var cancellables = Set<AnyCancellable>()
    private var artwork: MPMediaItemArtwork?
    private var artworkTask: Task<Void, Never>?

    // Playback rate options
    static let playbackRates: [Float] = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0]

    // Skip interval in seconds
    static let skipInterval: TimeInterval = 15

    // MARK: - Initialization

    private override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
    }

    // MARK: - Audio Session Setup

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
        } catch {
            if AppConfiguration.shared.isLoggingEnabled {
                print("AudioPlaybackService: Failed to set up audio session: \(error)")
            }
        }
    }

    // MARK: - Remote Command Center (Lock Screen Controls)

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.play()
            }
            return .success
        }

        // Pause
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pause()
            }
            return .success
        }

        // Toggle play/pause
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePlayPause()
            }
            return .success
        }

        // Skip forward
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: Self.skipInterval)]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.skipForward()
            }
            return .success
        }

        // Skip backward
        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: Self.skipInterval)]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.skipBackward()
            }
            return .success
        }

        // Seek (scrubbing)
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                self?.seek(to: positionEvent.positionTime)
            }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let book = currentBook else { return }

        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = book.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = book.formattedAuthors
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "BookBite Summary"
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackRate : 0.0
        if let artwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    /// Download the cover once per book; updateNowPlayingInfo runs every 0.5s and reuses it
    private func loadArtwork(for book: Book) {
        artworkTask?.cancel()
        artwork = nil
        guard let url = URL.bookCover(from: book.coverAssetName) else { return }
        artworkTask = Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data),
                  !Task.isCancelled else { return }
            self?.artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            self?.updateNowPlayingInfo()
        }
    }

    // MARK: - Playback Control

    /// Load and optionally start playing audio for a book
    func loadAudio(for book: Book, summary: Summary, autoPlay: Bool = true) {
        guard let audioUrlString = summary.audioUrl, let audioUrl = URL(string: audioUrlString) else {
            error = .noAudioAvailable
            return
        }

        // Stop current playback if any
        stop()

        isLoading = true
        error = nil
        currentBook = book
        currentSummary = summary
        loadArtwork(for: book)

        // Check for offline audio first
        if let offlineURL = OfflineStorageService.shared.getOfflineAudioURL(bookId: book.id) {
            setupPlayer(with: offlineURL, autoPlay: autoPlay)
        } else {
            setupPlayer(with: audioUrl, autoPlay: autoPlay)
        }
    }

    private func setupPlayer(with url: URL, autoPlay: Bool) {
        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        // Don't set rate here: a non-zero rate starts playback even when autoPlay is false

        // Observe player item status
        statusObserver = playerItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                switch item.status {
                case .readyToPlay:
                    self.isLoading = false
                    self.duration = item.duration.seconds.isFinite ? item.duration.seconds : 0
                    self.updateNowPlayingInfo()
                    if autoPlay {
                        self.play()
                    }

                case .failed:
                    self.isLoading = false
                    self.error = .playbackFailed(item.error?.localizedDescription ?? "Unknown error")

                case .unknown:
                    break

                @unknown default:
                    break
                }
            }
        }

        // Observe playback time
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.currentTime = time.seconds.isFinite ? time.seconds : 0
                self.updateNowPlayingInfo()
            }
        }

        // Observe when playback ends
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handlePlaybackEnded()
                }
            }
            .store(in: &cancellables)
    }

    private func handlePlaybackEnded() {
        isPlaying = false
        currentTime = duration
        updateNowPlayingInfo()
    }

    func play() {
        // Restart from the beginning after the summary finished
        if duration > 0 && currentTime >= duration {
            seek(to: 0)
        }
        player?.rate = playbackRate
        isPlaying = true
        updateNowPlayingInfo()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func stop() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)

        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }

        statusObserver?.invalidate()
        statusObserver = nil
        cancellables.removeAll()

        player = nil
        playerItem = nil

        isPlaying = false
        isLoading = false
        currentTime = 0
        duration = 0
        currentBook = nil
        currentSummary = nil
        error = nil
        artworkTask?.cancel()
        artwork = nil

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func seek(to time: TimeInterval) {
        let clampedTime = max(0, min(time, duration))
        let cmTime = CMTime(seconds: clampedTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = clampedTime
        updateNowPlayingInfo()
    }

    func skipForward() {
        seek(to: currentTime + Self.skipInterval)
    }

    func skipBackward() {
        seek(to: currentTime - Self.skipInterval)
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            player?.rate = rate
        }
        updateNowPlayingInfo()
    }

    // MARK: - Helpers

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    var remainingTime: TimeInterval {
        max(0, duration - currentTime)
    }

    var formattedCurrentTime: String {
        formatTime(currentTime)
    }

    var formattedDuration: String {
        formatTime(duration)
    }

    var formattedRemainingTime: String {
        "-" + formatTime(remainingTime)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Returns true if audio is currently active (playing or paused with content loaded)
    var isActive: Bool {
        currentBook != nil && playerItem != nil
    }
}

// MARK: - Errors

enum AudioPlaybackError: LocalizedError {
    case noAudioAvailable
    case playbackFailed(String)
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .noAudioAvailable:
            return "No audio available for this book"
        case .playbackFailed(let message):
            return "Playback failed: \(message)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        }
    }
}
