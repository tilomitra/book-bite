import SwiftUI
import UIKit

/// A key idea typeset as a quote, for sharing as an image: the idea in serif on warm paper with a
/// wash of the cover's colour, the book's cover, title and author, and a discreet wordmark.
/// Rendered off screen with `ImageRenderer`, so it uses fixed sizes and a fixed light appearance
/// (it must look the same whatever the sharer's text size or dark mode) and a pre-loaded cover image
/// (`AsyncImage` doesn't load inside a renderer).
struct IdeaShareCard: View {
    let idea: String
    let book: Book
    let tint: Color
    /// The downloaded cover; nil draws a `TypographicCover`
    let cover: UIImage?

    static let width: CGFloat = 360
    /// 4:5, the shape most feeds show uncropped. Long ideas make the card taller.
    static let minHeight: CGFloat = 450

    private let ink = Color(red: 0.11, green: 0.10, blue: 0.09)
    private let paper = Color(red: 0.98, green: 0.97, blue: 0.95)

    /// Shorter ideas get larger type, so every card fills its space without crowding.
    private var ideaSize: CGFloat {
        switch idea.count {
        case ..<110: return 27
        case ..<200: return 23
        case ..<320: return 20
        default: return 17
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\u{201C}")
                .font(.system(size: 64, weight: .regular, design: .serif))
                .foregroundStyle(tint)
                .frame(height: 40, alignment: .top)
                .padding(.bottom, 10)

            Text(KeyIdeaText.attributed(idea))
                .font(.system(size: ideaSize, weight: .regular, design: .serif))
                .lineSpacing(ideaSize * 0.28)
                .tracking(-0.2)
                .foregroundStyle(ink)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 32)

            Rectangle()
                .fill(ink.opacity(0.15))
                .frame(height: 0.5)
                .padding(.bottom, 16)

            HStack(alignment: .center, spacing: 12) {
                coverView
                    .frame(width: 36, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(book.shelfTitle)
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundStyle(ink)
                        .lineLimit(2)
                    Text(book.shelfAuthor)
                        .font(.system(size: 12))
                        .foregroundStyle(ink.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Text("BookBite")
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .tracking(0.3)
                    .foregroundStyle(ink.opacity(0.45))
            }
        }
        .padding(32)
        .frame(width: Self.width, alignment: .leading)
        .frame(minHeight: Self.minHeight, alignment: .top)
        .background {
            ZStack {
                paper
                LinearGradient(
                    colors: [tint.opacity(0.32), tint.opacity(0.08), tint.opacity(0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .environment(\.colorScheme, .light)
        .environment(\.dynamicTypeSize, .large)
    }

    @ViewBuilder
    private var coverView: some View {
        if let cover {
            Image(uiImage: cover)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            TypographicCover(title: book.title, author: book.formattedAuthors)
        }
    }

    /// Renders the card at 3x (1080 px wide).
    @MainActor
    static func render(idea: String, book: Book, tint: Color, cover: UIImage?) -> UIImage? {
        let renderer = ImageRenderer(content: IdeaShareCard(idea: idea, book: book, tint: tint, cover: cover))
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// Downloads the cover for the card. Usually served from URLCache: the page just showed it.
    static func loadCover(for book: Book) async -> UIImage? {
        guard let url = URL.bookCover(from: book.coverAssetName),
              let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }
}

/// A rendered quote image, shared as a PNG.
struct IdeaQuoteImage: Transferable {
    let image: UIImage
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            guard let data = item.image.pngData() else { throw CocoaError(.fileWriteUnknown) }
            return data
        }
        .suggestedFileName { $0.fileName }
    }
}

/// Key ideas often start with a short lead-in ("The Hero's Journey: Bilbo's transformation…").
/// Set the lead in bold so the idea reads like a headed paragraph.
enum KeyIdeaText {
    static func split(_ text: String) -> (lead: String?, rest: String) {
        guard let range = text.range(of: ": ") else { return (nil, text) }
        let lead = String(text[..<range.lowerBound])
        let rest = String(text[range.upperBound...])
        // Only a short phrase counts as a lead, not a clause that happens to contain a colon
        guard (2...60).contains(lead.count), !lead.contains("."), !rest.isEmpty else { return (nil, text) }
        return (lead, rest)
    }

    static func attributed(_ text: String) -> AttributedString {
        let parts = split(text)
        guard let lead = parts.lead else { return AttributedString(text) }
        var head = AttributedString(lead + ": ")
        head.inlinePresentationIntent = .stronglyEmphasized
        return head + AttributedString(parts.rest)
    }
}

#Preview {
    IdeaShareCard(
        idea: "The Hero's Journey: Bilbo's transformation from a reluctant hobbit to a courageous hero.",
        book: Book(id: "preview", title: "The Hobbit", authors: ["J. R. R. Tolkien"]),
        tint: Color(red: 0.6, green: 0.35, blue: 0.2),
        cover: nil
    )
}
