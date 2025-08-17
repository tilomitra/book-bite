import SwiftUI

struct EnhancedBookCard: View {
    let book: Book
    let style: BookCardStyle
    
    @State private var isPressed = false
    @State private var showShimmer = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Book Cover with enhanced styling
            EnhancedBookCoverView(book: book, style: style)
            
            // Book Information
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                // Title
                Text(book.title)
                    .font(style.titleFont)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Author
                Text(book.formattedAuthors)
                    .font(style.authorFont)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(1)
                
                // NYT Bestseller Badge
                if book.isNYTBestseller == true {
                    NYTBestsellerBadge(book: book)
                        .transition(.scale.combined(with: .opacity))
                }
                
                // Genre Tags
                if !book.categories.isEmpty && style.showGenreTags {
                    GenreTagsView(categories: book.categories, maxTags: 2)
                        .transition(.slide.combined(with: .opacity))
                }
            }
            .frame(width: style.cardWidth, alignment: .leading)
        }
        .frame(width: style.cardWidth)
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(DesignSystem.Colors.cardBackground)
                .shadow(
                    color: isPressed ? 
                        DesignSystem.Shadow.large.color : 
                        DesignSystem.Shadow.medium.color,
                    radius: isPressed ? 
                        DesignSystem.Shadow.large.radius : 
                        DesignSystem.Shadow.medium.radius,
                    x: 0,
                    y: isPressed ? 6 : 2
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .rotation3DEffect(
            .degrees(isPressed ? 2 : 0),
            axis: (x: 1, y: 0, z: 0)
        )
        .animation(DesignSystem.Animations.spring, value: isPressed)
        .onTapGesture {
            withAnimation(DesignSystem.Animations.bouncy) {
                isPressed = true
            }
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(DesignSystem.Animations.bouncy) {
                    isPressed = false
                }
            }
        }
        .onAppear {
            // Delayed shimmer effect
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.5...2.0)) {
                withAnimation(DesignSystem.Animations.gentle) {
                    showShimmer = true
                }
            }
        }
    }
}

struct EnhancedBookCoverView: View {
    let book: Book
    let style: BookCardStyle
    
    @State private var imageLoaded = false
    
    var body: some View {
        ZStack {
            // Placeholder with gradient
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.vibrantBlue.opacity(0.3),
                            DesignSystem.Colors.vibrantPurple.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: style.coverWidth, height: style.coverHeight)
                .opacity(imageLoaded ? 0 : 1)
                .animation(DesignSystem.Animations.smooth, value: imageLoaded)
            
            // Book Cover Image
            AsyncImage(url: book.coverAssetName != nil ? URL(string: book.coverAssetName!) : nil) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: style.coverWidth, height: style.coverHeight)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                    .onAppear {
                        withAnimation(DesignSystem.Animations.smooth) {
                            imageLoaded = true
                        }
                    }
            } placeholder: {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                    .fill(DesignSystem.Colors.surface)
                    .frame(width: style.coverWidth, height: style.coverHeight)
                    .overlay(
                        Image(systemName: "book.closed")
                            .font(.system(size: 24))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    )
                    .shimmerEffect()
            }
            
            // NYT Bestseller Corner Badge
            if book.isNYTBestseller == true {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "star.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(
                                Circle()
                                    .fill(DesignSystem.Colors.nytGold)
                                    .shadow(
                                        color: DesignSystem.Colors.nytGold.opacity(0.3),
                                        radius: 4,
                                        x: 0,
                                        y: 2
                                    )
                            )
                            .offset(x: 4, y: -4)
                    }
                    Spacer()
                }
            }
        }
    }
}

struct NYTBestsellerBadge: View {
    let book: Book
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "star.fill")
                .font(DesignSystem.Typography.badge)
                .foregroundColor(.white)
            
            if let rank = book.nytRank {
                Text("NYT #\(rank)")
                    .font(DesignSystem.Typography.badge)
                    .foregroundColor(.white)
            } else {
                Text("NYT")
                    .font(DesignSystem.Typography.badge)
                    .foregroundColor(.white)
            }
            
            if let weeks = book.nytWeeksOnList, weeks > 1 {
                Text("• \(weeks)w")
                    .font(DesignSystem.Typography.badge)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.nytGold,
                            DesignSystem.Colors.nytGoldAccent
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(
                    color: DesignSystem.Colors.nytGold.opacity(0.3),
                    radius: 4,
                    x: 0,
                    y: 2
                )
        )
    }
}

struct GenreTagsView: View {
    let categories: [String]
    let maxTags: Int
    
    var displayCategories: [String] {
        Array(categories.prefix(maxTags))
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            ForEach(displayCategories, id: \.self) { category in
                Text(category)
                    .font(DesignSystem.Typography.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.genreColor(for: category))
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.genreColor(for: category).opacity(0.15))
                    )
            }
        }
    }
}

// MARK: - Book Card Styles
enum BookCardStyle {
    case compact
    case featured
    case detailed
    
    var cardWidth: CGFloat {
        switch self {
        case .compact: return 140
        case .featured: return 160
        case .detailed: return 180
        }
    }
    
    var coverWidth: CGFloat {
        switch self {
        case .compact: return 120
        case .featured: return 140
        case .detailed: return 160
        }
    }
    
    var coverHeight: CGFloat {
        switch self {
        case .compact: return 180
        case .featured: return 210
        case .detailed: return 240
        }
    }
    
    var titleFont: Font {
        switch self {
        case .compact: return DesignSystem.Typography.caption1
        case .featured: return DesignSystem.Typography.callout
        case .detailed: return DesignSystem.Typography.headline
        }
    }
    
    var authorFont: Font {
        switch self {
        case .compact: return DesignSystem.Typography.caption2
        case .featured: return DesignSystem.Typography.caption1
        case .detailed: return DesignSystem.Typography.footnote
        }
    }
    
    var showGenreTags: Bool {
        switch self {
        case .compact: return false
        case .featured: return true
        case .detailed: return true
        }
    }
}