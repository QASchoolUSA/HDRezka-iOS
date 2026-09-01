import Foundation

public actor ConvexSyncManager {
    public static let shared = ConvexSyncManager()
    
    private var convexURL: URL?
    private var isSyncEnabled: Bool = false
    
    public init() {
        if let customStr = UserDefaults.standard.string(forKey: "hdrezka_convex_url"),
           let u = URL(string: customStr) {
            self.convexURL = u
            self.isSyncEnabled = true
        }
    }
    
    public func configure(convexDeploymentURL: String) {
        if let u = URL(string: convexDeploymentURL) {
            self.convexURL = u
            self.isSyncEnabled = true
            UserDefaults.standard.set(convexDeploymentURL, forKey: "hdrezka_convex_url")
        }
    }
    
    public func isConfigured() -> Bool {
        return isSyncEnabled && convexURL != nil
    }
    
    /// Syncs playback progress mutation to Convex
    public func pushProgress(_ progress: PlaybackProgress) async {
        guard let url = convexURL, isSyncEnabled else { return }
        
        let endpoint = url.appendingPathComponent("/api/mutation")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "path": "progress:saveProgress",
            "args": [
                "mediaId": progress.mediaId,
                "title": progress.title,
                "posterURL": progress.posterURL?.absoluteString ?? "",
                "season": progress.seasonNumber ?? 0,
                "episode": progress.episodeNumber ?? 0,
                "currentTime": progress.currentTimeSeconds,
                "duration": progress.durationSeconds,
                "translationId": progress.translationId ?? ""
            ]
        ]
        
        if let body = try? JSONSerialization.data(withJSONObject: payload) {
            request.httpBody = body
            _ = try? await URLSession.shared.data(for: request)
        }
    }
    
    /// Syncs watchlist change to Convex
    public func pushWatchlist(item: MediaItem, isAdded: Bool) async {
        guard let url = convexURL, isSyncEnabled else { return }
        
        let endpoint = url.appendingPathComponent("/api/mutation")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "path": isAdded ? "watchlist:addToWatchlist" : "watchlist:removeFromWatchlist",
            "args": [
                "mediaId": item.id,
                "title": item.title,
                "posterURL": item.posterURL?.absoluteString ?? "",
                "year": item.year ?? 0,
                "contentType": item.contentType.rawValue
            ]
        ]
        
        if let body = try? JSONSerialization.data(withJSONObject: payload) {
            request.httpBody = body
            _ = try? await URLSession.shared.data(for: request)
        }
    }
}
