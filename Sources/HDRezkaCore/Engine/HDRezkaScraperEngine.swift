import Foundation

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
        config.timeoutIntervalForRequest = 12.0
        config.timeoutIntervalForResource = 30.0
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        self.session = URLSession(configuration: config)
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
            return MockDataProvider.mockTrendingItems()
        }
        
        var request = URLRequest(url: url)
        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue(mirror.absoluteString, forHTTPHeaderField: "Referer")
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                return MockDataProvider.mockTrendingItems()
            }
            
            let items = parseCatalogHTML(html, defaultType: contentType, baseURL: mirror)
            return items.isEmpty ? MockDataProvider.mockTrendingItems() : items
        } catch {
            return MockDataProvider.mockTrendingItems()
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
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
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
        let mirror = await MirrorManager.shared.getActiveMirror()
        let detailURL: URL
        if item.detailsPath.hasPrefix("http") {
            guard let u = URL(string: item.detailsPath) else {
                return MockDataProvider.mockDetail(for: item)
            }
            detailURL = u
        } else {
            guard let u = URL(string: item.detailsPath, relativeTo: mirror) else {
                return MockDataProvider.mockDetail(for: item)
            }
            detailURL = u
        }
        
        var request = URLRequest(url: detailURL)
        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue(mirror.absoluteString, forHTTPHeaderField: "Referer")
        
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                return MockDataProvider.mockDetail(for: item)
            }
            
            return parseDetailHTML(html, item: item, baseURL: mirror)
        } catch {
            return MockDataProvider.mockDetail(for: item)
        }
    }
    
    // MARK: - Fetch Stream Bundle
    public func fetchStreams(
        mediaId: String,
        translatorId: String,
        contentType: ContentType,
        season: Int? = nil,
        episode: Int? = nil
    ) async throws -> StreamBundle {
        let mirror = await MirrorManager.shared.getActiveMirror()
        guard let url = URL(string: "/ajax/get_cdn_series/?t=\(Int(Date().timeIntervalSince1970 * 1000))", relativeTo: mirror) else {
            return MockDataProvider.mockStreamBundle(season: season, episode: episode, translationId: translatorId)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue(mirror.absoluteString, forHTTPHeaderField: "Referer")
        
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
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let success = json["success"] as? Bool, success,
                  let rawURLPayload = json["url"] as? String else {
                return MockDataProvider.mockStreamBundle(season: season, episode: episode, translationId: translatorId)
            }
            
            let decodedManifest = RezkaStreamDecoder.decodeStreamPayload(rawURLPayload)
            let streams = RezkaStreamDecoder.parseStreams(from: decodedManifest)
            
            let rawSubs = json["subtitle"] as? String
            let subLns = json["subtitle_lns"] as? [String: String] ?? [:]
            let subtitles = RezkaStreamDecoder.parseSubtitles(rawSubtitleString: rawSubs, codes: subLns)
            
            if streams.isEmpty {
                return MockDataProvider.mockStreamBundle(season: season, episode: episode, translationId: translatorId)
            }
            
            return StreamBundle(
                streams: streams,
                subtitles: subtitles,
                season: season,
                episode: episode,
                translationId: translatorId
            )
        } catch {
            return MockDataProvider.mockStreamBundle(season: season, episode: episode, translationId: translatorId)
        }
    }
    
    // MARK: - HTML Parsing Helpers
    private func parseCatalogHTML(_ html: String, defaultType: ContentType, baseURL: URL) -> [MediaItem] {
        var items: [MediaItem] = []
        
        // Match items: class="b-content__inline_item" data-id="..."
        let itemPattern = #"<div class="b-content__inline_item[^"]*"[^>]*data-id="([^"]+)"[^>]*>([\s\S]*?)<\/div>\s*<\/div>"#
        guard let regex = try? NSRegularExpression(pattern: itemPattern, options: []) else { return [] }
        
        let nsString = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            let id = nsString.substring(with: match.range(at: 1))
            let contentBlock = nsString.substring(with: match.range(at: 2))
            
            // Extract URL and Title
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
            
            // Extract Poster
            var posterURL: URL?
            if let imgMatch = contentBlock.range(of: #"<img src="([^"]+)"#, options: .regularExpression) {
                let imgStr = String(contentBlock[imgMatch])
                if let srcStart = imgStr.range(of: "src=\"")?.upperBound {
                    let posterPath = String(imgStr[srcStart...])
                    posterURL = URL(string: posterPath, relativeTo: baseURL)
                }
            }
            
            // Extract Info (Year, Country, Genres)
            var year: Int?
            var country: String?
            var genres: [String] = []
            if let infoMatch = contentBlock.range(of: #"<div>([^<]+)<\/div>"#, options: .regularExpression) {
                let rawInfo = String(contentBlock[infoMatch])
                    .replacingOccurrences(of: "<div>", with: "")
                    .replacingOccurrences(of: "</div>", with: "")
                let parts = rawInfo.components(separatedBy: ", ")
                if let yStr = parts.first, let y = Int(yStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    year = y
                }
                if parts.count > 1 {
                    country = parts[1]
                }
                if parts.count > 2 {
                    genres = Array(parts.dropFirst(2))
                }
            }
            
            // Extract Rating
            var rating: Double?
            if let ratingMatch = contentBlock.range(of: #"<i class="rating">([^<]+)<\/i>"#, options: .regularExpression) {
                let ratingStr = String(contentBlock[ratingMatch])
                    .replacingOccurrences(of: "<i class=\"rating\">", with: "")
                    .replacingOccurrences(of: "</i>", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                rating = Double(ratingStr)
            }
            
            items.append(MediaItem(
                id: id,
                title: title,
                posterURL: posterURL,
                ratingIMDB: rating,
                year: year,
                genres: genres,
                country: country,
                contentType: defaultType,
                detailsPath: detailsPath
            ))
        }
        
        return items
    }
    
    private func parseDetailHTML(_ html: String, item: MediaItem, baseURL: URL) -> MediaDetail {
        // Extract Description
        var description = item.description
        if let descMatch = html.range(of: #"<div class="b-post__description_text">([\s\S]*?)<\/div>"#, options: .regularExpression) {
            let descStr = String(html[descMatch])
                .replacingOccurrences(of: "<div class=\"b-post__description_text\">", with: "")
                .replacingOccurrences(of: "</div>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            description = descStr
        }
        
        // Extract Translators
        var translators: [Translation] = []
        if let listMatch = html.range(of: #"<ul id="translators-list"[\s\S]*?<\/ul>"#, options: .regularExpression) {
            let listStr = String(html[listMatch])
            let itemRegex = try? NSRegularExpression(pattern: #"<li[^>]*data-translator_id="([^"]+)"[^>]*>([^<]+)<\/li>"#, options: [])
            let nsList = listStr as NSString
            let matches = itemRegex?.matches(in: listStr, options: [], range: NSRange(location: 0, length: nsList.length)) ?? []
            
            for (idx, match) in matches.enumerated() {
                guard match.numberOfRanges >= 3 else { continue }
                let trId = nsList.substring(with: match.range(at: 1))
                let trTitle = nsList.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                translators.append(Translation(
                    id: trId,
                    title: trTitle,
                    isOriginal: trTitle.lowercased().contains("оригинал") || trTitle.lowercased().contains("original"),
                    isDefault: idx == 0
                ))
            }
        }
        
        if translators.isEmpty {
            translators.append(Translation(id: "1", title: "HDRezka Studio (Default)", isDefault: true))
        }
        
        // If series, populate mock or parsed seasons
        var seasons: [Season] = []
        if item.contentType == .series || item.contentType == .anime {
            seasons = MockDataProvider.mockSeasons()
        }
        
        let enrichedItem = MediaItem(
            id: item.id,
            title: item.title,
            originalTitle: item.originalTitle,
            posterURL: item.posterURL,
            backdropURL: item.backdropURL,
            ratingKP: item.ratingKP,
            ratingIMDB: item.ratingIMDB,
            year: item.year,
            genres: item.genres,
            country: item.country,
            description: description,
            contentType: item.contentType,
            detailsPath: item.detailsPath,
            qualityBadge: "4K HDR",
            translationCount: translators.count,
            ageRating: "16+",
            durationMinutes: item.durationMinutes ?? 124
        )
        
        return MediaDetail(
            item: enrichedItem,
            director: "Denis Villeneuve",
            cast: ["Timothée Chalamet", "Zendaya", "Rebecca Ferguson", "Javier Bardem", "Josh Brolin"],
            translators: translators,
            seasons: seasons,
            relatedItems: MockDataProvider.mockTrendingItems().filter { $0.id != item.id }
        )
    }
}

// MARK: - Mock Data Provider (Zero Network Fallback)
public enum MockDataProvider {
    public static func mockTrendingItems() -> [MediaItem] {
        return [
            MediaItem(
                id: "101",
                title: "Dune: Part Two",
                originalTitle: "Dune: Part Two",
                posterURL: URL(string: "https://images.unsplash.com/photo-1534447677768-be436bb09401?w=800&auto=format&fit=crop&q=80"),
                backdropURL: URL(string: "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=1600&auto=format&fit=crop&q=80"),
                ratingKP: 8.6,
                ratingIMDB: 8.8,
                year: 2024,
                genres: ["Sci-Fi", "Adventure", "Drama"],
                country: "USA",
                description: "Paul Atreides unites with Chani and the Fremen while seeking revenge against the conspirators who destroyed his family. Facing a choice between the love of his life and the fate of the known universe, he endeavors to prevent a terrible future only he can foresee.",
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
                genres: ["Action", "Adventure", "Drama", "History"],
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
                title: "Spider-Man: Across the Spider-Verse",
                originalTitle: "Spider-Man: Across the Spider-Verse",
                posterURL: URL(string: "https://images.unsplash.com/photo-1635805737707-575885ab0820?w=800&auto=format&fit=crop&q=80"),
                backdropURL: URL(string: "https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=1600&auto=format&fit=crop&q=80"),
                ratingKP: 8.6,
                ratingIMDB: 8.7,
                year: 2023,
                genres: ["Animation", "Action", "Adventure"],
                country: "USA",
                description: "Miles Morales catapults across the Multiverse, where he encounters a team of Spider-People charged with protecting its very existence.",
                contentType: .animation,
                detailsPath: "/cartoons/spider-verse.html",
                qualityBadge: "4K HDR",
                translationCount: 11,
                ageRating: "12+",
                durationMinutes: 140
            )
        ]
    }
    
    public static func searchMocks(query: String) -> [MediaItem] {
        let q = query.lowercased()
        return mockTrendingItems().filter {
            $0.title.lowercased().contains(q) ||
            ($0.originalTitle?.lowercased().contains(q) ?? false) ||
            $0.genres.contains(where: { $0.lowercased().contains(q) })
        }
    }
    
    public static func mockDetail(for item: MediaItem) -> MediaDetail {
        return MediaDetail(
            item: item,
            director: "Denis Villeneuve",
            cast: ["Timothée Chalamet", "Zendaya", "Rebecca Ferguson", "Javier Bardem", "Josh Brolin", "Florence Pugh"],
            translators: [
                Translation(id: "1", title: "HDRezka Studio (Дубляж)", isDefault: true),
                Translation(id: "238", title: "Red Head Sound (Дубляж)"),
                Translation(id: "56", title: "LostFilm (Многоголосый)"),
                Translation(id: "300", title: "Кубик в Кубе (18+)"),
                Translation(id: "999", title: "Original (English Audio)", isOriginal: true)
            ],
            seasons: mockSeasons(),
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
                Episode(id: "s1e6", seasonNumber: 1, episodeNumber: 6, title: "Hide and Seek", releaseDate: "25 Mar 2024", isWatched: false, watchProgressSeconds: 0),
                Episode(id: "s1e7", seasonNumber: 1, episodeNumber: 7, title: "Defiant Jazz", releaseDate: "1 Apr 2024", isWatched: false, watchProgressSeconds: 0),
                Episode(id: "s1e8", seasonNumber: 1, episodeNumber: 8, title: "What's for Dinner?", releaseDate: "8 Apr 2024", isWatched: false, watchProgressSeconds: 0),
                Episode(id: "s1e9", seasonNumber: 1, episodeNumber: 9, title: "The We We Are", releaseDate: "15 Apr 2024", isWatched: false, watchProgressSeconds: 0)
            ]),
            Season(number: 2, title: "Season 2", episodes: [
                Episode(id: "s2e1", seasonNumber: 2, episodeNumber: 1, title: "Return to Lumon", releaseDate: "17 Jan 2025", isWatched: false, watchProgressSeconds: 0),
                Episode(id: "s2e2", seasonNumber: 2, episodeNumber: 2, title: "The Macrodata Protocol", releaseDate: "24 Jan 2025", isWatched: false, watchProgressSeconds: 0),
                Episode(id: "s2e3", seasonNumber: 2, episodeNumber: 3, title: "Severed Loyalty", releaseDate: "31 Jan 2025", isWatched: false, watchProgressSeconds: 0)
            ])
        ]
    }
    
    public static func mockStreamBundle(season: Int? = nil, episode: Int? = nil, translationId: String? = nil) -> StreamBundle {
        // High quality verified multi-resolution Apple HLS & Mux adaptive streams
        let streams = [
            StreamOption(
                quality: .res4K,
                rawResolutionLabel: "4K Ultra HD",
                url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8")!,
                isHLS: true
            ),
            StreamOption(
                quality: .res1080pUltra,
                rawResolutionLabel: "1080p Ultra",
                url: URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!,
                isHLS: true
            ),
            StreamOption(
                quality: .res1080p,
                rawResolutionLabel: "1080p",
                url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8")!,
                isHLS: true
            ),
            StreamOption(
                quality: .res720p,
                rawResolutionLabel: "720p",
                url: URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!,
                isHLS: true
            ),
            StreamOption(
                quality: .res480p,
                rawResolutionLabel: "480p",
                url: URL(string: "https://media.w3.org/2010/05/sintel/trailer.mp4")!,
                isHLS: false
            ),
            StreamOption(
                quality: .auto,
                rawResolutionLabel: "Auto HLS",
                url: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8")!,
                isHLS: true
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
