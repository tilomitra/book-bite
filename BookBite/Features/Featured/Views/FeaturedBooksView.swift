import SwiftUI

/// Discover tab: the idea of the day, then one shelf of books per genre.
struct FeaturedBooksView: View {
    @StateObject private var viewModel: FeaturedBooksViewModel

    init() {
        _viewModel = StateObject(wrappedValue: FeaturedBooksViewModel(bookRepository: DependencyContainer.shared.bookRepository))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.booksByGenre.isEmpty {
                ConsistentLoadingView(style: .primary, message: "Loading books...")
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
            } else if viewModel.showEmptyState {
                ContentUnavailableView("No books yet", systemImage: "books.vertical")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 32) {
                        if let dailyIdea = viewModel.dailyIdea {
                            DailyIdeaCard(dailyIdea: dailyIdea)
                        }

                        ForEach(viewModel.booksByGenre, id: \.genre) { shelf in
                            BookShelf(title: shelf.genre, books: shelf.books)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Discover")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                if books.count > previewCount {
                    NavigationLink("See all") {
                        BookGridView(title: title, books: books)
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(books.prefix(previewCount)) { book in
                        NavigationLink(destination: BookDetailView(book: book)) {
                            ShelfBookCard(book: book, coverWidth: 104)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

/// Cover, title and author. Nothing else.
struct ShelfBookCard: View {
    let book: Book
    let coverWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            EnhancedBookCover(coverURL: book.coverAssetName)
                .frame(width: coverWidth, height: coverWidth * 1.5)

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(book.formattedAuthors)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: coverWidth, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// All books of one shelf as a grid.
struct BookGridView: View {
    let title: String
    let books: [Book]

    private let columns = [GridItem(.adaptive(minimum: 104, maximum: 140), spacing: 16, alignment: .top)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                ForEach(books) { book in
                    NavigationLink(destination: BookDetailView(book: book)) {
                        ShelfBookCard(book: book, coverWidth: 104)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}
