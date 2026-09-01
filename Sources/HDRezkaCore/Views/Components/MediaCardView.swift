import SwiftUI

public struct MediaCardView: View {
    public let item: MediaItem
    public var progress: PlaybackProgress?
    public let onSelect: () -> Void
    
    @State private var isPressed: Bool = false
    
    public init(item: MediaItem, progress: PlaybackProgress? = nil, onSelect: @escaping () -> Void) {
        self.item = item
        self.progress = progress
        self.onSelect = onSelect
    }
    
    public var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // Poster Image Container
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: item.posterURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            Rectangle()
                                .fill(RezkaTheme.bgCard)
                                .overlay(
                                    Image(systemName: "film")
                                        .font(.system(size: 24))
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
                    .frame(width: 140, height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    
                    // Card Bottom Gradient
                    RezkaTheme.cardOverlayGradient
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    
                    // Top Rating Badge
                    VStack {
                        HStack {
                            if item.primaryRatingValue > 0 {
                                HStack(spacing: 3) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(RezkaTheme.accentAmber)
                                    Text(String(format: "%.1f", item.primaryRatingValue))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.75))
                                .clipShape(Capsule())
                            }
                            
                            Spacer()
                            
                            if let badge = item.qualityBadge {
                                Text(badge)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(RezkaTheme.accentCyan)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.75))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(6)
                        
                        Spacer()
                    }
                    
                    // Continue Watching Progress Bar
                    if let prog = progress, prog.durationSeconds > 0 {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prog.formattedRemainingTime)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.white)
                                .shadow(color: .black, radius: 2)
                                .padding(.leading, 8)
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.3))
                                        .frame(height: 4)
                                    
                                    Capsule()
                                        .fill(RezkaTheme.accentAmber)
                                        .frame(width: max(0, min(geo.size.width * CGFloat(prog.progressFraction), geo.size.width)), height: 4)
                                }
                            }
                            .frame(height: 4)
                            .padding(.horizontal, 6)
                            .padding(.bottom, 6)
                        }
                    }
                }
                .frame(width: 140, height: 210)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 4)
                
                // Titles
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(RezkaTheme.textPrimary)
                        .lineLimit(1)
                    
                    Text(item.subtitleLine)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(RezkaTheme.textSecondary)
                        .lineLimit(1)
                }
                .frame(width: 140, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
}
