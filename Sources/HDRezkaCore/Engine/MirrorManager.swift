import Foundation

public struct MirrorStatus: Identifiable, Sendable {
    public var id: String { url.absoluteString }
    public let url: URL
    public let latencyMs: Int?
    public let isAlive: Bool
    public let lastChecked: Date
    
    public init(url: URL, latencyMs: Int? = nil, isAlive: Bool = false, lastChecked: Date = Date()) {
        self.url = url
        self.latencyMs = latencyMs
        self.isAlive = isAlive
        self.lastChecked = lastChecked
    }
}

public actor MirrorManager {
    public static let shared = MirrorManager()
    
    public static let defaultMirrors: [String] = [
        "http://192.168.1.147:7890",
        "https://rezka.ag",
        "https://hdrezka.ag",
        "https://hdrezka.me",
        "https://hdrezka.cm",
        "https://hdrezka.ac",
        "https://rezka-ag.com"
    ]
    
    private var mirrors: [URL]
    private var activeMirror: URL
    private var mirrorStatuses: [String: MirrorStatus] = [:]
    
    private let customMirrorKey = "hdrezka_custom_mirror_url"
    private let activeMirrorKey = "hdrezka_active_mirror_url"
    
    public init() {
        var initialList: [URL] = []
        for mirrorStr in Self.defaultMirrors {
            if let u = URL(string: mirrorStr) {
                initialList.append(u)
            }
        }
        
        if let customStr = UserDefaults.standard.string(forKey: customMirrorKey),
           let customURL = URL(string: customStr) {
            if !initialList.contains(customURL) {
                initialList.insert(customURL, at: 0)
            }
        }
        
        self.mirrors = initialList
        
        if let savedActive = UserDefaults.standard.string(forKey: activeMirrorKey),
           let savedURL = URL(string: savedActive) {
            self.activeMirror = savedURL
        } else {
            self.activeMirror = initialList.first ?? URL(string: "https://rezka.ag")!
        }
    }
    
    public func getActiveMirror() -> URL {
        return activeMirror
    }
    
    public func setActiveMirror(_ url: URL) {
        self.activeMirror = url
        UserDefaults.standard.set(url.absoluteString, forKey: activeMirrorKey)
    }
    
    public func addCustomMirror(_ url: URL) {
        if !mirrors.contains(url) {
            mirrors.insert(url, at: 0)
        }
        UserDefaults.standard.set(url.absoluteString, forKey: customMirrorKey)
        setActiveMirror(url)
    }
    
    public func getAllMirrors() -> [URL] {
        return mirrors
    }
    
    public func getStatuses() -> [MirrorStatus] {
        return mirrors.map { url in
            mirrorStatuses[url.absoluteString] ?? MirrorStatus(url: url)
        }
    }
    
    /// Tests all mirrors concurrently and picks the fastest responsive one
    public func checkMirrorsHealth() async -> [MirrorStatus] {
        await withTaskGroup(of: MirrorStatus.self) { group in
            for mirror in self.mirrors {
                group.addTask {
                    await Self.pingMirror(mirror)
                }
            }
            
            var results: [MirrorStatus] = []
            for await status in group {
                self.mirrorStatuses[status.url.absoluteString] = status
                results.append(status)
            }
            
            // Auto-switch to lowest latency healthy mirror if active is dead
            if let currentStatus = self.mirrorStatuses[self.activeMirror.absoluteString],
               !currentStatus.isAlive {
                if let fastest = results.filter({ $0.isAlive }).min(by: { ($0.latencyMs ?? Int.max) < ($1.latencyMs ?? Int.max) }) {
                    self.activeMirror = fastest.url
                }
            }
            
            return results
        }
    }
    
    private static func pingMirror(_ url: URL) async -> MirrorStatus {
        let startTime = CFAbsoluteTimeGetCurrent()
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 4.0
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let elapsed = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            let isAlive = (response as? HTTPURLResponse)?.statusCode ?? 0 < 400
            return MirrorStatus(url: url, latencyMs: elapsed, isAlive: isAlive, lastChecked: Date())
        } catch {
            return MirrorStatus(url: url, latencyMs: nil, isAlive: false, lastChecked: Date())
        }
    }
}
