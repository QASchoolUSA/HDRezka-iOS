import SwiftUI

public struct AppRootView: View {
    @StateObject private var playbackManager = PlaybackManager.shared
    @State private var selectedTab: TabItem = .home
    @State private var selectedMediaForDetail: MediaItem?
    
    public enum TabItem: String, CaseIterable, Identifiable {
        case home = "Home"
        case search = "Search"
        case library = "Library"
        case settings = "Settings"
        
        public var id: String { rawValue }
        
        public var icon: String {
            switch self {
            case .home: return "house.fill"
            case .search: return "magnifyingglass"
            case .library: return "square.stack.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    public init() {}
    
    public var body: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            iPadSidebarLayout
        } else {
            iPhoneTabLayout
        }
        #else
        iPadSidebarLayout
        #endif
    }
    
    // MARK: - iPhone Tab Layout
    private var iPhoneTabLayout: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeFeedView(
                    onSelect: { item in selectedMediaForDetail = item },
                    onPlay: { item in startQuickPlay(item) }
                )
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(TabItem.home)
                
                SearchView(
                    onSelect: { item in selectedMediaForDetail = item }
                )
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(TabItem.search)
                
                LibraryView(
                    onSelect: { item in selectedMediaForDetail = item },
                    onResumeProgress: { progress in resumeProgress(progress) }
                )
                .tabItem {
                    Label("Library", systemImage: "square.stack.fill")
                }
                .tag(TabItem.library)
                
                SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(TabItem.settings)
            }
            .tint(RezkaTheme.accentAmber)
        }
        .sheet(item: $selectedMediaForDetail) { item in
            MediaDetailView(
                item: item,
                onPlay: { media, detail, translation, season, episode in
                    selectedMediaForDetail = nil
                    Task {
                        await playbackManager.playMedia(
                            item: media,
                            detail: detail,
                            translation: translation,
                            season: season,
                            episode: episode
                        )
                    }
                },
                onDismiss: {
                    selectedMediaForDetail = nil
                }
            )
        }
        #if os(iOS) || os(tvOS) || os(visionOS)
        .fullScreenCover(isPresented: $playbackManager.isPresented) {
            CustomPlayerOverlayView(playbackManager: playbackManager)
        }
        #else
        .sheet(isPresented: $playbackManager.isPresented) {
            CustomPlayerOverlayView(playbackManager: playbackManager)
                .frame(minWidth: 800, minHeight: 500)
        }
        #endif
    }
    
    // MARK: - iPadOS & Mac NavigationSplitView Layout
    private var iPadSidebarLayout: some View {
        NavigationSplitView {
            List {
                ForEach(TabItem.allCases) { tab in
                    Button(action: {
                        selectedTab = tab
                    }) {
                        HStack {
                            Label(tab.rawValue, systemImage: tab.icon)
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            if selectedTab == tab {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(RezkaTheme.accentAmber)
                            }
                        }
                        .padding(.vertical, 4)
                        .foregroundColor(selectedTab == tab ? RezkaTheme.accentAmber : .white)
                    }
                }
            }
            .navigationTitle("HDRezka")
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(RezkaTheme.bgSurface)
        } detail: {
            Group {
                switch selectedTab {
                case .home:
                    HomeFeedView(
                        onSelect: { item in selectedMediaForDetail = item },
                        onPlay: { item in startQuickPlay(item) }
                    )
                case .search:
                    SearchView(
                        onSelect: { item in selectedMediaForDetail = item }
                    )
                case .library:
                    LibraryView(
                        onSelect: { item in selectedMediaForDetail = item },
                        onResumeProgress: { progress in resumeProgress(progress) }
                    )
                case .settings:
                    SettingsView()
                }
            }
        }
        .sheet(item: $selectedMediaForDetail) { item in
            MediaDetailView(
                item: item,
                onPlay: { media, detail, translation, season, episode in
                    selectedMediaForDetail = nil
                    Task {
                        await playbackManager.playMedia(
                            item: media,
                            detail: detail,
                            translation: translation,
                            season: season,
                            episode: episode
                        )
                    }
                },
                onDismiss: {
                    selectedMediaForDetail = nil
                }
            )
        }
        #if os(iOS) || os(tvOS) || os(visionOS)
        .fullScreenCover(isPresented: $playbackManager.isPresented) {
            CustomPlayerOverlayView(playbackManager: playbackManager)
        }
        #else
        .sheet(isPresented: $playbackManager.isPresented) {
            CustomPlayerOverlayView(playbackManager: playbackManager)
                .frame(minWidth: 800, minHeight: 500)
        }
        #endif
    }
    
    private func startQuickPlay(_ item: MediaItem) {
        Task {
            let detail = try? await HDRezkaScraperEngine.shared.fetchDetails(for: item)
            let season = detail?.seasons.first
            let episode = season?.episodes.first
            await playbackManager.playMedia(
                item: item,
                detail: detail,
                translation: detail?.translators.first,
                season: season,
                episode: episode
            )
        }
    }
    
    private func resumeProgress(_ progress: PlaybackProgress) {
        let item = MediaItem(
            id: progress.mediaId,
            title: progress.title,
            posterURL: progress.posterURL,
            backdropURL: progress.backdropURL,
            contentType: progress.contentType,
            detailsPath: ""
        )
        Task {
            let detail = try? await HDRezkaScraperEngine.shared.fetchDetails(for: item)
            let season = detail?.seasons.first(where: { $0.number == progress.seasonNumber }) ?? detail?.seasons.first
            let episode = season?.episodes.first(where: { $0.episodeNumber == progress.episodeNumber }) ?? season?.episodes.first
            let translation = detail?.translators.first(where: { $0.id == progress.translationId })
            
            await playbackManager.playMedia(
                item: item,
                detail: detail,
                translation: translation,
                season: season,
                episode: episode,
                startFromSavedPosition: true
            )
        }
    }
}
