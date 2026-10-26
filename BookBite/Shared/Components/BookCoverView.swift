import SwiftUI

struct BookCoverView: View {
    let coverURL: String?
    let size: CoverSize
    /// When set, a missing or broken image shows a `TypographicCover` instead of the placeholder.
    var title: String? = nil
    var author: String? = nil
    
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
        BookPlaceholderView.custom(
            width: size.dimensions.width,
            height: size.dimensions.height,
            cornerRadius: 8
        )
    }
    
    var body: some View {
        AsyncImage(url: URL.bookCover(from: coverURL)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .empty where URL.bookCover(from: coverURL) != nil:
                placeholderView
            case .failure(_), .empty:
                if let title {
                    TypographicCover(title: title, author: author ?? "")
                } else {
                    placeholderView
                }
            @unknown default:
                placeholderView
            }
        }
        .frame(width: size.dimensions.width, height: size.dimensions.height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

extension BookCoverView {
    init(book: Book, size: CoverSize) {
        self.init(coverURL: book.coverAssetName, size: size, title: book.title, author: book.formattedAuthors)
    }
}
