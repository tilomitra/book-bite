import SwiftUI

struct EnhancedBookCover: View {
    let coverURL: String?
    @State private var isLoading = true
    
    private var placeholderView: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(UIColor.systemGray5),
                            Color(UIColor.systemGray6)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(.secondary)
            } else {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
    }
    
    var body: some View {
        AsyncImage(url: coverURL != nil ? URL(string: httpsURL) : nil) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .onAppear { isLoading = false }
            case .failure(_):
                placeholderView
                    .onAppear { isLoading = false }
            case .empty:
                placeholderView
            @unknown default:
                placeholderView
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(UIColor.separator).opacity(0.2), lineWidth: 0.5)
        )
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