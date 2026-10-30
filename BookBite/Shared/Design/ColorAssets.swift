import SwiftUI

// MARK: - Color Assets Extension
// This provides fallback colors when Asset Catalog colors aren't available
extension Color {
    static let primaryColor = Color.primary
    static let secondaryColor = Color.secondary
    static let accentColor = Color.primary
    
    static let backgroundColor = Color(UIColor.systemBackground)
    static let surfaceColor = Color(UIColor.secondarySystemBackground)
    static let cardBackground = Color(UIColor.tertiarySystemBackground)
    
    static let textPrimary = Color(UIColor.label)
    static let textSecondary = Color(UIColor.secondaryLabel)
    static let textTertiary = Color(UIColor.tertiaryLabel)

    /// Warm off-white page background for editorial screens (Discover); near-black in dark mode.
    static let paper = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 18 / 255, green: 17 / 255, blue: 16 / 255, alpha: 1)
            : UIColor(red: 250 / 255, green: 248 / 255, blue: 244 / 255, alpha: 1)
    })

    /// A card lying on `paper`: a step darker in light mode, a step lighter in dark mode.
    static let paperRaised = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 32 / 255, green: 30 / 255, blue: 28 / 255, alpha: 1)
            : UIColor(red: 241 / 255, green: 237 / 255, blue: 230 / 255, alpha: 1)
    })
}

// MARK: - Custom Color Initializers
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}