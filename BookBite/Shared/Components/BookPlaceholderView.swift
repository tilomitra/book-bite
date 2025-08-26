import SwiftUI

/// Consistent black and white placeholder for book covers throughout the app
struct BookPlaceholderView: View {
    let width: CGFloat?
    let height: CGFloat?
    let cornerRadius: CGFloat
    let showLoading: Bool
    
    init(width: CGFloat? = nil, height: CGFloat? = nil, cornerRadius: CGFloat = 8, showLoading: Bool = false) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.showLoading = showLoading
    }
    
    var body: some View {
        ZStack {
            // Black and white gradient background
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.1),
                            Color.black.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )
            
            // Book icon
            if showLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(Color.black.opacity(0.4))
            } else {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 24)) // Fixed reasonable size
                    .foregroundColor(Color.black.opacity(0.3))
            }
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Convenience Initializers
extension BookPlaceholderView {
    /// Small placeholder (60x90)
    static func small(showLoading: Bool = false) -> BookPlaceholderView {
        BookPlaceholderView(width: 60, height: 90, cornerRadius: 6, showLoading: showLoading)
    }
    
    /// Medium placeholder (100x150)
    static func medium(showLoading: Bool = false) -> BookPlaceholderView {
        BookPlaceholderView(width: 100, height: 150, cornerRadius: 8, showLoading: showLoading)
    }
    
    /// Large placeholder (150x225)
    static func large(showLoading: Bool = false) -> BookPlaceholderView {
        BookPlaceholderView(width: 150, height: 225, cornerRadius: 12, showLoading: showLoading)
    }
    
    /// Custom size placeholder
    static func custom(width: CGFloat? = nil, height: CGFloat? = nil, cornerRadius: CGFloat = 8, showLoading: Bool = false) -> BookPlaceholderView {
        BookPlaceholderView(width: width, height: height, cornerRadius: cornerRadius, showLoading: showLoading)
    }
    
    /// Flexible placeholder that fills available space
    static func flexible(cornerRadius: CGFloat = 8, showLoading: Bool = false) -> BookPlaceholderView {
        BookPlaceholderView(width: nil, height: nil, cornerRadius: cornerRadius, showLoading: showLoading)
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 16) {
            BookPlaceholderView.small()
            BookPlaceholderView.medium()
            BookPlaceholderView.large()
        }
        
        HStack(spacing: 16) {
            BookPlaceholderView.small(showLoading: true)
            BookPlaceholderView.medium(showLoading: true)
            BookPlaceholderView.large(showLoading: true)
        }
    }
    .padding()
}