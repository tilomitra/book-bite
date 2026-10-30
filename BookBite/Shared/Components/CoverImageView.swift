import SwiftUI

/// A cover from `CoverImageLoader`. An image already in memory shows in the first frame, with no placeholder.
struct CoverImageView<Placeholder: View, Failure: View>: View {
    let coverURL: String?
    /// The width it's shown at, in points
    let width: CGFloat
    var contentMode: ContentMode = .fill
    @ViewBuilder let placeholder: () -> Placeholder
    /// Shown when there is no cover, or it can't be loaded
    @ViewBuilder let failure: () -> Failure

    @State private var image: UIImage?
    @State private var didFail = false

    init(
        coverURL: String?,
        width: CGFloat,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.coverURL = coverURL
        self.width = width
        self.contentMode = contentMode
        self.placeholder = placeholder
        self.failure = failure
        _image = State(initialValue: Self.memoryImage(coverURL, width))
    }

    private static func memoryImage(_ coverURL: String?, _ width: CGFloat) -> UIImage? {
        guard let coverURL else { return nil }
        return CoverImageLoader.shared.placeholderImage(for: coverURL, pixelWidth: CoverImageLoader.pixelWidth(forPoints: width))
    }

    private var url: String? {
        coverURL?.isEmpty == false ? coverURL : nil
    }

    private var loadID: String {
        "\(CoverImageLoader.pixelWidth(forPoints: width))|\(coverURL ?? "")"
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if url == nil || didFail {
                failure()
            } else {
                placeholder()
            }
        }
        // Also when the same view gets another book, or a larger size
        .task(id: loadID) {
            didFail = false
            guard let url else {
                image = nil
                return
            }
            let pixelWidth = CoverImageLoader.pixelWidth(forPoints: width)
            let shown = CoverImageLoader.shared.placeholderImage(for: url, pixelWidth: pixelWidth)
            if shown == nil { image = nil } else if image !== shown { image = shown }
            let loaded = await CoverImageLoader.shared.image(for: url, pixelWidth: pixelWidth)
            guard !Task.isCancelled else { return }
            if let loaded {
                if loaded !== image { image = loaded }
            } else if image == nil {
                didFail = true
            }
        }
    }
}
