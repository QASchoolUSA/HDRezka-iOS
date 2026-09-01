import SwiftUI

public struct MediaDetailView: View {
    public let item: MediaItem
    public let onPlay: (MediaItem, MediaDetail?, Translation?, Season?, Episode?) -> Void
    public let onDismiss: () -> Void
    
    @State private var detail: MediaDetail?
    @State private var isLoading: Bool = true
    @State private var selectedTranslation: Translation?
    @State private var selectedSeason: Season?
    @State private var isBookmarked: Bool = false
    @State private var isDescriptionExpanded: Bool = false
    @State private var watchProgress: PlaybackProgress?
    
    public init(
        item: MediaItem,
        onPlay: @escaping (MediaItem, MediaDetail?, Translation?, Season?, Episode?) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.item = item
        self.onPlay = onPlay
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                RezkaTheme.bgDeep.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header Backdrop Clamped to Screen Width
                        headerBackdrop(width: geo.size.width)
                        
                        // Main Content
                        VStack(alignment: .leading, spacing: 18) {
                            // Title & Meta Info
                            titleAndMetaSection
                            
                            // Action Buttons (Play / Resume / Watchlist)
                            actionButtonsSection
                            
                            // Translations / Voice-Over Selector
                            if let d = detail, !d.translators.isEmpty {
                                translationsSection(translators: d.translators)
                            }
                            
                            // Seasons & Episodes (if series)
                            if let d = detail, !d.seasons.isEmpty {
                                seasonsAndEpisodesSection(seasons: d.seasons)
                            }
                            
                            // Synopsis
                            synopsisSection
                            
                            // Cast & Crew
                            if let d = detail {
                                castAndCrewSection(detail: d)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 36)
                        .frame(width: geo.size.width, alignment: .leading)
                    }
                    .frame(width: geo.size.width)
                }
                
                // Top Navigation Bar with Dismiss Button
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.65))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Button(action: toggleBookmark) {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(isBookmarked ? RezkaTheme.accentAmber : .white)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.65))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .task {
            await loadDetails()
        }
    }
    
    // MARK: - Header Backdrop
    private func headerBackdrop(width: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            ZStack {
                AsyncImage(url: item.backdropURL ?? item.posterURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: width, height: 300)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(RezkaTheme.bgCard)
                            .frame(width: width, height: 300)
                    case .empty:
                        Rectangle()
                            .fill(RezkaTheme.bgCard)
                            .frame(width: width, height: 300)
                            .overlay(ProgressView().tint(RezkaTheme.accentAmber))
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .frame(width: width, height: 300)
            .clipped()
            
            RezkaTheme.heroBottomGradient
                .frame(width: width, height: 300)
            
            // Play Button Floating on Backdrop
            Button(action: startPlayback) {
                Image(systemName: "play.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.black)
                    .frame(width: 60, height: 60)
                    .background(RezkaTheme.accentAmber)
                    .clipShape(Circle())
                    .shadow(color: RezkaTheme.accentAmber.opacity(0.5), radius: 12, x: 0, y: 6)
            }
            .padding(.bottom, 16)
        }
        .frame(width: width, height: 300)
        .clipped()
    }
    
    // MARK: - Title and Metadata
    private var titleAndMetaSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(2)
            
            if let orig = item.originalTitle, orig != item.title {
                Text(orig)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(RezkaTheme.textSecondary)
                    .lineLimit(1)
            }
            
            HStack(spacing: 6) {
                // Rating
                if item.primaryRatingValue > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(RezkaTheme.accentAmber)
                        Text(String(format: "%.1f", item.primaryRatingValue))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }
                
                if let badge = item.qualityBadge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(RezkaTheme.accentCyan)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(RezkaTheme.accentCyan.opacity(0.18))
                        .clipShape(Capsule())
                }
                
                if let year = item.year {
                    Text(String(year))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(RezkaTheme.textSecondary)
                }
                
                if let duration = item.durationMinutes {
                    Text("\(duration) min")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(RezkaTheme.textSecondary)
                }
                
                if let age = item.ageRating {
                    Text(age)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(RezkaTheme.textSecondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.white.opacity(0.25), lineWidth: 1))
                }
            }
            
            // Genres pills (horizontal scrollable)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(item.genres, id: \.self) { genre in
                        Text(genre)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(RezkaTheme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(RezkaTheme.bgCard)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.top, 2)
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtonsSection: some View {
        HStack(spacing: 10) {
            Button(action: startPlayback) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(watchProgress != nil && !watchProgress!.isCompleted ? "Resume (\(watchProgress!.formattedRemainingTime))" : "Watch Now")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RezkaTheme.accentAmber)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: RezkaTheme.accentAmber.opacity(0.35), radius: 6, x: 0, y: 3)
            }
            
            Button(action: toggleBookmark) {
                HStack(spacing: 5) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isBookmarked ? RezkaTheme.accentAmber : .white)
                    Text(isBookmarked ? "Saved" : "Watchlist")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            .fixedSize()
        }
    }
    
    // MARK: - Translations Section
    private func translationsSection(translators: [Translation]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Voice-Over & Studio")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(translators) { tr in
                        Button(action: { selectedTranslation = tr }) {
                            Text(tr.title)
                                .font(.system(size: 12, weight: selectedTranslation?.id == tr.id ? .bold : .medium))
                                .foregroundColor(selectedTranslation?.id == tr.id ? .black : .white)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    selectedTranslation?.id == tr.id ?
                                    RezkaTheme.accentAmber :
                                    RezkaTheme.bgCard
                                )
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(selectedTranslation?.id == tr.id ? 0.35 : 0.1), lineWidth: 1)
                                )
                        }
                        .fixedSize()
                    }
                }
            }
        }
    }
    
    // MARK: - Seasons & Episodes Section
    private func seasonsAndEpisodesSection(seasons: [Season]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Episodes")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Season Picker
                if seasons.count > 1 {
                    Menu {
                        ForEach(seasons) { season in
                            Button(action: { selectedSeason = season }) {
                                Text(season.title)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedSeason?.title ?? seasons.first?.title ?? "Season 1")
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9))
                        }
                        .foregroundColor(RezkaTheme.accentCyan)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .fixedSize()
                }
            }
            
            // Episodes List
            if let currentS = selectedSeason ?? seasons.first {
                VStack(spacing: 8) {
                    ForEach(currentS.episodes) { episode in
                        Button(action: {
                            onPlay(item, detail, selectedTranslation, currentS, episode)
                        }) {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(RezkaTheme.bgCardHover)
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(RezkaTheme.accentAmber)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(episode.displayTitle)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    if let date = episode.releaseDate {
                                        Text(date)
                                            .font(.system(size: 11))
                                            .foregroundColor(RezkaTheme.textSecondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if episode.isWatched {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(RezkaTheme.accentCyan)
                                }
                            }
                            .padding(10)
                            .glassCard(cornerRadius: 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // MARK: - Synopsis
    private var synopsisSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Overview")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(item.description ?? "No synopsis available.")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(RezkaTheme.textSecondary)
                .lineSpacing(3)
                .lineLimit(isDescriptionExpanded ? nil : 3)
            
            Button(action: { isDescriptionExpanded.toggle() }) {
                Text(isDescriptionExpanded ? "Show Less" : "Read More")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(RezkaTheme.accentAmber)
            }
        }
    }
    
    // MARK: - Cast & Crew
    private func castAndCrewSection(detail: MediaDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let dir = detail.director {
                HStack(alignment: .top) {
                    Text("Director:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(RezkaTheme.textSecondary)
                    Text(dir)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
            }
            
            if !detail.cast.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Cast:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(RezkaTheme.textSecondary)
                    Text(detail.cast.joined(separator: ", "))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 10)
    }
    
    // MARK: - Actions
    private func startPlayback() {
        let season = selectedSeason ?? detail?.seasons.first
        let episode = season?.episodes.first
        onPlay(item, detail, selectedTranslation, season, episode)
    }
    
    private func toggleBookmark() {
        Task {
            isBookmarked = await LocalStorageManager.shared.toggleWatchlist(item)
            await ConvexSyncManager.shared.pushWatchlist(item: item, isAdded: isBookmarked)
        }
    }
    
    private func loadDetails() async {
        isBookmarked = await LocalStorageManager.shared.isInWatchlist(item.id)
        watchProgress = await LocalStorageManager.shared.getProgress(for: item.id)
        
        do {
            let fetched = try await HDRezkaScraperEngine.shared.fetchDetails(for: item)
            self.detail = fetched
            self.selectedTranslation = fetched.translators.first
            self.selectedSeason = fetched.seasons.first
            self.isLoading = false
        } catch {
            self.isLoading = false
        }
    }
}
