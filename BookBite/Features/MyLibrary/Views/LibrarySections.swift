import SwiftUI

/// The newest few kept ideas as pull quotes, with "See all" to the full Notebook.
struct NotebookPreview: View {
    let ideas: [SavedIdeasStore.SavedIdea]
    var previewCount = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notebook")
                        .font(.system(size: 24, weight: .medium, design: .serif))
                    Text(ideas.count == 1 ? "1 idea kept" : "\(ideas.count) ideas kept")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 0)

                NavigationLink("See all") {
                    NotebookView()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .layoutPriority(1)
            }

            VStack(spacing: 0) {
                ForEach(Array(Notebook.newestFirst(ideas).prefix(previewCount).enumerated()), id: \.element.id) { index, idea in
                    if index > 0 {
                        Divider().padding(.leading, 15)
                    }
                    NavigationLink {
                        BookDetailView(book: idea.book)
                    } label: {
                        NotebookQuote(idea: idea)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the book")
                    .contextMenu {
                        ShareLink(item: Notebook.shareText(for: idea)) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        Button(role: .destructive) {
                            withAnimation { SavedIdeasStore.shared.remove(idea) }
                        } label: {
                            Label("Remove from notebook", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

/// What a new reader's Library will hold, shown until there is anything in it.
struct LibraryIntro: View {
    private let items: [(symbol: String, title: String, detail: String)] = [
        ("book.pages", "Continue reading", "Summaries you start, so you can pick up where you left off."),
        ("text.quote", "Notebook", "Key ideas you keep from any summary."),
        ("checkmark.circle", "Finished", "Every summary you read to the end."),
        ("bookmark", "Saved", "Books you bookmark for later, on all your devices."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your library fills in as you read.")
                    .font(.system(.title2, design: .serif, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Open any book from Discover or Search to begin.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 18) {
                ForEach(items, id: \.title) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Image(systemName: item.symbol)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                            Text(item.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.primary).frame(height: 1)
        }
        .padding(.horizontal, 20)
    }
}
