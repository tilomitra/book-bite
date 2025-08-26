import SwiftUI

struct EnhancedBookCover: View {
    let coverURL: String?
    @State private var isLoading = true
    
    private var placeholderView: some View {
        BookPlaceholderView.flexible(
            cornerRadius: 6,
            showLoading: isLoading
        )
    }
    
    var body: some View {
        AsyncImage(url: URL.bookCover(from: coverURL)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
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
}