import SwiftUI

public enum RezkaTheme {
    // MARK: - Color Palette
    public static let bgDeep = Color(red: 0.04, green: 0.05, blue: 0.08) // #0A0D14
    public static let bgSurface = Color(red: 0.08, green: 0.10, blue: 0.15) // #141A26
    public static let bgCard = Color(red: 0.11, green: 0.14, blue: 0.20) // #1C2433
    public static let bgCardHover = Color(red: 0.15, green: 0.19, blue: 0.27)
    
    public static let accentAmber = Color(red: 0.96, green: 0.62, blue: 0.04) // #F59E0B Rezka Gold
    public static let accentCyan = Color(red: 0.02, green: 0.71, blue: 0.83) // #06B6D4 Neon Cyan
    public static let accentCrimson = Color(red: 0.94, green: 0.27, blue: 0.27) // #EF4444
    public static let accentPurple = Color(red: 0.66, green: 0.33, blue: 0.98) // #A855F7
    
    public static let textPrimary = Color.white
    public static let textSecondary = Color.white.opacity(0.65)
    public static let textTertiary = Color.white.opacity(0.40)
    
    // MARK: - Gradients
    public static let heroBottomGradient = LinearGradient(
        colors: [
            Color.clear,
            bgDeep.opacity(0.4),
            bgDeep.opacity(0.85),
            bgDeep
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    public static let cardOverlayGradient = LinearGradient(
        colors: [
            Color.clear,
            Color.black.opacity(0.3),
            Color.black.opacity(0.85)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    public static let accentGradient = LinearGradient(
        colors: [accentAmber, Color(red: 0.98, green: 0.45, blue: 0.09)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let cyanGradient = LinearGradient(
        colors: [accentCyan, Color(red: 0.23, green: 0.51, blue: 0.96)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Custom Glassmorphic Modifiers
public struct GlassCardModifier: ViewModifier {
    public var cornerRadius: CGFloat = 16
    public var borderColor: Color = Color.white.opacity(0.12)
    
    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(RezkaTheme.bgCard.opacity(0.75))
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                }
            )
            .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 6)
    }
}

public struct GlassButtonModifier: ViewModifier {
    public var isProminent: Bool = false
    
    public func body(content: Content) -> some View {
        content
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Group {
                    if isProminent {
                        RezkaTheme.accentGradient
                    } else {
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.white.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(isProminent ? 0.3 : 0.15), lineWidth: 1)
            )
            .shadow(color: isProminent ? RezkaTheme.accentAmber.opacity(0.35) : Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

public extension View {
    func glassCard(cornerRadius: CGFloat = 16, borderColor: Color = Color.white.opacity(0.12)) -> some View {
        self.modifier(GlassCardModifier(cornerRadius: cornerRadius, borderColor: borderColor))
    }
    
    func glassButton(isProminent: Bool = false) -> some View {
        self.modifier(GlassButtonModifier(isProminent: isProminent))
    }
}
