import SwiftUI

struct StarRatingView: View {
    let rating: Double
    let maxRating: Int = 5
    let starSize: CGFloat
    let spacing: CGFloat
    
    init(rating: Double, starSize: CGFloat = 16, spacing: CGFloat = 2) {
        self.rating = rating
        self.starSize = starSize
        self.spacing = spacing
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...maxRating, id: \.self) { index in
                starImage(for: index)
                    .foregroundColor(starColor(for: index))
                    .font(.system(size: starSize))
            }
        }
    }
    
    private func starImage(for index: Int) -> Image {
        let threshold = Double(index)
        
        if rating >= threshold {
            return Image(systemName: "star.fill")
        } else if rating >= threshold - 0.5 {
            return Image(systemName: "star.leadinghalf.filled")
        } else {
            return Image(systemName: "star")
        }
    }
    
    private func starColor(for index: Int) -> Color {
        let threshold = Double(index)
        
        if rating >= threshold {
            return .orange
        } else if rating >= threshold - 0.5 {
            return .orange
        } else {
            return .gray.opacity(0.3)
        }
    }
}

struct BookRatingDisplayView: View {
    let rating: BookRating
    let showSource: Bool
    let compact: Bool
    
    init(rating: BookRating, showSource: Bool = true, compact: Bool = false) {
        self.rating = rating
        self.showSource = showSource
        self.compact = compact
    }
    
    var body: some View {
        if compact {
            compactView
        } else {
            fullView
        }
    }
    
    private var compactView: some View {
        HStack(spacing: 8) {
            StarRatingView(rating: rating.average, starSize: 14)
            
            Text(rating.formattedAverage)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("(\(rating.formattedCount))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var fullView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                StarRatingView(rating: rating.average, starSize: 18)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(rating.formattedAverage)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("\(rating.formattedCount) ratings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if showSource {
                Text("via \(rating.source)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .opacity(0.8)
            }
            
            if let distribution = rating.distribution {
                RatingDistributionView(distribution: distribution, totalCount: rating.count)
            }
        }
        .padding(.vertical, 4)
    }
}

struct RatingDistributionView: View {
    let distribution: BookRating.RatingDistribution
    let totalCount: Int
    
    var body: some View {
        VStack(spacing: 4) {
            ForEach([5, 4, 3, 2, 1], id: \.self) { star in
                HStack(spacing: 8) {
                    Text("\(star)")
                        .font(.caption2)
                        .frame(width: 12)
                    
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    
                    ProgressView(value: Double(count(for: star)), total: Double(totalCount))
                        .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                        .frame(height: 4)
                    
                    Text("\(count(for: star))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 24, alignment: .trailing)
                }
            }
        }
        .padding(.top, 8)
    }
    
    private func count(for star: Int) -> Int {
        switch star {
        case 5: return distribution.five ?? 0
        case 4: return distribution.four ?? 0
        case 3: return distribution.three ?? 0
        case 2: return distribution.two ?? 0
        case 1: return distribution.one ?? 0
        default: return 0
        }
    }
}

// Loading state view
struct RatingLoadingView: View {
    let compact: Bool
    
    init(compact: Bool = false) {
        self.compact = compact
    }
    
    var body: some View {
        if compact {
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    ForEach(0..<5) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 14, height: 14)
                    }
                }
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 30, height: 16)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        ForEach(0..<5) { _ in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 18, height: 18)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 20)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 80, height: 14)
                    }
                    
                    Spacer()
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        BookRatingDisplayView(
            rating: BookRating(
                average: 4.3,
                count: 1234,
                distribution: BookRating.RatingDistribution(
                    one: 12,
                    two: 23,
                    three: 156,
                    four: 478,
                    five: 565
                ),
                source: "Open Library"
            )
        )
        
        BookRatingDisplayView(
            rating: BookRating(
                average: 4.7,
                count: 892,
                distribution: nil,
                source: "Open Library"
            ),
            compact: true
        )
        
        RatingLoadingView()
        
        RatingLoadingView(compact: true)
    }
    .padding()
}