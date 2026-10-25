import SwiftUI

// MARK: - Design System
struct DesignSystem {

    // MARK: - Colors
    struct Colors {
        // MARK: - Monochrome UI Colors
        // Primary colors for buttons, icons, and UI elements
        static let primary = Color.primary
        static let secondary = Color.secondary
        static let accent = Color.primary

        // Monochrome Palette for UI elements
        static let monoDark = Color(white: 0.15)
        static let monoMedium = Color(white: 0.45)
        static let monoLight = Color(white: 0.75)
        static let monoLighter = Color(white: 0.92)

        // Legacy color references (now monochrome)
        static let vibrantBlue = monoMedium
        static let vibrantPurple = monoMedium
        static let vibrantPink = monoMedium
        static let vibrantGreen = monoMedium
        static let vibrantOrange = monoMedium
        static let vibrantYellow = monoMedium

        // Neutral Colors
        static let background = Color("BackgroundColor")
        static let surface = Color("SurfaceColor")
        static let cardBackground = Color("CardBackground")

        // Text Colors
        static let textPrimary = Color("TextPrimary")
        static let textSecondary = Color("TextSecondary")
        static let textTertiary = Color("TextTertiary")

        // MARK: - Badge Colors (preserved for visual hierarchy)
        // These are the only colored elements besides book covers
        static let badgeGreen = Color(red: 0.2, green: 0.78, blue: 0.35)
        static let badgeOrange = Color(red: 1.0, green: 0.58, blue: 0.0)
        static let badgeYellow = Color(red: 0.95, green: 0.77, blue: 0.06)
        static let badgeRed = Color(red: 1.0, green: 0.27, blue: 0.23)

        // Semantic Colors (for badges and status indicators only)
        static let success = badgeGreen
        static let warning = badgeOrange
        static let error = badgeRed
        static let info = monoMedium

        // NYT Bestseller Badge Colors (preserved)
        static let nytGold = Color(red: 1.0, green: 0.84, blue: 0.0)
        static let nytGoldAccent = Color(red: 0.8, green: 0.65, blue: 0.0)

        // Star Rating Color (preserved for ratings display)
        static let starColor = Color(red: 1.0, green: 0.58, blue: 0.0)

        // Genre/Category Colors (now monochrome for tags)
        static let genreTagColor = monoMedium
        static let businessColor = monoMedium
        static let selfHelpColor = monoMedium
        static let biographyColor = monoMedium
        static let scienceColor = monoMedium
        static let politicsColor = monoMedium
        static let healthColor = monoMedium
        static let historyColor = monoMedium
        static let psychologyColor = monoMedium
        static let technologyColor = monoMedium
        static let philosophyColor = monoMedium
        static let economicsColor = monoMedium
        static let leadershipColor = monoMedium
        static let entrepreneurshipColor = monoMedium
        static let memoirColor = monoMedium
        static let educationColor = monoMedium
        static let artColor = monoMedium
        static let musicColor = monoMedium
        static let travelColor = monoMedium
        static let cookingColor = monoMedium
        static let nutritionColor = monoMedium
        static let fitnessColor = monoMedium
        static let mentalHealthColor = monoMedium
        static let innovationColor = monoMedium
        static let marketingColor = monoMedium
        static let productivityColor = monoMedium
        static let mindfulnessColor = monoMedium
        static let biologyColor = monoMedium
        static let physicsColor = monoMedium
        static let medicineColor = monoMedium
        static let environmentColor = monoMedium
        static let spiritualityColor = monoMedium
        static let sociologyColor = monoMedium
        static let anthropologyColor = monoMedium
        static let personalDevelopmentColor = monoMedium

        static func genreColor(for genre: String) -> Color {
            // All genres now use monochrome
            return genreTagColor
        }

        static func categoryColor(for category: String) -> Color {
            // Only NYT Bestsellers gets gold, everything else is monochrome
            switch category.lowercased() {
            case "nyt bestsellers": return nytGold
            default: return genreTagColor
            }
        }
    }
    
    // MARK: - Typography
    struct Typography {
        // Headlines
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title1 = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 22, weight: .bold, design: .rounded)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
        
        // Body Text
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        static let caption1 = Font.system(size: 12, weight: .regular, design: .default)
        static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
        
        // Special
        static let bookTitle = Font.system(size: 16, weight: .semibold, design: .serif)
        static let bookAuthor = Font.system(size: 14, weight: .medium, design: .default)
        static let badge = Font.system(size: 11, weight: .bold, design: .rounded)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 24
        static let circular: CGFloat = 999
    }
    
    // MARK: - Shadows
    struct Shadow {
        static let small = (color: Color.black.opacity(0.08), radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1))
        static let medium = (color: Color.black.opacity(0.12), radius: CGFloat(6), x: CGFloat(0), y: CGFloat(3))
        static let large = (color: Color.black.opacity(0.16), radius: CGFloat(12), x: CGFloat(0), y: CGFloat(6))
        // NYT cards now use subtle black shadow instead of gold glow
        static let nytGlow = (color: Color.black.opacity(0.12), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
    }
    
    // MARK: - Animations
    struct Animations {
        static let spring = Animation.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)
        static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)
        static let smooth = Animation.easeInOut(duration: 0.3)
        static let quick = Animation.easeInOut(duration: 0.2)
        static let gentle = Animation.easeInOut(duration: 0.5)
    }
}

// MARK: - View Extensions
extension View {
    func customCardStyle() -> some View {
        self
            .background(DesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            .shadow(
                color: DesignSystem.Shadow.medium.color,
                radius: DesignSystem.Shadow.medium.radius,
                x: DesignSystem.Shadow.medium.x,
                y: DesignSystem.Shadow.medium.y
            )
    }
    
    func nytBestsellerCard() -> some View {
        self
            .background(DesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .shadow(
                color: DesignSystem.Shadow.medium.color,
                radius: DesignSystem.Shadow.medium.radius,
                x: DesignSystem.Shadow.medium.x,
                y: DesignSystem.Shadow.medium.y
            )
    }
    
    func genreSection(color: Color) -> some View {
        self
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
    
    func bounceOnTap(scale: CGFloat = 0.95) -> some View {
        self
            .scaleEffect(1.0)
            .onTapGesture {
                withAnimation(DesignSystem.Animations.quick) {
                    // Trigger haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            }
    }
    
    func shimmerEffect() -> some View {
        self
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: -200)
                    .animation(
                        Animation.linear(duration: 1.5).repeatForever(autoreverses: false),
                        value: true
                    )
            )
            .clipped()
    }
}