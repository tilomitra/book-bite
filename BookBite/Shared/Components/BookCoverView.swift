import SwiftUI

struct BookCoverView: View {
    let coverURL: String?
    let size: CoverSize
    
    enum CoverSize {
        case small
        case medium
        case large
        
        var dimensions: (width: CGFloat, height: CGFloat) {
            switch self {
            case .small:
                return (60, 90)
            case .medium:
                return (100, 150)
            case .large:
                return (150, 225)
            }
        }
    }
    
    private var placeholderView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.8),
                            Color.purple.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Image(systemName: "book.fill")
                .font(.system(size: size.dimensions.width * 0.4))
                .foregroundColor(.white.opacity(0.9))
        }
    }
    
    var body: some View {
        AsyncImage(url: coverURL != nil ? URL(string: httpsURL) : nil) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure(_):
                placeholderView
            case .empty:
                placeholderView
            @unknown default:
                placeholderView
            }
        }
        .frame(width: size.dimensions.width, height: size.dimensions.height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    private var httpsURL: String {
        guard let coverURL = coverURL else { return "" }
        // Convert HTTP Google Books URLs to HTTPS
        if coverURL.hasPrefix("http://books.google.com") {
            return coverURL.replacingOccurrences(of: "http://", with: "https://")
        }
        return coverURL
    }
}