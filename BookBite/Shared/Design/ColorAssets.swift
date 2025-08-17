import SwiftUI

// MARK: - Color Assets Extension
// This provides fallback colors when Asset Catalog colors aren't available
extension Color {
    static let primaryColor = Color(red: 0.2, green: 0.6, blue: 1.0)
    static let secondaryColor = Color(red: 0.6, green: 0.3, blue: 1.0)
    static let accentColor = Color(red: 1.0, green: 0.6, blue: 0.2)
    
    static let backgroundColor = Color(UIColor.systemBackground)
    static let surfaceColor = Color(UIColor.secondarySystemBackground)
    static let cardBackground = Color(UIColor.tertiarySystemBackground)
    
    static let textPrimary = Color(UIColor.label)
    static let textSecondary = Color(UIColor.secondaryLabel)
    static let textTertiary = Color(UIColor.tertiaryLabel)
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