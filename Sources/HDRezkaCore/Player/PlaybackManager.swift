import Foundation
import AVFoundation
import MediaPlayer
import Combine

@MainActor
public final class PlaybackManager: ObservableObject {
    public static let shared = PlaybackManager()
    
    // MARK: - Published Playback State
    @Published public var isPresented: Bool = false
    @Published public var currentMedia: MediaItem?
    @Published public var currentMediaDetail: MediaDetail?
    @Published public var currentStreamBundle: StreamBundle?
    @Published public var currentStream: StreamOption?
    @Published public var currentQuality: VideoQuality = .res1080p
    @Published public var currentSeason: Season?
    @Published public var currentEpisode: Episode?
    @Published public var currentTranslation: Translation?
    
    @Published public var isPlaying: Bool = false
    @Published public var isBuffering: Bool = false
    @Published public var currentTime: Double = 0
    @Published public var duration: Double = 0
    @Published public var bufferedTime: Double = 0
    @Published public var playbackRate: Float = 1.0
    
    @Published public var activeSubtitleTrack: SubtitleTrack?
    @Published public var currentSubtitleCue: String?
    
    @Published public var showNextEpisodePrompt: Bool = false
    @Published public var nextEpisodeCountdown: Int = 10
    
    // MARK: - AVPlayer Core
    public let player: AVPlayer = AVPlayer()
    private var timeObserverToken: Any?
    private var itemStatusObserver: NSKeyValueObservation?
    private var itemBufferObserver: NSKeyValueObservation?
    private var nextEpisodeTimer: AnyCancellable?
    
    public init() {
        setupAudioSession()
        setupRemoteCommands()
        setupPeriodicTimeObserver()
    }
    
    // MARK: - Audio Session & Background Audio
    private func setupAudioSession() {
        do {
            #if os(iOS) || os(tvOS) || os(visionOS)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
            try AVAudioSession.sharedInstance().setActive(true)
            #endif
        } catch {
            print("Failed to configure AVAudioSession: \(error)")
        }
    }
    
    // MARK: - Load & Play Media
    public func playMedia(
        item: MediaItem,
        detail: MediaDetail? = nil,
        translation: Translation? = nil,
        season: Season? = nil,
        episode: Episode? = nil,
        preferredQuality: VideoQuality = .res1080p,
        startFromSavedPosition: Bool = true
    ) async {
        self.currentMedia = item
        self.currentMediaDetail = detail
        self.currentSeason = season
        self.currentEpisode = episode
        self.currentQuality = preferredQuality
        self.isPresented = true
        self.isBuffering = true
        self.showNextEpisodePrompt = false
        
        let targetTranslator = translation ?? detail?.translators.first ?? Translation(id: "1", title: "Default", isDefault: true)
        self.currentTranslation = targetTranslator
        
        // Fetch Streams via Scraper Engine / Cloudflare
        var bundle: StreamBundle?
        if await CloudflareClient.shared.isConfigured() {
            bundle = try? await CloudflareClient.shared.fetchStreams(
                mediaId: item.id,
                translatorId: targetTranslator.id,
                season: season?.number,
                episode: episode?.episodeNumber
            )
        }
        
        if bundle == nil {
            bundle = try? await HDRezkaScraperEngine.shared.fetchStreams(
                mediaId: item.id,
                translatorId: targetTranslator.id,
                season: season?.number,
                episode: episode?.episodeNumber,
                action: (season != nil) ? "get_stream" : "get_movie",
                contentType: item.contentType
            )
        }
        
        guard let validBundle = bundle, !validBundle.streams.isEmpty else {
            self.isBuffering = false
            return
        }
        
        self.currentStreamBundle = validBundle
        
        // Select matching or best resolution
        let selectedStream = validBundle.stream(for: preferredQuality) ?? validBundle.streams.first!
        self.currentStream = selectedStream
        
        // Check saved progress
        var resumeTime: Double = 0
        if startFromSavedPosition {
            if let saved = await LocalStorageManager.shared.getProgress(for: item.id), !saved.isCompleted {
                resumeTime = saved.currentTimeSeconds
            }
        }
        
        loadStream(selectedStream, resumeAt: resumeTime)
    }
    
    private func loadStream(_ stream: StreamOption, resumeAt: Double = 0) {
        let headers: [String: String] = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1",
            "Referer": "https://rezka.ag/"
        ]
        let asset = AVURLAsset(url: stream.url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 5
        player.automaticallyWaitsToMinimizeStalling = true
        
        // Observe status
        itemStatusObserver?.invalidate()
        itemStatusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if item.status == .readyToPlay {
                    self.isBuffering = false
                    self.duration = item.duration.seconds.isFinite ? item.duration.seconds : 0
                    if resumeAt > 0 {
                        self.seek(to: resumeAt)
                    }
                    self.play()
                    self.updateNowPlayingInfo()
                } else if item.status == .failed {
                    self.isBuffering = false
                    print("⚠️ AVPlayerItem failed: \(String(describing: item.error))")
                }
            }
        }
        
        // Observe loaded time ranges (buffering)
        itemBufferObserver?.invalidate()
        itemBufferObserver = playerItem.observe(\.loadedTimeRanges, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self = self, let timeRange = item.loadedTimeRanges.first?.timeRangeValue else { return }
                self.bufferedTime = timeRange.start.seconds + timeRange.duration.seconds
                if item.isPlaybackLikelyToKeepUp {
                    self.isBuffering = false
                }
            }
        }
        
        player.replaceCurrentItem(with: playerItem)
        self.play()
    }
    
    // MARK: - Transport Controls
    public func play() {
        player.play()
        player.rate = playbackRate
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    public func pause() {
        player.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    public func seek(to seconds: Double) {
        let target = CMTime(seconds: max(0, min(seconds, duration)), preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateNowPlayingInfo()
            }
        }
    }
    
    public func skip(seconds: Double) {
        seek(to: currentTime + seconds)
    }
    
    public func changePlaybackSpeed(to rate: Float) {
        self.playbackRate = rate
        if isPlaying {
            player.rate = rate
        }
        updateNowPlayingInfo()
    }
    
    // MARK: - Quality Switch (Preserving Exact Timestamp)
    public func changeQuality(to quality: VideoQuality) {
        guard let bundle = currentStreamBundle,
              let targetStream = bundle.stream(for: quality),
              targetStream.id != currentStream?.id else { return }
        
        let savedTime = currentTime
        self.currentQuality = quality
        self.currentStream = targetStream
        self.isBuffering = true
        
        loadStream(targetStream, resumeAt: savedTime)
    }
    
    // MARK: - Translation / Voiceover Switch
    public func changeTranslation(to translation: Translation) async {
        guard let media = currentMedia else { return }
        let savedTime = currentTime
        self.currentTranslation = translation
        self.isBuffering = true
        
        await playMedia(
            item: media,
            detail: currentMediaDetail,
            translation: translation,
            season: currentSeason,
            episode: currentEpisode,
            preferredQuality: currentQuality,
            startFromSavedPosition: false
        )
        
        seek(to: savedTime)
    }
    
    // MARK: - Subtitles
    public func selectSubtitleTrack(_ track: SubtitleTrack?) async {
        self.activeSubtitleTrack = track
        if let t = track {
            _ = await SubtitleManager.shared.loadSubtitles(from: t)
        } else {
            await SubtitleManager.shared.clearSubtitles()
            self.currentSubtitleCue = nil
        }
    }
    
    // MARK: - Auto Next Episode Logic
    public func playNextEpisode() {
        guard let season = currentSeason, let episode = currentEpisode,
              let media = currentMedia, let detail = currentMediaDetail else { return }
        
        showNextEpisodePrompt = false
        nextEpisodeTimer?.cancel()
        
        // Find next episode in current season
        if let nextEp = season.episodes.first(where: { $0.episodeNumber == episode.episodeNumber + 1 }) {
            Task {
                await playMedia(
                    item: media,
                    detail: detail,
                    translation: currentTranslation,
                    season: season,
                    episode: nextEp,
                    preferredQuality: currentQuality,
                    startFromSavedPosition: false
                )
            }
            return
        }
        
        // Or find first episode of next season
        if let nextSeason = detail.seasons.first(where: { $0.number == season.number + 1 }),
           let firstEp = nextSeason.episodes.first {
            Task {
                await playMedia(
                    item: media,
                    detail: detail,
                    translation: currentTranslation,
                    season: nextSeason,
                    episode: firstEp,
                    preferredQuality: currentQuality,
                    startFromSavedPosition: false
                )
            }
        }
    }
    
    public func dismissPlayer() {
        pause()
        isPresented = false
        player.replaceCurrentItem(with: nil)
        nextEpisodeTimer?.cancel()
    }
    
    // MARK: - Periodic Time Observer
    private func setupPeriodicTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            let sec = time.seconds
            guard sec.isFinite else { return }
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.currentTime = sec
                
                // Query live subtitles
                if let cue = await SubtitleManager.shared.getCue(at: sec) {
                    self.currentSubtitleCue = cue
                } else {
                    self.currentSubtitleCue = nil
                }
                
                // Check for Auto Next Episode trigger near the end (last 45 seconds of a series episode)
                if let _ = self.currentEpisode, self.duration > 60 {
                    let remaining = self.duration - sec
                    if remaining <= 45 && remaining > 0 && !self.showNextEpisodePrompt {
                        self.triggerNextEpisodeCountdown()
                    }
                }
                
                // Persist progress periodically (every 5 seconds)
                if Int(sec) % 5 == 0 && sec > 3 {
                    self.saveCurrentProgress()
                }
            }
        }
    }
    
    private func triggerNextEpisodeCountdown() {
        showNextEpisodePrompt = true
        nextEpisodeCountdown = 10
        nextEpisodeTimer?.cancel()
        nextEpisodeTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.nextEpisodeCountdown > 1 {
                    self.nextEpisodeCountdown -= 1
                } else {
                    self.playNextEpisode()
                }
            }
    }
    
    private func saveCurrentProgress() {
        guard let media = currentMedia else { return }
        let progress = PlaybackProgress(
            mediaId: media.id,
            title: media.title,
            posterURL: media.posterURL,
            backdropURL: media.backdropURL,
            seasonNumber: currentSeason?.number,
            episodeNumber: currentEpisode?.episodeNumber,
            episodeTitle: currentEpisode?.title,
            translationId: currentTranslation?.id,
            currentTimeSeconds: currentTime,
            durationSeconds: duration,
            updatedAt: Date(),
            contentType: media.contentType
        )
        
        Task {
            await LocalStorageManager.shared.saveProgress(progress)
            await ConvexSyncManager.shared.pushProgress(progress)
        }
    }
    
    // MARK: - Lockscreen & Remote Controls
    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }
        
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        
        center.skipForwardCommand.preferredIntervals = [10]
        center.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skip(seconds: 10) }
            return .success
        }
        
        center.skipBackwardCommand.preferredIntervals = [10]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skip(seconds: -10) }
            return .success
        }
        
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: positionEvent.positionTime) }
            return .success
        }
    }
    
    private func updateNowPlayingInfo() {
        guard let media = currentMedia else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: media.title,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(playbackRate) : 0.0
        ]
        
        if let season = currentSeason, let episode = currentEpisode {
            info[MPMediaItemPropertyArtist] = "S\(season.number) E\(episode.episodeNumber) • \(episode.title)"
        } else if let tr = currentTranslation {
            info[MPMediaItemPropertyArtist] = tr.title
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
