import SwiftUI

/// Book cover view that checks offline storage first before loading from network
struct OfflineAwareBookCoverView: View {
    let bookId: String
    let coverURL: String?
    let size: BookCoverView.CoverSize

    @State private var offlineImage: UIImage?

    private var placeholderView: some View {
        BookPlaceholderView.custom(
            width: size.dimensions.width,
            height: size.dimensions.height,
            cornerRadius: 8
        )
    }

    var body: some View {
        Group {
            if let offlineImage = offlineImage {
                // Use offline image if available
                Image(uiImage: offlineImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // Fall back to network loading
                AsyncImage(url: URL.bookCover(from: coverURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .failure:
                        placeholderView
                    case .empty:
                        placeholderView
                    @unknown default:
                        placeholderView
                    }
                }
            }
        }
        .frame(width: size.dimensions.width, height: size.dimensions.height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        .onAppear {
            loadOfflineImage()
        }
    }

    private func loadOfflineImage() {
        offlineImage = OfflineStorageService.shared.getOfflineCoverImage(bookId: bookId)
    }
}
