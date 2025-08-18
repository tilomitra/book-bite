import SwiftUI

// MARK: - Design System
struct DesignSystem {
    
    // MARK: - Colors
    struct Colors {
        // Primary Brand Colors
        static let primary = Color("PrimaryColor")
        static let secondary = Color("SecondaryColor")
        static let accent = Color("AccentColor")
        
        // Playful Color Palette
        static let vibrantBlue = Color(red: 0.2, green: 0.6, blue: 1.0)
        static let vibrantPurple = Color(red: 0.6, green: 0.3, blue: 1.0)
        static let vibrantPink = Color(red: 1.0, green: 0.3, blue: 0.7)
        static let vibrantGreen = Color(red: 0.3, green: 0.8, blue: 0.5)
        static let vibrantOrange = Color(red: 1.0, green: 0.6, blue: 0.2)
        static let vibrantYellow = Color(red: 1.0, green: 0.8, blue: 0.2)
        
        // Neutral Colors
        static let background = Color("BackgroundColor")
        static let surface = Color("SurfaceColor")
        static let cardBackground = Color("CardBackground")
        
        // Text Colors
        static let textPrimary = Color("TextPrimary")
        static let textSecondary = Color("TextSecondary")
        static let textTertiary = Color("TextTertiary")
        
        // Semantic Colors
        static let success = vibrantGreen
        static let warning = vibrantOrange
        static let error = vibrantPink
        static let info = vibrantBlue
        
        // NYT Bestseller Colors
        static let nytGold = Color(red: 1.0, green: 0.84, blue: 0.0)
        static let nytGoldAccent = Color(red: 0.8, green: 0.65, blue: 0.0)
        
        // Genre/Category Colors
        static let businessColor = vibrantBlue
        static let selfHelpColor = vibrantGreen
        static let biographyColor = vibrantPurple
        static let scienceColor = vibrantOrange
        static let politicsColor = Color(red: 0.8, green: 0.2, blue: 0.3)
        static let healthColor = Color(red: 0.2, green: 0.8, blue: 0.6)
        static let historyColor = Color(red: 0.6, green: 0.4, blue: 0.2)
        static let psychologyColor = vibrantPink
        static let technologyColor = Color(red: 0.3, green: 0.5, blue: 0.9)
        static let philosophyColor = Color(red: 0.5, green: 0.3, blue: 0.7)
        static let economicsColor = Color(red: 0.2, green: 0.7, blue: 0.5)
        static let leadershipColor = Color(red: 0.9, green: 0.5, blue: 0.2)
        static let entrepreneurshipColor = Color(red: 0.7, green: 0.4, blue: 0.9)
        static let memoirColor = Color(red: 0.6, green: 0.2, blue: 0.8)
        static let educationColor = Color(red: 0.4, green: 0.6, blue: 0.8)
        static let artColor = Color(red: 0.9, green: 0.3, blue: 0.5)
        static let musicColor = Color(red: 0.7, green: 0.2, blue: 0.6)
        static let travelColor = Color(red: 0.3, green: 0.7, blue: 0.8)
        static let cookingColor = Color(red: 0.8, green: 0.6, blue: 0.3)
        static let nutritionColor = Color(red: 0.4, green: 0.8, blue: 0.4)
        static let fitnessColor = Color(red: 0.9, green: 0.4, blue: 0.3)
        static let mentalHealthColor = Color(red: 0.5, green: 0.7, blue: 0.9)
        static let innovationColor = Color(red: 0.8, green: 0.3, blue: 0.8)
        static let marketingColor = Color(red: 0.6, green: 0.5, blue: 0.9)
        static let productivityColor = Color(red: 0.3, green: 0.8, blue: 0.7)
        static let mindfulnessColor = Color(red: 0.4, green: 0.6, blue: 0.9)
        static let biologyColor = Color(red: 0.3, green: 0.7, blue: 0.4)
        static let physicsColor = Color(red: 0.5, green: 0.4, blue: 0.8)
        static let medicineColor = Color(red: 0.7, green: 0.3, blue: 0.5)
        static let environmentColor = Color(red: 0.2, green: 0.6, blue: 0.4)
        static let spiritualityColor = Color(red: 0.6, green: 0.4, blue: 0.8)
        static let sociologyColor = Color(red: 0.5, green: 0.6, blue: 0.7)
        static let anthropologyColor = Color(red: 0.7, green: 0.5, blue: 0.6)
        static let personalDevelopmentColor = Color(red: 0.4, green: 0.7, blue: 0.6)
        
        static func genreColor(for genre: String) -> Color {
            switch genre.lowercased() {
            case "business": return businessColor
            case "self-help", "self help": return selfHelpColor
            case "biography": return biographyColor
            case "science": return scienceColor
            case "politics": return politicsColor
            case "health", "wellness": return healthColor
            case "history": return historyColor
            case "psychology": return psychologyColor
            default: return vibrantBlue
            }
        }
        
        static func categoryColor(for category: String) -> Color {
            switch category.lowercased() {
            case "business": return businessColor
            case "self-help", "self help": return selfHelpColor
            case "biography": return biographyColor
            case "science": return scienceColor
            case "politics": return politicsColor
            case "health", "wellness": return healthColor
            case "history", "american history": return historyColor
            case "psychology": return psychologyColor
            case "technology": return technologyColor
            case "philosophy": return philosophyColor
            case "economics": return economicsColor
            case "leadership": return leadershipColor
            case "entrepreneurship": return entrepreneurshipColor
            case "memoir": return memoirColor
            case "education": return educationColor
            case "art": return artColor
            case "music": return musicColor
            case "travel": return travelColor
            case "cooking": return cookingColor
            case "nutrition": return nutritionColor
            case "fitness": return fitnessColor
            case "mental health": return mentalHealthColor
            case "innovation": return innovationColor
            case "marketing": return marketingColor
            case "productivity": return productivityColor
            case "mindfulness": return mindfulnessColor
            case "biology": return biologyColor
            case "physics": return physicsColor
            case "medicine": return medicineColor
            case "environment": return environmentColor
            case "spirituality", "religion": return spiritualityColor
            case "sociology": return sociologyColor
            case "anthropology": return anthropologyColor
            case "personal development": return personalDevelopmentColor
            case "world war": return historyColor
            default: return vibrantBlue
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
        static let small = (color: Color.black.opacity(0.1), radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1))
        static let medium = (color: Color.black.opacity(0.15), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
        static let large = (color: Color.black.opacity(0.2), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
        static let nytGlow = (color: Colors.nytGold.opacity(0.3), radius: CGFloat(6), x: CGFloat(0), y: CGFloat(0))
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
                    .stroke(DesignSystem.Colors.nytGold.opacity(0.3), lineWidth: 1)
            )
            .shadow(
                color: DesignSystem.Shadow.nytGlow.color,
                radius: DesignSystem.Shadow.nytGlow.radius,
                x: DesignSystem.Shadow.nytGlow.x,
                y: DesignSystem.Shadow.nytGlow.y
            )
    }
    
    func genreSection(color: Color) -> some View {
        self
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .fill(color.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                    .stroke(color.opacity(0.2), lineWidth: 1)
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