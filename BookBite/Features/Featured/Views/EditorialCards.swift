import SwiftUI

// Editorial cards that break up Discover's shelves: a spotlight on one book, a passage
// from one summary, and a short list of books with their hooks. Colour comes from the covers only.

/// The cover's average colour, or the typographic cover's cloth while it loads or when there is no image.
private struct CoverTintModifier: ViewModifier {
    let book: Book
    @Binding var tint: Color

    func body(content: Content) -> some View {
        content.task(id: book.id) {
            if let color = await CoverTint.color(for: book.coverAssetName) {
                withAnimation(.easeOut(duration: 0.3)) { tint = color }
            }
        }
    }
}

private extension View {
    func coverTint(of book: Book, into tint: Binding<Color>) -> some View {
        modifier(CoverTintModifier(book: book, tint: tint))
    }
}

/// Small caps label above a card's title
private struct Eyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1.2)
    }
}

/// One book, large: the cover on a wash of its own colour, then the title and the hook.
struct SpotlightCard: View {
    let highlight: Highlight
    @Namespace private var zoom
    @State private var tint: Color

    init(highlight: Highlight) {
        self.highlight = highlight
        _tint = State(initialValue: Color(TypographicCover.cloth(for: highlight.book.title)))
    }

    private var book: Book { highlight.book }

    /// First category without its sub-path ("Body, Mind & Spirit / General" → "Body, Mind & Spirit")
    private var genre: String? {
        book.categories.first?.components(separatedBy: " / ").first
    }

    var body: some View {
        NavigationLink {
            BookDetailView(book: book)
                .navigationTransition(.zoom(sourceID: book.id, in: zoom))
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                EditorialCover(book: book, width: 150)
                    .zoomSource(id: book.id, in: zoom)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                    .padding(.bottom, 28)

                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: genre.map { "In focus · \($0)" } ?? "In focus")
                        .foregroundStyle(.white.opacity(0.7))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.shelfTitle)
                            .font(.system(size: 28, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                        Text(book.formattedAuthors)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    if let hook = highlight.hook {
                        Text(hook)
                            .font(.system(size: 17, design: .serif))
                            .lineSpacing(2)
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.top, 4)
                    }

                    HStack(spacing: 6) {
                        Text("Read the summary")
                        Image(systemName: "arrow.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 8)
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                // Darker towards the bottom so white text reads on light covers too
                LinearGradient(
                    colors: [tint, tint.mix(with: .black, by: 0.45), tint.mix(with: .black, by: 0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .coverTint(of: book, into: $tint)
        .padding(.horizontal, 20)
    }
}

/// One key idea from one summary, set large like a pull quote, on a light wash of the cover colour.
struct PassageCard: View {
    let highlight: Highlight
    @Namespace private var zoom
    @State private var tint: Color

    init(highlight: Highlight) {
        self.highlight = highlight
        _tint = State(initialValue: Color(TypographicCover.cloth(for: highlight.book.title)))
    }

    private var book: Book { highlight.book }

    var body: some View {
        NavigationLink {
            BookDetailView(book: book)
                .navigationTransition(.zoom(sourceID: book.id, in: zoom))
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                Text("“")
                    .font(.system(size: 72, weight: .bold, design: .serif))
                    .foregroundStyle(tint)
                    .frame(height: 40, alignment: .top)
                    .accessibilityHidden(true)

                Eyebrow(text: highlight.ideaLabel ?? "From the summary")
                    .foregroundStyle(.secondary)

                Text(highlight.ideaText)
                    .font(.system(size: 24, design: .serif))
                    .lineSpacing(4)
                    .foregroundStyle(.primary)

                HStack(spacing: 12) {
                    EditorialCover(book: book, width: 40)
                        .zoomSource(id: book.id, in: zoom)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.shelfTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(book.shelfAuthor)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .coverTint(of: book, into: $tint)
        .padding(.horizontal, 20)
    }
}

/// A heading and a few books as rows: cover, title, author and the one-sentence hook.
struct QuickBitesCard: View {
    let title: String
    let caption: String
    let highlights: [Highlight]
    @Namespace private var zoom

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 24, weight: .medium, design: .serif))
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                ForEach(Array(highlights.enumerated()), id: \.element.id) { index, highlight in
                    NavigationLink {
                        BookDetailView(book: highlight.book)
                            .navigationTransition(.zoom(sourceID: highlight.book.id, in: zoom))
                    } label: {
                        row(highlight)
                    }
                    .buttonStyle(.plain)

                    if index < highlights.count - 1 {
                        Divider().padding(.leading, 80)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func row(_ highlight: Highlight) -> some View {
        HStack(alignment: .top, spacing: 16) {
            EditorialCover(book: highlight.book, width: 64)
                .zoomSource(id: highlight.book.id, in: zoom)

            VStack(alignment: .leading, spacing: 4) {
                Text(highlight.book.shelfTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(highlight.book.shelfAuthor)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let hook = highlight.hook {
                    Text(hook)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}
