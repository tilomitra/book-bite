import SwiftUI

struct PlayfulLoadingView: View {
    @State private var isAnimating = false
    @State private var rotation = 0.0
    @State private var scale = 1.0
    @State private var opacity = 1.0
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Animated Book Stack
            BookStackAnimation()
            
            // Loading Text with Animation
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Loading NYT Bestsellers")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("Curating the best books for you...")
                    .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .opacity(opacity)
                    .animation(
                        Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: opacity
                    )
            }
            
            // Bouncing Dots
            BouncingDotsView()
        }
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever()) {
                opacity = 0.5
            }
        }
    }
}

struct BookStackAnimation: View {
    @State private var bookOffsets: [CGFloat] = [0, 0, 0]
    @State private var bookRotations: [Double] = [0, 0, 0]
    @State private var bookScales: [CGFloat] = [1, 1, 1]
    
    let colors = [
        DesignSystem.Colors.vibrantBlue,
        DesignSystem.Colors.vibrantPurple,
        DesignSystem.Colors.vibrantPink
    ]
    
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [colors[index], colors[index].opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 80)
                    .rotationEffect(.degrees(bookRotations[index]))
                    .scaleEffect(bookScales[index])
                    .offset(
                        x: bookOffsets[index] * 20,
                        y: sin(bookOffsets[index] * .pi) * 10
                    )
                    .shadow(
                        color: colors[index].opacity(0.3),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                    .zIndex(Double(3 - index))
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        for index in 0..<3 {
            let delay = Double(index) * 0.2
            
            withAnimation(
                Animation.easeInOut(duration: 2.0)
                    .delay(delay)
                    .repeatForever(autoreverses: true)
            ) {
                bookOffsets[index] = 1.0
                bookRotations[index] = Double.random(in: -10...10)
                bookScales[index] = 0.9
            }
        }
    }
}

struct BouncingDotsView: View {
    @State private var animatingDots = [false, false, false]
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(DesignSystem.Colors.nytGold)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animatingDots[index] ? 1.3 : 0.7)
                    .opacity(animatingDots[index] ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .delay(Double(index) * 0.2)
                            .repeatForever(autoreverses: true),
                        value: animatingDots[index]
                    )
            }
        }
        .onAppear {
            for index in 0..<3 {
                animatingDots[index] = true
            }
        }
    }
}

// MARK: - Genre Loading Animation
struct GenreLoadingAnimation: View {
    let genre: String
    @State private var isAnimating = false
    
    var genreColor: Color {
        DesignSystem.Colors.genreColor(for: genre)
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Animated genre icon
            ZStack {
                Circle()
                    .fill(genreColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .opacity(isAnimating ? 0.5 : 1.0)
                
                Circle()
                    .fill(genreColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .scaleEffect(isAnimating ? 1.0 : 1.3)
                    .opacity(isAnimating ? 1.0 : 0.0)
                
                Image(systemName: genreIcon(for: genre))
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(genreColor)
                    .rotationEffect(.degrees(isAnimating ? 10 : -10))
            }
            .animation(
                Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                value: isAnimating
            )
            
            Text("Loading \(genre)")
                .font(DesignSystem.Typography.headline)
                .foregroundColor(genreColor)
                .fontWeight(.semibold)
        }
        .onAppear {
            isAnimating = true
        }
    }
    
    private func genreIcon(for genre: String) -> String {
        switch genre.lowercased() {
        case "business": return "briefcase.fill"
        case "self-help": return "heart.fill"
        case "biography": return "person.fill"
        case "science": return "atom"
        case "politics": return "building.columns.fill"
        case "health": return "cross.fill"
        case "history": return "clock.fill"
        case "psychology": return "brain.head.profile"
        default: return "book.fill"
        }
    }
}

// MARK: - Skeleton Loading Views
struct SkeletonBookCard: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Cover skeleton
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small)
                .fill(DesignSystem.Colors.surface)
                .frame(width: 140, height: 210)
                .shimmerEffect()
            
            // Title skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(DesignSystem.Colors.surface)
                .frame(width: 120, height: 16)
                .shimmerEffect()
            
            RoundedRectangle(cornerRadius: 4)
                .fill(DesignSystem.Colors.surface)
                .frame(width: 90, height: 16)
                .shimmerEffect()
            
            // Author skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(DesignSystem.Colors.surface)
                .frame(width: 80, height: 12)
                .shimmerEffect()
        }
        .padding(DesignSystem.Spacing.sm)
    }
}