import SwiftUI

public struct LibraryView: View {
    public let onSelect: (MediaItem) -> Void
    public let onResumeProgress: (PlaybackProgress) -> Void
    
    @State private var selectedTab: LibraryTab = .continueWatching
    @State private var continueWatchingItems: [PlaybackProgress] = []
    @State private var watchlistItems: [MediaItem] = []
    @State private var historyItems: [PlaybackProgress] = []
    
    public enum LibraryTab: String, CaseIterable, Identifiable {
        case continueWatching = "Continue Watching"
        case watchlist = "Watchlist"
        case history = "History"
        
        public var id: String { rawValue }
        
        public var icon: String {
            switch self {
            case .continueWatching: return "play.circle.fill"
            case .watchlist: return "bookmark.fill"
            case .history: return "clock.fill"
            }
        }
    }
    
    public init(
        onSelect: @escaping (MediaItem) -> Void,
        onResumeProgress: @escaping (PlaybackProgress) -> Void
    ) {
        self.onSelect = onSelect
        self.onResumeProgress = onResumeProgress
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                RezkaTheme.bgDeep.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Segmented Picker
                    pickerSegment
                    
                    // Tab Content
                    switch selectedTab {
                    case .continueWatching:
                        continueWatchingList
                    case .watchlist:
                        watchlistGrid
                    case .history:
                        historyList
                    }
                }
            }
            .navigationTitle("My Library")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(RezkaTheme.bgDeep, for: .navigationBar)
            #endif
            .toolbar {
                if selectedTab == .history && !historyItems.isEmpty {
                    Button("Clear") {
                        Task {
                            await LocalStorageManager.shared.clearAllHistory()
                            await loadData()
                        }
                    }
                    .foregroundColor(RezkaTheme.accentCrimson)
                }
            }
        }
        .task {
            await loadData()
        }
    }
    
    // MARK: - Picker Segment
    private var pickerSegment: some View {
        HStack(spacing: 6) {
            ForEach(LibraryTab.allCases) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11))
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: selectedTab == tab ? .bold : .medium))
                    }
                    .foregroundColor(selectedTab == tab ? .black : .white)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        selectedTab == tab ?
                        RezkaTheme.accentAmber :
                        Color.clear
                    )
                    .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(RezkaTheme.bgCard)
        .clipShape(Capsule())
        .padding(.horizontal, 20)
    }
    
    // MARK: - Continue Watching
    private var continueWatchingList: some View {
        Group {
            if continueWatchingItems.isEmpty {
                emptyState(icon: "play.slash", title: "No Videos in Progress", subtitle: "Start watching movies or TV shows to resume anytime.")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(continueWatchingItems) { item in
                            Button(action: { onResumeProgress(item) }) {
                                HStack(spacing: 14) {
                                    // Poster with Play Overlay
                                    ZStack {
                                        AsyncImage(url: item.posterURL) { phase in
                                            if let image = phase.image {
                                                image.resizable().aspectRatio(contentMode: .fill)
                                            } else {
                                                Rectangle().fill(RezkaTheme.bgCardHover)
                                            }
                                        }
                                        .frame(width: 80, height: 110)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        
                                        Image(systemName: "play.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(RezkaTheme.accentAmber)
                                            .shadow(radius: 4)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(item.title)
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        
                                        if let season = item.seasonNumber, let ep = item.episodeNumber {
                                            Text("Season \(season), Episode \(ep)")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(RezkaTheme.accentCyan)
                                        }
                                        
                                        Text(item.formattedRemainingTime)
                                            .font(.system(size: 11))
                                            .foregroundColor(RezkaTheme.textSecondary)
                                        
                                        // Progress bar
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                Capsule()
                                                    .fill(Color.white.opacity(0.2))
                                                    .frame(height: 4)
                                                
                                                Capsule()
                                                    .fill(RezkaTheme.accentAmber)
                                                    .frame(width: max(0, min(geo.size.width * CGFloat(item.progressFraction), geo.size.width)), height: 4)
                                            }
                                        }
                                        .frame(height: 4)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        Task {
                                            await LocalStorageManager.shared.removeProgress(for: item.mediaId)
                                            await loadData()
                                        }
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(RezkaTheme.textTertiary)
                                            .padding(8)
                                    }
                                }
                                .padding(12)
                                .glassCard(cornerRadius: 14)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
    }
    
    // MARK: - Watchlist
    private var watchlistGrid: some View {
        Group {
            if watchlistItems.isEmpty {
                emptyState(icon: "bookmark.slash", title: "Watchlist is Empty", subtitle: "Save your favorite movies and shows to watch later.")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)], spacing: 20) {
                        ForEach(watchlistItems) { item in
                            MediaCardView(item: item, onSelect: { onSelect(item) })
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
    }
    
    // MARK: - History
    private var historyList: some View {
        Group {
            if historyItems.isEmpty {
                emptyState(icon: "clock.arrow.circlepath", title: "No History", subtitle: "Your watched videos will appear here.")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(historyItems) { item in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    if let s = item.seasonNumber, let e = item.episodeNumber {
                                        Text("S\(s) E\(e)")
                                            .font(.system(size: 12))
                                            .foregroundColor(RezkaTheme.textSecondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Text(item.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 11))
                                    .foregroundColor(RezkaTheme.textTertiary)
                            }
                            .padding(12)
                            .glassCard(cornerRadius: 12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
    }
    
    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(RezkaTheme.textTertiary)
            
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(RezkaTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
    
    private func loadData() async {
        continueWatchingItems = await LocalStorageManager.shared.getAllContinueWatching()
        watchlistItems = await LocalStorageManager.shared.getAllWatchlist()
        historyItems = await LocalStorageManager.shared.getAllHistory()
    }
}
