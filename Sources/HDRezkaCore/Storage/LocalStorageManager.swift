import Foundation

public struct UserSettings: Codable, Sendable {
    public var defaultQuality: VideoQuality
    public var preferredTranslatorName: String?
    public var subtitleScale: Double
    public var subtitleBackgroundOpacity: Double
    public var autoPlayNextEpisode: Bool
    public var useCloudEdgeProxy: Bool
    public var customEdgeEndpoint: String?
    public var customMirrorURL: String?
    
    public init(
        defaultQuality: VideoQuality = .res1080p,
        preferredTranslatorName: String? = "HDRezka Studio",
        subtitleScale: Double = 1.0,
        subtitleBackgroundOpacity: Double = 0.5,
        autoPlayNextEpisode: Bool = true,
        useCloudEdgeProxy: Bool = false,
        customEdgeEndpoint: String? = nil,
        customMirrorURL: String? = nil
    ) {
        self.defaultQuality = defaultQuality
        self.preferredTranslatorName = preferredTranslatorName
        self.subtitleScale = subtitleScale
        self.subtitleBackgroundOpacity = subtitleBackgroundOpacity
        self.autoPlayNextEpisode = autoPlayNextEpisode
        self.useCloudEdgeProxy = useCloudEdgeProxy
        self.customEdgeEndpoint = customEdgeEndpoint
        self.customMirrorURL = customMirrorURL
    }
}

public actor LocalStorageManager {
    public static let shared = LocalStorageManager()
    
    private let progressKey = "hdrezka_playback_progress_map"
    private let watchlistKey = "hdrezka_watchlist_items"
    private let settingsKey = "hdrezka_user_settings"
    
    private var progressCache: [String: PlaybackProgress] = [:]
    private var watchlistCache: [String: MediaItem] = [:]
    private var settingsCache: UserSettings
    
    public init() {
        // Load Settings
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(UserSettings.self, from: data) {
            self.settingsCache = settings
        } else {
            self.settingsCache = UserSettings()
        }
        
        // Load Progress
        if let data = UserDefaults.standard.data(forKey: progressKey),
           let map = try? JSONDecoder().decode([String: PlaybackProgress].self, from: data) {
            self.progressCache = map
        }
        
        // Load Watchlist
        if let data = UserDefaults.standard.data(forKey: watchlistKey),
           let map = try? JSONDecoder().decode([String: MediaItem].self, from: data) {
            self.watchlistCache = map
        }
    }
    
    // MARK: - Playback Progress
    public func saveProgress(_ progress: PlaybackProgress) {
        progressCache[progress.mediaId] = progress
        persistProgress()
    }
    
    public func getProgress(for mediaId: String) -> PlaybackProgress? {
        return progressCache[mediaId]
    }
    
    public func getAllContinueWatching() -> [PlaybackProgress] {
        return progressCache.values
            .filter { !$0.isCompleted && $0.currentTimeSeconds > 10 }
            .sorted(by: { $0.updatedAt > $1.updatedAt })
    }
    
    public func getAllHistory() -> [PlaybackProgress] {
        return progressCache.values.sorted(by: { $0.updatedAt > $1.updatedAt })
    }
    
    public func removeProgress(for mediaId: String) {
        progressCache.removeValue(forKey: mediaId)
        persistProgress()
    }
    
    public func clearAllHistory() {
        progressCache.removeAll()
        persistProgress()
    }
    
    private func persistProgress() {
        if let data = try? JSONEncoder().encode(progressCache) {
            UserDefaults.standard.set(data, forKey: progressKey)
        }
    }
    
    // MARK: - Watchlist
    public func toggleWatchlist(_ item: MediaItem) -> Bool {
        let isSaved = watchlistCache[item.id] != nil
        if isSaved {
            watchlistCache.removeValue(forKey: item.id)
        } else {
            watchlistCache[item.id] = item
        }
        persistWatchlist()
        return !isSaved
    }
    
    public func isInWatchlist(_ itemId: String) -> Bool {
        return watchlistCache[itemId] != nil
    }
    
    public func getAllWatchlist() -> [MediaItem] {
        return Array(watchlistCache.values)
    }
    
    private func persistWatchlist() {
        if let data = try? JSONEncoder().encode(watchlistCache) {
            UserDefaults.standard.set(data, forKey: watchlistKey)
        }
    }
    
    // MARK: - Settings
    public func getSettings() -> UserSettings {
        return settingsCache
    }
    
    public func updateSettings(_ settings: UserSettings) {
        self.settingsCache = settings
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }
}
