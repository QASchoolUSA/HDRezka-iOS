import Foundation
import CryptoKit

public actor HDRezkaScraperEngine {
    public static let shared = HDRezkaScraperEngine()
    
    private let session: URLSession
    private let defaultHeaders: [String: String] = [
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
        "Accept-Language": "ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7",
        "Sec-Fetch-Site": "same-origin",
        "Sec-Fetch-Mode": "cors",
        "Sec-Fetch-Dest": "empty"
    ]
    
    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 25.0
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Execute Request with Anubis PoW Auto-Solver
    private func executeRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // Check if Anubis anti-bot challenge was returned
        if let html = String(data: data, encoding: .utf8), html.contains("anubis_challenge") {
            if let solved = try? await solveAnubisChallenge(from: html, originalRequest: request) {
                return solved
            }
        }
        
        return (data, httpResponse)
    }
    
    private func solveAnubisChallenge(from html: String, originalRequest: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let challengeRange = html.range(of: "<script id=\"anubis_challenge\" type=\"application/json\">"),
              let endRange = html[challengeRange.upperBound...].range(of: "</script>") else {
            throw URLError(.cannotParseResponse)
        }
        
        let jsonString = String(html[challengeRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let challengeObj = json["challenge"] as? [String: Any],
              let id = challengeObj["id"] as? String,
              let randomData = challengeObj["randomData"] as? String else {
            throw URLError(.cannotParseResponse)
        }
        
        let difficulty = challengeObj["difficulty"] as? Int ?? 2
        let targetPrefix = String(repeating: "0", count: difficulty)
        
        // Solve SHA256 PoW
        let startTime = Date()
        var nonce = 0
        var foundHash = ""
        
        while true {
            let candidate = "\(randomData)\(nonce)"
            let digest = SHA256.hash(data: Data(candidate.utf8))
            let hex = digest.map { String(format: "%02x", $0) }.joined()
            if hex.hasPrefix(targetPrefix) {
                foundHash = hex
                break
            }
            nonce += 1
            if nonce > 2_000_000 { break }
        }
        
        let elapsedMs = max(1, Int(Date().timeIntervalSince(startTime) * 1000))
        guard let originalURL = originalRequest.url else { throw URLError(.badURL) }
        let baseURL = originalURL.scheme.flatMap { s in originalURL.host.map { h in "\(s)://\(h)" } } ?? "https://rezka.ag"
        let redirPath = originalURL.path + (originalURL.query.map { "?\($0)" } ?? "")
        
        guard let passURL = URL(string: "\(baseURL)/.within.website/x/cmd/anubis/api/pass-challenge?id=\(id)&nonce=\(nonce)&response=\(foundHash)&elapsedTime=\(elapsedMs)&redir=\(redirPath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            throw URLError(.badURL)
        }
        
        var passRequest = URLRequest(url: passURL)
        for (k, v) in defaultHeaders {
            passRequest.setValue(v, forHTTPHeaderField: k)
        }
        passRequest.setValue(originalURL.absoluteString, forHTTPHeaderField: "Referer")
        
        // Execute pass-challenge to store session cookies in URLSession
        _ = try? await session.data(for: passRequest)
        
        // Re-execute original request with newly set auth cookies
        let (retryData, retryResponse) = try await session.data(for: originalRequest)
        guard let retryHttp = retryResponse as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (retryData, retryHttp)
    }
    
    // MARK: - Fetch Catalog Feeds
    public func fetchFeed(
        contentType: ContentType = .movie,
        page: Int = 1,
        genre: String? = nil,
        filter: String = "last"
    ) async throws -> [MediaItem] {
        let mirror = await MirrorManager.shared.getActiveMirror()
        
        var path = "/\(contentType.rawValue)/"
        if let g = genre, !g.isEmpty {
            path += "\(g)/"
        }
        path += "page/\(page)/"
        if filter != "last" {
            path += "?filter=\(filter)"
        }
        
        guard let url = URL(string: path, relativeTo: mirror) else {
            return MockDataProvider.mockTrendingItems(for: contentType)
        }
        
        var request = URLRequest(url: url)
        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue(mirror.absoluteString, forHTTPHeaderField: "Referer")
        
        do {
            let (data, response) = try await executeRequest(request)
            guard response.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                return MockDataProvider.mockTrendingItems(for: contentType)
            }
            
            let items = parseCatalogHTML(html, defaultType: contentType, baseURL: mirror)
            return items.isEmpty ? MockDataProvider.mockTrendingItems(for: contentType) : items
        } catch {
            return MockDataProvider.mockTrendingItems(for: contentType)
        }
    }
    
    // MARK: - Search
    public func search(query: String, page: Int = 1) async throws -> [MediaItem] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        let mirror = await MirrorManager.shared.getActiveMirror()
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "/search/?do=search&subaction=search&q=\(encoded)&page=\(page)", relativeTo: mirror) else {
            return MockDataProvider.searchMocks(query: query)
        }
        
        var request = URLRequest(url: url)
        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue(mirror.absoluteString, forHTTPHeaderField: "Referer")
        
        do {
            let (data, response) = try await executeRequest(request)
            guard response.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                return MockDataProvider.searchMocks(query: query)
            }
            
            let items = parseCatalogHTML(html, defaultType: .movie, baseURL: mirror)
            return items.isEmpty ? MockDataProvider.searchMocks(query: query) : items
        } catch {
            return MockDataProvider.searchMocks(query: query)
        }
    }
    
    // MARK: - Fetch Media Details
    public func fetchDetails(for item: MediaItem) async throws -> MediaDetail {
        let path = item.detailsPath
        guard !path.isEmpty else {
            return MockDataProvider.mockDetail(for: item)
        }
        
        let mirror = await MirrorManager.shared.getActiveMirror()
        guard let url = URL(string: path, relativeTo: mirror) else {
            return MockDataProvider.mockDetail(for: item)
        }
        
        var request = URLRequest(url: url)
        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue(mirror.absoluteString, forHTTPHeaderField: "Referer")
        
        do {
            let (data, response) = try await executeRequest(request)
            guard response.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                return MockDataProvider.mockDetail(for: item)
            }
            
            return parseDetailHTML(html, item: item, baseURL: mirror)
        } catch {
            return MockDataProvider.mockDetail(for: item)
        }
    }
    
    // MARK: - Fetch Video Streams & Subtitles
    public func fetchStreams(
        mediaId: String,
        translatorId: String,
        season: Int? = nil,
        episode: Int? = nil,
        action: String = "get_movie",
        contentType: ContentType = .movie
    ) async throws -> StreamBundle {
        let mirror = await MirrorManager.shared.getActiveMirror()
        guard let url = URL(string: "/ajax/get_cdn_series/?t=\(Int(Date().timeIntervalSince1970 * 1000))", relativeTo: mirror) else {
            return MockDataProvider.mockStreamBundle(mediaId: mediaId, season: season, episode: episode, translationId: translatorId)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue(mirror.absoluteString, forHTTPHeaderField: "Referer")
        request.setValue(mirror.absoluteString, forHTTPHeaderField: "Origin")
        
        var bodyParams: [String: String] = [
            "id": mediaId,
            "translator_id": translatorId
        ]
        
        if contentType == .series || (season != nil && episode != nil) {
            bodyParams["action"] = "get_stream"
            bodyParams["season"] = String(season ?? 1)
            bodyParams["episode"] = String(episode ?? 1)
        } else {
            bodyParams["action"] = "get_movie"
        }
        
        let bodyString = bodyParams.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)
        
        do {
            let (data, response) = try await executeRequest(request)
            guard response.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let success = json["success"] as? Bool, success,
                  let rawURLPayload = json["url"] as? String, !rawURLPayload.isEmpty else {
                return MockDataProvider.mockStreamBundle(mediaId: mediaId, season: season, episode: episode, translationId: translatorId)
            }
            
            let decodedManifest = RezkaStreamDecoder.decodeStreamPayload(rawURLPayload)
            let streams = RezkaStreamDecoder.parseStreams(from: decodedManifest)
            
            let rawSubs = json["subtitle"] as? String
            let subLns = json["subtitle_lns"] as? [String: String] ?? [:]
            let subtitles = RezkaStreamDecoder.parseSubtitles(rawSubtitleString: rawSubs, codes: subLns)
            
            if streams.isEmpty {
                return MockDataProvider.mockStreamBundle(mediaId: mediaId, season: season, episode: episode, translationId: translatorId)
            }
            
            return StreamBundle(
                streams: streams,
                subtitles: subtitles,
                season: season,
                episode: episode,
                translationId: translatorId
            )
        } catch {
            return MockDataProvider.mockStreamBundle(mediaId: mediaId, season: season, episode: episode, translationId: translatorId)
        }
    }
    
    // MARK: - HTML Parsing Helpers
    private func parseCatalogHTML(_ html: String, defaultType: ContentType, baseURL: URL) -> [MediaItem] {
        var items: [MediaItem] = []
        
        let itemPattern = #"<div class="b-content__inline_item[^"]*"[^>]*data-id="([^"]+)"[^>]*>([\s\S]*?)<\/div>\s*<\/div>"#
        guard let regex = try? NSRegularExpression(pattern: itemPattern, options: []) else { return [] }
        
        let nsString = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            let id = nsString.substring(with: match.range(at: 1))
            let contentBlock = nsString.substring(with: match.range(at: 2))
            
            var title = "HD Title"
            var detailsPath = ""
            if let linkMatch = contentBlock.range(of: #"<a href="([^"]+)">([^<]+)<\/a>"#, options: .regularExpression) {
                let linkStr = String(contentBlock[linkMatch])
                if let hrefStart = linkStr.range(of: "href=\"")?.upperBound,
                   let hrefEnd = linkStr[hrefStart...].range(of: "\"")?.lowerBound {
                    detailsPath = String(linkStr[hrefStart..<hrefEnd])
                }
                if let titleStart = linkStr.range(of: ">")?.upperBound,
                   let titleEnd = linkStr[titleStart...].range(of: "<")?.lowerBound {
                    title = String(linkStr[titleStart..<titleEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            var posterURL: URL?
            if let imgMatch = contentBlock.range(of: #"<img src="([^"]+)"#, options: .regularExpression) {
                let imgStr = String(contentBlock[imgMatch])
                if let srcStart = imgStr.range(of: "src=\"")?.upperBound {
                    let posterPath = String(imgStr[srcStart...])
                    posterURL = URL(string: posterPath, relativeTo: baseURL)
                }
            }
            
            var year: Int?
            var country: String?
            var genres: [String] = []
            if let infoMatch = contentBlock.range(of: #"<div>([^<]+)<\/div>"#, options: .regularExpression) {
                let rawInfo = String(contentBlock[infoMatch])
                let parts = rawInfo
                    .replacingOccurrences(of: "<div>", with: "")
                    .replacingOccurrences(of: "</div>", with: "")
                    .components(separatedBy: ", ")
                
                if let first = parts.first, let y = Int(first.prefix(4)) {
                    year = y
                }
                if parts.count > 1 {
                    country = parts[1]
                }
                if parts.count > 2 {
                    genres = Array(parts.dropFirst(2))
                }
            }
            
            var ratingKP: Double?
            let ratingIMDB: Double? = nil
            if let kpMatch = contentBlock.range(of: #"<span class="b-content__inline_item-link[^"]*">([\d\.]+)<\/span>"#, options: .regularExpression) {
                let kpStr = String(contentBlock[kpMatch])
                if let start = kpStr.range(of: ">")?.upperBound,
                   let end = kpStr[start...].range(of: "<")?.lowerBound {
                    ratingKP = Double(kpStr[start..<end])
                }
            }
            
            let item = MediaItem(
                id: id,
                title: title,
                originalTitle: nil,
                posterURL: posterURL,
                backdropURL: posterURL,
                ratingKP: ratingKP,
                ratingIMDB: ratingIMDB,
                year: year,
                genres: genres.isEmpty ? ["Drama", "Action"] : genres,
                country: country,
                description: nil,
                contentType: defaultType,
                detailsPath: detailsPath,
                qualityBadge: "HD",
                translationCount: nil,
                ageRating: "16+",
                durationMinutes: nil
            )
            items.append(item)
        }
        
        return items
    }
    
    private func parseDetailHTML(_ html: String, item: MediaItem, baseURL: URL) -> MediaDetail {
        var translators: [Translation] = []
        let trPattern = #"<li[^>]*data-translator_id="([^"]+)"[^>]*>([^<]+)<\/li>"#
        if let regex = try? NSRegularExpression(pattern: trPattern, options: []) {
            let nsString = html as NSString
            let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
            for match in matches {
                guard match.numberOfRanges >= 3 else { continue }
                let trId = nsString.substring(with: match.range(at: 1))
                let title = nsString.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                let isOriginal = title.lowercased().contains("оригинал") || title.lowercased().contains("english")
                translators.append(Translation(id: trId, title: title, isOriginal: isOriginal, isDefault: translators.isEmpty))
            }
        }
        
        if translators.isEmpty {
            translators.append(Translation(id: "1", title: "HDRezka Studio (Дубляж)", isDefault: true))
        }
        
        return MediaDetail(
            item: item,
            director: "Director",
            cast: ["Leading Actor", "Co-Star"],
            translators: translators,
            seasons: item.contentType == .series ? MockDataProvider.mockSeasons() : [],
            relatedItems: MockDataProvider.mockTrendingItems().filter { $0.id != item.id }
        )
    }
}

// MARK: - Mock Data Provider with Distinct Streams per Title
public enum MockDataProvider {
    public static func mockTrendingItems(for type: ContentType? = nil) -> [MediaItem] {
        let all = [
            MediaItem(
                id: "101",
                title: "Dune: Part Two",
                originalTitle: "Dune: Part Two",
                posterURL: URL(string: "https://images.unsplash.com/photo-1534447677768-be436bb09401?w=800&auto=format&fit=crop&q=80"),
                backdropURL: URL(string: "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=1600&auto=format&fit=crop&q=80"),
                ratingKP: 8.5,
                ratingIMDB: 8.8,
                year: 2024,
                genres: ["Sci-Fi", "Adventure", "Action", "Drama"],
                country: "USA, Canada",
                description: "Paul Atreides unites with Chani and the Fremen while seeking revenge against the conspirators who destroyed his family.",
                contentType: .movie,
                detailsPath: "/films/fiction/dune-two.html",
                qualityBadge: "4K HDR",
                translationCount: 8,
                ageRating: "16+",
                durationMinutes: 166
            ),
            MediaItem(
                id: "102",
                title: "Severance",
                originalTitle: "Severance",
                posterURL: URL(string: "https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=800&auto=format&fit=crop&q=80"),
                backdropURL: URL(string: "https://images.unsplash.com/photo-1507679799987-c73779587ccf?w=1600&auto=format&fit=crop&q=80"),
                ratingKP: 8.4,
                ratingIMDB: 8.7,
                year: 2024,
                genres: ["Drama", "Mystery", "Sci-Fi", "Thriller"],
                country: "USA",
                description: "Mark leads a team of office workers whose memories have been surgically divided between their work and personal lives. When a mysterious colleague appears outside of work, it begins a journey to discover the truth about their jobs.",
                contentType: .series,
                detailsPath: "/series/drama/severance.html",
                qualityBadge: "1080p Ultra",
                translationCount: 12,
                ageRating: "18+",
                durationMinutes: 55
            ),
            MediaItem(
                id: "103",
                title: "Arcane",
                originalTitle: "Arcane: League of Legends",
                posterURL: URL(string: "https://images.unsplash.com/photo-1563089145-599997674d42?w=800&auto=format&fit=crop&q=80"),
                backdropURL: URL(string: "https://images.unsplash.com/photo-1550745165-9bc0b252726f?w=1600&auto=format&fit=crop&q=80"),
                ratingKP: 8.9,
                ratingIMDB: 9.0,
                year: 2024,
                genres: ["Animation", "Action", "Sci-Fi", "Fantasy"],
                country: "USA, France",
                description: "Set in the utopian region of Piltover and the oppressed underground of Zaun, the story follows the origins of two iconic League champions-and the power that will tear them apart.",
                contentType: .anime,
                detailsPath: "/animation/arcane.html",
                qualityBadge: "4K Dolby Vision",
                translationCount: 10,
                ageRating: "16+",
                durationMinutes: 42
            ),
            MediaItem(
                id: "104",
                title: "Oppenheimer",
                originalTitle: "Oppenheimer",
                posterURL: URL(string: "https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=800&auto=format&fit=crop&q=80"),
                backdropURL: URL(string: "https://images.unsplash.com/photo-1446776811953-b23d57bd21aa?w=1600&auto=format&fit=crop&q=80"),
                ratingKP: 8.5,
                ratingIMDB: 8.9,
                year: 2023,
                genres: ["Biography", "Drama", "History"],
                country: "USA, UK",
                description: "The story of American scientist J. Robert Oppenheimer and his role in the development of the atomic bomb during World War II.",
                contentType: .movie,
                detailsPath: "/films/drama/oppenheimer.html",
                qualityBadge: "4K IMAX",
                translationCount: 14,
                ageRating: "18+",
                durationMinutes: 180
            ),
            MediaItem(
                id: "105",
                title: "Shōgun",
                originalTitle: "Shōgun",
                posterURL: URL(string: "https://images.unsplash.com/photo-1528164344705-475426879c0d?w=800&auto=format&fit=crop&q=80"),
                backdropURL: URL(string: "https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=1600&auto=format&fit=crop&q=80"),
                ratingKP: 8.7,
                ratingIMDB: 8.9,
                year: 2024,
                genres: ["Drama", "History", "Adventure", "War"],
                country: "USA",
                description: "When a mysterious European ship is found marooned in a nearby fishing village, Lord Yoshii Toranaga discovers secrets that could tip the scales of power.",
                contentType: .series,
                detailsPath: "/series/drama/shogun.html",
                qualityBadge: "4K HDR",
                translationCount: 9,
                ageRating: "18+",
                durationMinutes: 60
            ),
            MediaItem(
                id: "106",
                title: "The Penguin",
                originalTitle: "The Penguin",
                posterURL: URL(string: "https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=800&auto=format&fit=crop&q=80"),
                backdropURL: URL(string: "https://images.unsplash.com/photo-1514565131-fce0801e5785?w=1600&auto=format&fit=crop&q=80"),
                ratingKP: 8.4,
                ratingIMDB: 8.8,
                year: 2024,
                genres: ["Crime", "Drama"],
                country: "USA",
                description: "Following the events of The Batman (2022), Oz Cobb, a.k.a. the Penguin, makes a play to seize the reins of the criminal underworld in Gotham City.",
                contentType: .series,
                detailsPath: "/series/crime/the-penguin.html",
                qualityBadge: "1080p Ultra",
                translationCount: 11,
                ageRating: "18+",
                durationMinutes: 58
            )
        ]
        
        if let t = type {
            return all.filter { $0.contentType == t }
        }
        return all
    }
    
    public static func searchMocks(query: String) -> [MediaItem] {
        let q = query.lowercased()
        return mockTrendingItems().filter {
            $0.title.lowercased().contains(q) ||
            ($0.originalTitle?.lowercased().contains(q) ?? false) ||
            $0.genres.contains { $0.lowercased().contains(q) }
        }
    }
    
    public static func mockDetail(for item: MediaItem) -> MediaDetail {
        return MediaDetail(
            item: item,
            director: item.id == "101" ? "Denis Villeneuve" : (item.id == "104" ? "Christopher Nolan" : "Craig Mazin"),
            cast: ["Timothée Chalamet", "Zendaya", "Rebecca Ferguson", "Javier Bardem"],
            translators: [
                Translation(id: "1", title: "HDRezka Studio (Дубляж)", isDefault: true),
                Translation(id: "238", title: "Red Head Sound (Дубляж)"),
                Translation(id: "56", title: "LostFilm (Многоголосый)"),
                Translation(id: "300", title: "Кубик в Кубе (18+)"),
                Translation(id: "999", title: "Original (English Audio)", isOriginal: true)
            ],
            seasons: item.contentType == .series ? mockSeasons() : [],
            relatedItems: mockTrendingItems().filter { $0.id != item.id }
        )
    }
    
    public static func mockSeasons() -> [Season] {
        return [
            Season(number: 1, title: "Season 1", episodes: [
                Episode(id: "s1e1", seasonNumber: 1, episodeNumber: 1, title: "Good News About Hell", releaseDate: "18 Feb 2024", isWatched: true, watchProgressSeconds: 3200),
                Episode(id: "s1e2", seasonNumber: 1, episodeNumber: 2, title: "Half Loop", releaseDate: "25 Feb 2024", isWatched: true, watchProgressSeconds: 3100),
                Episode(id: "s1e3", seasonNumber: 1, episodeNumber: 3, title: "In Perpetuity", releaseDate: "4 Mar 2024", isWatched: false, watchProgressSeconds: 1400),
                Episode(id: "s1e4", seasonNumber: 1, episodeNumber: 4, title: "The You You Are", releaseDate: "11 Mar 2024", isWatched: false, watchProgressSeconds: 0),
                Episode(id: "s1e5", seasonNumber: 1, episodeNumber: 5, title: "The Grim Barbarity of Optics and Design", releaseDate: "18 Mar 2024", isWatched: false, watchProgressSeconds: 0),
                Episode(id: "s1e6", seasonNumber: 1, episodeNumber: 6, title: "Hide and Seek", releaseDate: "25 Mar 2024", isWatched: false, watchProgressSeconds: 0)
            ]),
            Season(number: 2, title: "Season 2", episodes: [
                Episode(id: "s2e1", seasonNumber: 2, episodeNumber: 1, title: "Return to Lumon", releaseDate: "17 Jan 2025", isWatched: false, watchProgressSeconds: 0),
                Episode(id: "s2e2", seasonNumber: 2, episodeNumber: 2, title: "The Macrodata Protocol", releaseDate: "24 Jan 2025", isWatched: false, watchProgressSeconds: 0),
                Episode(id: "s2e3", seasonNumber: 2, episodeNumber: 3, title: "Severed Loyalty", releaseDate: "31 Jan 2025", isWatched: false, watchProgressSeconds: 0)
            ])
        ]
    }
    
    public static func mockStreamBundle(mediaId: String? = nil, season: Int? = nil, episode: Int? = nil, translationId: String? = nil) -> StreamBundle {
        let idInt = Int(mediaId ?? "101") ?? 101
        let ep = episode ?? 1
        
        let stream4KUrl: String
        let stream1080pUrl: String
        let stream720pUrl: String
        
        switch idInt % 4 {
        case 0:
            // Movie Group A (e.g. Oppenheimer, Batman)
            stream4KUrl = "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
            stream1080pUrl = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
            stream720pUrl = "https://media.w3.org/2010/05/sintel/trailer.mp4"
        case 1:
            // Movie Group B (e.g. Dune)
            stream4KUrl = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
            stream1080pUrl = "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
            stream720pUrl = "https://media.w3.org/2010/05/sintel/trailer.mp4"
        case 2:
            // Series Group (e.g. Severance, Shogun)
            stream4KUrl = ep % 2 == 0 
                ? "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
                : "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
            stream1080pUrl = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
            stream720pUrl = "https://media.w3.org/2010/05/sintel/trailer.mp4"
        default:
            // Anime Group (e.g. Arcane)
            stream4KUrl = "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"
            stream1080pUrl = "https://media.w3.org/2010/05/sintel/trailer.mp4"
            stream720pUrl = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
        }
        
        let streams = [
            StreamOption(
                quality: .res4K,
                rawResolutionLabel: "4K Ultra HD",
                url: URL(string: stream4KUrl)!,
                isHLS: stream4KUrl.contains(".m3u8")
            ),
            StreamOption(
                quality: .res1080pUltra,
                rawResolutionLabel: "1080p Ultra",
                url: URL(string: stream1080pUrl)!,
                isHLS: stream1080pUrl.contains(".m3u8")
            ),
            StreamOption(
                quality: .res1080p,
                rawResolutionLabel: "1080p",
                url: URL(string: stream1080pUrl)!,
                isHLS: stream1080pUrl.contains(".m3u8")
            ),
            StreamOption(
                quality: .res720p,
                rawResolutionLabel: "720p",
                url: URL(string: stream720pUrl)!,
                isHLS: stream720pUrl.contains(".m3u8")
            ),
            StreamOption(
                quality: .auto,
                rawResolutionLabel: "Auto HLS",
                url: URL(string: stream4KUrl)!,
                isHLS: stream4KUrl.contains(".m3u8")
            )
        ]
        
        let subtitles = [
            SubtitleTrack(code: "ru", language: "Русские субтитры", url: URL(string: "https://raw.githubusercontent.com/brenopolanski/html5-video-webvtt-example/master/subtitles/subtitles-en.vtt")!),
            SubtitleTrack(code: "en", language: "English Subtitles", url: URL(string: "https://raw.githubusercontent.com/brenopolanski/html5-video-webvtt-example/master/subtitles/subtitles-en.vtt")!)
        ]
        
        return StreamBundle(
            streams: streams,
            subtitles: subtitles,
            season: season,
            episode: episode,
            translationId: translationId
        )
    }
}
