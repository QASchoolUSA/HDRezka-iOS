import SwiftUI

public struct SearchView: View {
    public let onSelect: (MediaItem) -> Void
    
    @State private var query: String = ""
    @State private var selectedType: ContentType? = nil
    @State private var selectedGenre: String? = nil
    @State private var results: [MediaItem] = []
    @State private var isSearching: Bool = false
    @State private var searchTask: Task<Void, Never>?
    
    private let genres = ["All", "Sci-Fi", "Action", "Drama", "Comedy", "Thriller", "Horror", "Adventure", "Animation", "Crime", "Fantasy"]
    
    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 16)
    ]
    
    public init(onSelect: @escaping (MediaItem) -> Void) {
        self.onSelect = onSelect
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                RezkaTheme.bgDeep.ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Search Bar
                    searchBar
                    
                    // Filter Chips (Categories & Genres)
                    filterChips
                    
                    // Results Grid or Empty State
                    if isSearching {
                        Spacer()
                        ProgressView().tint(RezkaTheme.accentAmber)
                        Spacer()
                    } else if results.isEmpty {
                        emptyState
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(results) { item in
                                    MediaCardView(item: item, onSelect: { onSelect(item) })
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 30)
                        }
                    }
                }
            }
            .navigationTitle("Search & Discover")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(RezkaTheme.bgDeep, for: .navigationBar)
            #endif
        }
        .task {
            // Load trending as initial discovery feed
            results = MockDataProvider.mockTrendingItems()
        }
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(RezkaTheme.textSecondary)
            
            TextField("Movies, Series, Anime, Actors...", text: $query)
                .foregroundColor(.white)
                .font(.system(size: 15))
                .onChange(of: query) { _, newQuery in
                    performSearch(query: newQuery)
                }
            
            if !query.isEmpty {
                Button(action: {
                    query = ""
                    results = MockDataProvider.mockTrendingItems()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(RezkaTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: 14)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Filter Chips
    private var filterChips: some View {
        VStack(spacing: 8) {
            // Content Types (Movies, Series, Cartoons, Anime)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button(action: { selectedType = nil; filterResults() }) {
                        Text("All Types")
                            .font(.system(size: 12, weight: selectedType == nil ? .bold : .medium))
                            .foregroundColor(selectedType == nil ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedType == nil ? RezkaTheme.accentCyan : RezkaTheme.bgCard)
                            .clipShape(Capsule())
                    }
                    
                    ForEach(ContentType.allCases) { type in
                        Button(action: { selectedType = type; filterResults() }) {
                            HStack(spacing: 4) {
                                Image(systemName: type.systemIcon)
                                Text(type.displayName)
                            }
                            .font(.system(size: 12, weight: selectedType == type ? .bold : .medium))
                            .foregroundColor(selectedType == type ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedType == type ? RezkaTheme.accentCyan : RezkaTheme.bgCard)
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(RezkaTheme.textTertiary)
            
            Text("No Results Found")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Try searching for another movie, TV show, or genre.")
                .font(.system(size: 13))
                .foregroundColor(RezkaTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
    
    // MARK: - Actions
    private func performSearch(query: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }
            
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                results = MockDataProvider.mockTrendingItems()
                return
            }
            
            isSearching = true
            let fetched = try? await HDRezkaScraperEngine.shared.search(query: query)
            isSearching = false
            results = fetched ?? []
        }
    }
    
    private func filterResults() {
        if let type = selectedType {
            results = MockDataProvider.mockTrendingItems().filter { $0.contentType == type }
        } else {
            results = MockDataProvider.mockTrendingItems()
        }
    }
}
