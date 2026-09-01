import Foundation

// MARK: - Content Type
public enum ContentType: String, Codable, CaseIterable, Identifiable, Sendable {
    case movie = "movies"
    case series = "series"
    case animation = "cartoons"
    case anime = "animation"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .movie: return "Movies"
        case .series: return "TV Shows"
        case .animation: return "Cartoons"
        case .anime: return "Anime"
        }
    }
    
    public var systemIcon: String {
        switch self {
        case .movie: return "film"
        case .series: return "tv"
        case .animation: return "sparkles.tv"
        case .anime: return "wand.and.stars"
        }
    }
}

// MARK: - Media Item
public struct MediaItem: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let originalTitle: String?
    public let posterURL: URL?
    public let backdropURL: URL?
    public let ratingKP: Double?
    public let ratingIMDB: Double?
    public let year: Int?
    public let genres: [String]
    public let country: String?
    public let description: String?
    public let contentType: ContentType
    public let detailsPath: String
    public let qualityBadge: String?
    public let translationCount: Int?
    public let ageRating: String?
    public let durationMinutes: Int?
    
    public init(
        id: String,
        title: String,
        originalTitle: String? = nil,
        posterURL: URL? = nil,
        backdropURL: URL? = nil,
        ratingKP: Double? = nil,
        ratingIMDB: Double? = nil,
        year: Int? = nil,
        genres: [String] = [],
        country: String? = nil,
        description: String? = nil,
        contentType: ContentType = .movie,
        detailsPath: String = "",
        qualityBadge: String? = nil,
        translationCount: Int? = nil,
        ageRating: String? = nil,
        durationMinutes: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.originalTitle = originalTitle
        self.posterURL = posterURL
        self.backdropURL = backdropURL
        self.ratingKP = ratingKP
        self.ratingIMDB = ratingIMDB
        self.year = year
        self.genres = genres
        self.country = country
        self.description = description
        self.contentType = contentType
        self.detailsPath = detailsPath
        self.qualityBadge = qualityBadge
        self.translationCount = translationCount
        self.ageRating = ageRating
        self.durationMinutes = durationMinutes
    }
    
    public var formattedRating: String {
        if let imdb = ratingIMDB, imdb > 0 {
            return String(format: "IMDb %.1f", imdb)
        } else if let kp = ratingKP, kp > 0 {
            return String(format: "KP %.1f", kp)
        }
        return "HD"
    }
    
    public var primaryRatingValue: Double {
        ratingIMDB ?? ratingKP ?? 7.5
    }
    
    public var subtitleLine: String {
        var parts: [String] = []
        if let year = year { parts.append(String(year)) }
        if let country = country, !country.isEmpty { parts.append(country) }
        if let genre = genres.first { parts.append(genre) }
        return parts.joined(separator: " • ")
    }
}

// MARK: - Translation Voice-Over Option
public struct Translation: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let isOriginal: Bool
    public let isDefault: Bool
    
    public init(id: String, title: String, isOriginal: Bool = false, isDefault: Bool = false) {
        self.id = id
        self.title = title
        self.isOriginal = isOriginal
        self.isDefault = isDefault
    }
}

// MARK: - Season & Episode
public struct Episode: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let seasonNumber: Int
    public let episodeNumber: Int
    public let title: String
    public let releaseDate: String?
    public var isWatched: Bool
    public var watchProgressSeconds: Double
    
    public init(
        id: String,
        seasonNumber: Int,
        episodeNumber: Int,
        title: String,
        releaseDate: String? = nil,
        isWatched: Bool = false,
        watchProgressSeconds: Double = 0
    ) {
        self.id = id
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.title = title
        self.releaseDate = releaseDate
        self.isWatched = isWatched
        self.watchProgressSeconds = watchProgressSeconds
    }
    
    public var displayTitle: String {
        if title.lowercased().starts(with: "серия") || title.lowercased().starts(with: "episode") {
            return "Episode \(episodeNumber)"
        }
        return "Ep. \(episodeNumber): \(title)"
    }
}

public struct Season: Identifiable, Codable, Hashable, Sendable {
    public var id: Int { number }
    public let number: Int
    public let title: String
    public var episodes: [Episode]
    
    public init(number: Int, title: String, episodes: [Episode] = []) {
        self.number = number
        self.title = title
        self.episodes = episodes
    }
}

// MARK: - Detailed Media Information
public struct MediaDetail: Identifiable, Codable, Hashable, Sendable {
    public var id: String { item.id }
    public let item: MediaItem
    public let director: String?
    public let cast: [String]
    public let translators: [Translation]
    public let seasons: [Season]
    public let relatedItems: [MediaItem]
    
    public init(
        item: MediaItem,
        director: String? = nil,
        cast: [String] = [],
        translators: [Translation] = [],
        seasons: [Season] = [],
        relatedItems: [MediaItem] = []
    ) {
        self.item = item
        self.director = director
        self.cast = cast
        self.translators = translators
        self.seasons = seasons
        self.relatedItems = relatedItems
    }
}

// MARK: - Video Resolutions & Streams
public enum VideoQuality: String, Codable, CaseIterable, Comparable, Sendable {
    case res360p = "360p"
    case res480p = "480p"
    case res720p = "720p"
    case res1080p = "1080p"
    case res1080pUltra = "1080p Ultra"
    case res4K = "4K"
    case auto = "Auto"
    
    public var priority: Int {
        switch self {
        case .res360p: return 1
        case .res480p: return 2
        case .res720p: return 3
        case .res1080p: return 4
        case .res1080pUltra: return 5
        case .res4K: return 6
        case .auto: return 7
        }
    }
    
    public static func < (lhs: VideoQuality, rhs: VideoQuality) -> Bool {
        lhs.priority < rhs.priority
    }
    
    public static func from(raw: String) -> VideoQuality {
        let clean = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.contains("ultra") || clean.contains("1080p ultra") {
            return .res1080pUltra
        } else if clean.contains("4k") || clean.contains("2160p") {
            return .res4K
        } else if clean.contains("1080") {
            return .res1080p
        } else if clean.contains("720") {
            return .res720p
        } else if clean.contains("480") {
            return .res480p
        } else if clean.contains("360") {
            return .res360p
        }
        return .res720p
    }
}

public struct StreamOption: Identifiable, Codable, Hashable, Sendable {
    public var id: String { "\(quality.rawValue)-\(url.absoluteString)" }
    public let quality: VideoQuality
    public let rawResolutionLabel: String
    public let url: URL
    public let isHLS: Bool
    
    public init(quality: VideoQuality, rawResolutionLabel: String, url: URL, isHLS: Bool) {
        self.quality = quality
        self.rawResolutionLabel = rawResolutionLabel
        self.url = url
        self.isHLS = isHLS
    }
}

// MARK: - Subtitle Track
public struct SubtitleTrack: Identifiable, Codable, Hashable, Sendable {
    public var id: String { code }
    public let code: String
    public let language: String
    public let url: URL
    
    public init(code: String, language: String, url: URL) {
        self.code = code
        self.language = language
        self.url = url
    }
}

// MARK: - Stream Bundle
public struct StreamBundle: Codable, Sendable {
    public let streams: [StreamOption]
    public let subtitles: [SubtitleTrack]
    public let season: Int?
    public let episode: Int?
    public let translationId: String?
    
    public init(
        streams: [StreamOption],
        subtitles: [SubtitleTrack] = [],
        season: Int? = nil,
        episode: Int? = nil,
        translationId: String? = nil
    ) {
        self.streams = streams
        self.subtitles = subtitles
        self.season = season
        self.episode = episode
        self.translationId = translationId
    }
    
    public func stream(for preferredQuality: VideoQuality) -> StreamOption? {
        if let exact = streams.first(where: { $0.quality == preferredQuality }) {
            return exact
        }
        // Fallback to highest available resolution
        return streams.sorted(by: { $0.quality > $1.quality }).first
    }
}

// MARK: - Playback Progress & History
public struct PlaybackProgress: Identifiable, Codable, Hashable, Sendable {
    public var id: String { mediaId }
    public let mediaId: String
    public let title: String
    public let posterURL: URL?
    public let backdropURL: URL?
    public let seasonNumber: Int?
    public let episodeNumber: Int?
    public let episodeTitle: String?
    public let translationId: String?
    public var currentTimeSeconds: Double
    public var durationSeconds: Double
    public var updatedAt: Date
    public let contentType: ContentType
    
    public init(
        mediaId: String,
        title: String,
        posterURL: URL? = nil,
        backdropURL: URL? = nil,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil,
        episodeTitle: String? = nil,
        translationId: String? = nil,
        currentTimeSeconds: Double,
        durationSeconds: Double,
        updatedAt: Date = Date(),
        contentType: ContentType = .movie
    ) {
        self.mediaId = mediaId
        self.title = title
        self.posterURL = posterURL
        self.backdropURL = backdropURL
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.episodeTitle = episodeTitle
        self.translationId = translationId
        self.currentTimeSeconds = currentTimeSeconds
        self.durationSeconds = durationSeconds
        self.updatedAt = updatedAt
        self.contentType = contentType
    }
    
    public var progressFraction: Double {
        guard durationSeconds > 0 else { return 0 }
        return min(max(currentTimeSeconds / durationSeconds, 0), 1.0)
    }
    
    public var isCompleted: Bool {
        progressFraction > 0.92
    }
    
    public var formattedRemainingTime: String {
        let remaining = max(durationSeconds - currentTimeSeconds, 0)
        let minutes = Int(remaining) / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m left"
        }
        return "\(minutes)m left"
    }
}

// MARK: - Feed Section
public struct FeedSection: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let items: [MediaItem]
    
    public init(id: String, title: String, subtitle: String? = nil, items: [MediaItem]) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.items = items
    }
}
