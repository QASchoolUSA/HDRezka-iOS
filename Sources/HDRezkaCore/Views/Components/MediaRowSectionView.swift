import SwiftUI

public struct MediaRowSectionView: View {
    public let title: String
    public var subtitle: String?
    public let items: [MediaItem]
    public var progressMap: [String: PlaybackProgress] = [:]
    public let onSelect: (MediaItem) -> Void
    public var onSeeAll: (() -> Void)?
    
    public init(
        title: String,
        subtitle: String? = nil,
        items: [MediaItem],
        progressMap: [String: PlaybackProgress] = [:],
        onSelect: @escaping (MediaItem) -> Void,
        onSeeAll: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.items = items
        self.progressMap = progressMap
        self.onSelect = onSelect
        self.onSeeAll = onSeeAll
    }
    
    public var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 14) {
                // Section Header
                HStack(alignment: .bottom) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(RezkaTheme.accentAmber)
                            .frame(width: 6, height: 6)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(RezkaTheme.textPrimary)
                            
                            if let sub = subtitle {
                                Text(sub)
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(RezkaTheme.textSecondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    if let seeAll = onSeeAll {
                        Button(action: seeAll) {
                            HStack(spacing: 4) {
                                Text("See All")
                                    .font(.system(size: 13, weight: .semibold))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(RezkaTheme.accentCyan)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                // Horizontal Scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(items) { item in
                            MediaCardView(
                                item: item,
                                progress: progressMap[item.id],
                                onSelect: { onSelect(item) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}
