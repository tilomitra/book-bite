import SwiftUI

/// Discover tab: the idea of the day, then one shelf of books per genre.
struct FeaturedBooksView: View {
    @StateObject private var viewModel: FeaturedBooksViewModel

    init() {
        _viewModel = StateObject(wrappedValue: FeaturedBooksViewModel(bookRepository: DependencyContainer.shared.bookRepository))
    }

    var body: some View {
        // The header stays visible in every state: the navigation bar is hidden, so it is the screen's title
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30) {
                EditorialHeader(title: "Discover", caption: {
                    Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                })

                if viewModel.isLoading && viewModel.booksByGenre.isEmpty {
                    ConsistentLoadingView(style: .primary, message: "Loading books...")
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if let error = viewModel.error, viewModel.booksByGenre.isEmpty {
                    ContentUnavailableView {
                        Label("Can't load books", systemImage: "wifi.slash")
                    } description: {
                        Text(error.localizedDescription)
                    } actions: {
                        Button("Try Again") {
                            Task { await viewModel.loadFeaturedBooks() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 40)
                } else if viewModel.showEmptyState {
                    ContentUnavailableView("No books yet", systemImage: "books.vertical")
                        .padding(.top, 40)
                } else {
                    if let dailyIdea = viewModel.dailyIdea {
                        DailyIdeaCard(dailyIdea: dailyIdea)
                    }

                    ForEach(viewModel.booksByGenre, id: \.genre) { shelf in
                        BookShelf(title: shelf.genre, books: shelf.books)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("Discover")
        .editorialNavigationBar()
        .refreshable {
            await viewModel.loadFeaturedBooks()
        }
    }
}

/// A titled, horizontally scrolling row of books.
struct BookShelf: View {
    let title: String
    let books: [Book]

    private let previewCount = 12
    @Namespace private var zoom

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 24, weight: .medium, design: .serif))
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                if books.count > previewCount {
                    NavigationLink("See all") {
                        BookGridView(title: title, books: books)
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(books.prefix(previewCount)) { book in
                        NavigationLink {
                            BookDetailView(book: book)
                                .navigationTransition(.zoom(sourceID: book.id, in: zoom))
                        } label: {
                            ShelfBookCard(book: book, coverWidth: 118, zoomNamespace: zoom)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                // Room for the cover shadows, which a horizontal ScrollView would otherwise clip
                .padding(.vertical, 12)
            }
            .padding(.vertical, -12)
        }
    }
}

/// Cover, title and author. Nothing else.
struct ShelfBookCard: View {
    let book: Book
    let coverWidth: CGFloat
    /// When set, the cover is the origin of the zoom transition to the book page (source id = book id).
    var zoomNamespace: Namespace.ID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorialCover(coverURL: book.coverAssetName, width: coverWidth)
                .zoomSource(id: book.id, in: zoomNamespace)

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(book.formattedAuthors)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: coverWidth, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// A 2:3 book cover with a book-like shape (tighter corners at the spine) and a soft shadow.
struct EditorialCover: View {
    let coverURL: String?
    let width: CGFloat

    private var shape: UnevenRoundedRectangle {
        let spine = max(2, width * 0.025)
        let edge = max(3, width * 0.05)
        return UnevenRoundedRectangle(
            topLeadingRadius: spine,
            bottomLeadingRadius: spine,
            bottomTrailingRadius: edge,
            topTrailingRadius: edge
        )
    }

    var body: some View {
        AsyncImage(url: URL.bookCover(from: coverURL)) { phase in
            if case .success(let image) = phase {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                BookPlaceholderView.flexible(cornerRadius: 0, showLoading: false)
            }
        }
        .frame(width: width, height: width * 1.5)
        .clipShape(shape)
        .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.16), radius: 1, y: 1)
        .shadow(color: .black.opacity(width > 60 ? 0.18 : 0.08), radius: width > 60 ? 10 : 4, y: width > 60 ? 8 : 2)
    }
}

/// All books of one shelf as a grid.
struct BookGridView: View {
    let title: String
    let books: [Book]

    private let columns = [GridItem(.adaptive(minimum: 104, maximum: 140), spacing: 16, alignment: .top)]
    @Namespace private var zoom

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 28) {
                ForEach(books) { book in
                    NavigationLink {
                        BookDetailView(book: book)
                            .navigationTransition(.zoom(sourceID: book.id, in: zoom))
                    } label: {
                        ShelfBookCard(book: book, coverWidth: 104, zoomNamespace: zoom)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}
