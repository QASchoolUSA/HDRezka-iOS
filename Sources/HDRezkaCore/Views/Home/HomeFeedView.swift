import SwiftUI

public struct HomeFeedView: View {
    public let onSelect: (MediaItem) -> Void
    public let onPlay: (MediaItem) -> Void
    
    @State private var heroItems: [MediaItem] = []
    @State private var trendingMovies: [MediaItem] = []
    @State private var topSeries: [MediaItem] = []
    @State private var animeItems: [MediaItem] = []
    @State private var continueWatching: [PlaybackProgress] = []
    @State private var continueWatchingMap: [String: PlaybackProgress] = [:]
    @State private var isLoading: Bool = true
    
    public init(onSelect: @escaping (MediaItem) -> Void, onPlay: @escaping (MediaItem) -> Void) {
        self.onSelect = onSelect
        self.onPlay = onPlay
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                RezkaTheme.bgDeep.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Apple TV+ Hero Carousel
                        if !heroItems.isEmpty {
                            HeroCarouselView(
                                items: heroItems,
                                onPlay: { item in onPlay(item) },
                                onSelect: { item in onSelect(item) }
                            )
                        }
                        
                        // Continue Watching Section (if any)
                        if !continueWatching.isEmpty {
                            let continueMedia = continueWatching.map { prog in
                                MediaItem(
                                    id: prog.mediaId,
                                    title: prog.title,
                                    posterURL: prog.posterURL,
                                    backdropURL: prog.backdropURL,
                                    contentType: prog.contentType,
                                    detailsPath: ""
                                )
                            }
                            
                            MediaRowSectionView(
                                title: "Continue Watching",
                                subtitle: "Pick up where you left off",
                                items: continueMedia,
                                progressMap: continueWatchingMap,
                                onSelect: { item in onSelect(item) }
                            )
                        }
                        
                        // Trending Movies Row
                        MediaRowSectionView(
                            title: "Trending Movies",
                            subtitle: "Top blockbusters & critically acclaimed",
                            items: trendingMovies,
                            onSelect: { item in onSelect(item) }
                        )
                        
                        // Top TV Series Row
                        MediaRowSectionView(
                            title: "Binge-Worthy TV Shows",
                            subtitle: "Most popular drama, sci-fi & thriller series",
                            items: topSeries,
                            onSelect: { item in onSelect(item) }
                        )
                        
                        // Anime & Animation Row
                        MediaRowSectionView(
                            title: "Animation & Anime",
                            subtitle: "Masterpiece animated series and films",
                            items: animeItems,
                            onSelect: { item in onSelect(item) }
                        )
                    }
                    .padding(.bottom, 40)
                }
                .refreshable {
                    await loadFeed()
                }
            }
            .navigationTitle("HDRezka")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(RezkaTheme.bgDeep, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.tv.fill")
                            .foregroundColor(RezkaTheme.accentAmber)
                            .font(.system(size: 16))
                        
                        Text("HDREZKA")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .task {
            await loadFeed()
        }
    }
    
    private func loadFeed() async {
        let mocks = MockDataProvider.mockTrendingItems()
        self.heroItems = Array(mocks.prefix(3))
        self.trendingMovies = mocks.filter { $0.contentType == .movie }
        self.topSeries = mocks.filter { $0.contentType == .series }
        self.animeItems = mocks.filter { $0.contentType == .anime || $0.contentType == .animation }
        
        let progressList = await LocalStorageManager.shared.getAllContinueWatching()
        self.continueWatching = progressList
        var map: [String: PlaybackProgress] = [:]
        for p in progressList {
            map[p.mediaId] = p
        }
        self.continueWatchingMap = map
        
        // Try live feed from scraper
        if let liveMovies = try? await HDRezkaScraperEngine.shared.fetchFeed(contentType: .movie), !liveMovies.isEmpty {
            self.trendingMovies = liveMovies
            self.heroItems = Array(liveMovies.prefix(4))
        }
        
        if let liveSeries = try? await HDRezkaScraperEngine.shared.fetchFeed(contentType: .series), !liveSeries.isEmpty {
            self.topSeries = liveSeries
        }
        
        self.isLoading = false
    }
}
