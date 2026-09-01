import SwiftUI

public struct HeroCarouselView: View {
    public let items: [MediaItem]
    public let onPlay: (MediaItem) -> Void
    public let onSelect: (MediaItem) -> Void
    
    @State private var currentIndex: Int = 0
    @State private var timer = Timer.publish(every: 6.0, on: .main, in: .common).autoconnect()
    
    public init(items: [MediaItem], onPlay: @escaping (MediaItem) -> Void, onSelect: @escaping (MediaItem) -> Void) {
        self.items = items
        self.onPlay = onPlay
        self.onSelect = onSelect
    }
    
    private var heroHeight: CGFloat {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? 440 : 360
        #else
        return 420
        #endif
    }
    
    public var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            GeometryReader { parentGeo in
                ZStack(alignment: .bottom) {
                    // Paging Hero Images
                    TabView(selection: $currentIndex) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            HeroCardSlide(
                                item: item,
                                slideWidth: parentGeo.size.width,
                                slideHeight: heroHeight,
                                onPlay: { onPlay(item) },
                                onSelect: { onSelect(item) }
                            )
                            .frame(width: parentGeo.size.width, height: heroHeight)
                            .tag(index)
                        }
                    }
                    #if os(iOS)
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    #endif
                    .frame(width: parentGeo.size.width, height: heroHeight)
                    
                    // Bottom Page Indicator Dots
                    HStack(spacing: 6) {
                        ForEach(0..<items.count, id: \.self) { idx in
                            Capsule()
                                .fill(idx == currentIndex ? RezkaTheme.accentAmber : Color.white.opacity(0.35))
                                .frame(width: idx == currentIndex ? 20 : 6, height: 4)
                                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: currentIndex)
                        }
                    }
                    .padding(.bottom, 10)
                }
            }
            .frame(height: heroHeight)
            .clipped()
            .onReceive(timer) { _ in
                guard !items.isEmpty else { return }
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentIndex = (currentIndex + 1) % items.count
                }
            }
        }
    }
}

private struct HeroCardSlide: View {
    let item: MediaItem
    let slideWidth: CGFloat
    let slideHeight: CGFloat
    let onPlay: () -> Void
    let onSelect: () -> Void
    
    @State private var isBookmarked: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Backdrop Image clamped to slideWidth and slideHeight
            ZStack {
                AsyncImage(url: item.backdropURL ?? item.posterURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: slideWidth, height: slideHeight)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(RezkaTheme.bgCard)
                            .overlay(
                                Image(systemName: "film.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(RezkaTheme.textTertiary)
                            )
                    case .empty:
                        Rectangle()
                            .fill(RezkaTheme.bgCard)
                            .overlay(ProgressView().tint(RezkaTheme.accentAmber))
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .frame(width: slideWidth, height: slideHeight)
            .clipped()
            
            // Rich Gradient Overlay
            RezkaTheme.heroBottomGradient
                .frame(width: slideWidth, height: slideHeight)
            
            // Left Vignette Gradient for Depth
            LinearGradient(
                colors: [Color.black.opacity(0.7), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: slideWidth, height: slideHeight)
            
            // Hero Content Overlay
            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                
                // Badges Row
                HStack(spacing: 6) {
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
                        .background(Color.black.opacity(0.65))
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
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(RezkaTheme.textSecondary)
                    }
                    
                    if let age = item.ageRating {
                        Text(age)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(RezkaTheme.textSecondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.25), lineWidth: 1))
                    }
                }
                
                // Title
                Text(item.title)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.9), radius: 4, x: 0, y: 2)
                    .lineLimit(1)
                
                // Subtitle / Genres
                Text(item.genres.joined(separator: " • "))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(RezkaTheme.textSecondary)
                    .lineLimit(1)
                
                // Action Buttons
                HStack(spacing: 10) {
                    Button(action: onPlay) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("Watch Now")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(RezkaTheme.accentAmber)
                        .clipShape(Capsule())
                        .shadow(color: RezkaTheme.accentAmber.opacity(0.4), radius: 6, x: 0, y: 3)
                    }
                    .fixedSize()
                    
                    Button(action: onSelect) {
                        HStack(spacing: 5) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Details")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .fixedSize()
                    
                    Button(action: {
                        Task {
                            isBookmarked = await LocalStorageManager.shared.toggleWatchlist(item)
                            await ConvexSyncManager.shared.pushWatchlist(item: item, isAdded: isBookmarked)
                        }
                    }) {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isBookmarked ? RezkaTheme.accentAmber : .white)
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .fixedSize()
                }
                .padding(.top, 2)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 16)
            .frame(width: slideWidth, alignment: .leading)
        }
        .frame(width: slideWidth, height: slideHeight)
        .clipped()
        .task {
            isBookmarked = await LocalStorageManager.shared.isInWatchlist(item.id)
        }
    }
}
