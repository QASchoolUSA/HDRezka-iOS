import Foundation

public actor CloudflareClient {
    public static let shared = CloudflareClient()
    
    private var edgeBaseURL: URL?
    private var isEnabled: Bool = false
    
    public init() {
        if let saved = UserDefaults.standard.string(forKey: "hdrezka_edge_endpoint"),
           let u = URL(string: saved) {
            self.edgeBaseURL = u
            self.isEnabled = UserDefaults.standard.bool(forKey: "hdrezka_edge_enabled")
        }
    }
    
    public func configure(endpoint: String, enabled: Bool) {
        if let u = URL(string: endpoint) {
            self.edgeBaseURL = u
            self.isEnabled = enabled
            UserDefaults.standard.set(endpoint, forKey: "hdrezka_edge_endpoint")
            UserDefaults.standard.set(enabled, forKey: "hdrezka_edge_enabled")
        }
    }
    
    public func isConfigured() -> Bool {
        return isEnabled && edgeBaseURL != nil
    }
    
    public func fetchFeed(contentType: ContentType, page: Int) async throws -> [MediaItem]? {
        guard let base = edgeBaseURL, isEnabled else { return nil }
        guard let url = URL(string: "/api/feed?type=\(contentType.rawValue)&page=\(page)", relativeTo: base) else { return nil }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode([MediaItem].self, from: data)
    }
    
    public func fetchStreams(
        mediaId: String,
        translatorId: String,
        season: Int?,
        episode: Int?
    ) async throws -> StreamBundle? {
        guard let base = edgeBaseURL, isEnabled else { return nil }
        guard let url = URL(string: "/api/stream", relativeTo: base) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "id": mediaId,
            "translator_id": translatorId,
            "season": season as Any,
            "episode": episode as Any
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(StreamBundle.self, from: data)
    }
}
