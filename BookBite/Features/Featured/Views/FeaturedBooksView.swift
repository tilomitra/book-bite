import SwiftUI

/// Discover tab: the idea of the day, then an endless feed of shelves and editorial cards.
struct FeaturedBooksView: View {
    @StateObject private var viewModel: FeaturedBooksViewModel
    @ObservedObject private var readingProgress = ReadingProgressStore.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// iPad and other wide windows: the idea of the day beside Continue reading, cards three to a row
    private var isWide: Bool { horizontalSizeClass == .regular }

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

                // On-device, so it shows even while the feed loads or the server is unreachable
                if isWide {
                    wideTopRow
                } else {
                    ContinueReadingSection(entries: readingProgress.inProgress)
                }

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
                    if !isWide, let dailyIdea = viewModel.dailyIdea {
                        DailyIdeaCard(dailyIdea: dailyIdea)
                    }

                    let rows = isWide ? FeedRow.wide(viewModel.blocks) : viewModel.blocks.map(FeedRow.block)
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        rowView(row)
                            .onAppear {
                                // Start loading a few rows before the end, so scrolling doesn't stall
                                if index >= rows.count - 3 {
                                    Task { await viewModel.loadMore() }
                                }
                            }
                    }

                    if viewModel.canLoadMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .onAppear {
                                Task { await viewModel.loadMore() }
                            }
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

    /// The idea of the day and Continue reading side by side; either one alone takes the full width
    @ViewBuilder
    private var wideTopRow: some View {
        let entries = readingProgress.inProgress
        if viewModel.dailyIdea != nil || !entries.isEmpty {
            HStack(alignment: .top, spacing: 16) {
                if let dailyIdea = viewModel.dailyIdea {
                    DailyIdeaCard(dailyIdea: dailyIdea)
                        .frame(maxWidth: .infinity, alignment: .top)
                }
                if !entries.isEmpty {
                    ContinueReadingSection(entries: entries)
                        .frame(maxWidth: .infinity, alignment: .top)
                }
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: FeedRow) -> some View {
        switch row {
        case .block(let block):
            blockView(block)
        case .cards(let cards):
            // Always three columns, so a row still filling up doesn't stretch its first card
            HStack(alignment: .top, spacing: 0) {
                ForEach(0..<FeedRow.cardsPerRow, id: \.self) { column in
                    Group {
                        if column < cards.count {
                            blockView(cards[column])
                        } else {
                            Color.clear.frame(height: 1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .padding(.horizontal, 10)
        }
    }

    @ViewBuilder
    private func blockView(_ block: DiscoverBlock) -> some View {
        switch block {
        case .shelf(let title, let books):
            BookShelf(heading: title, books: books)
        case .spotlight(let highlight):
            SpotlightCard(highlight: highlight)
        case .passage(let highlight):
            PassageCard(highlight: highlight)
        case .quickBites(let title, let caption, let highlights):
            QuickBitesCard(title: title, caption: caption, highlights: highlights)
        }
    }
}

/// One row of the Discover feed: a block as is, or on wide screens up to three editorial cards side by side.
enum FeedRow: Identifiable {
    case block(DiscoverBlock)
    case cards([DiscoverBlock])

    static let cardsPerRow = 3

    var id: String {
        switch self {
        case .block(let block): return block.id
        // Named after its first card, which never changes, so the row keeps its identity as it fills
        case .cards(let cards): return "cards:\(cards.first?.id ?? "")"
        }
    }

    /// Shelves stay full width. Each card row is placed where its first card was and takes the next
    /// cards from further down, so rows already on screen never move when more blocks load.
    static func wide(_ blocks: [DiscoverBlock]) -> [FeedRow] {
        var rows: [FeedRow] = []
        var openRow: Int?
        for block in blocks {
            if case .shelf = block {
                rows.append(.block(block))
                continue
            }
            if let index = openRow, case .cards(let cards) = rows[index] {
                let filled = cards + [block]
                rows[index] = .cards(filled)
                if filled.count == cardsPerRow { openRow = nil }
            } else {
                rows.append(.cards([block]))
                openRow = rows.count - 1
            }
        }
        return rows
    }
}

/// A titled, horizontally scrolling row of books.
struct BookShelf: View {
    let title: String
    /// Small caps line above the title, e.g. "More like" over a book title
    var eyebrow: String? = nil
    /// Quiet line under the title, e.g. "12 finished this year"
    var caption: String? = nil
    let books: [Book]

    static let previewCount = 12
    private var previewCount: Int { Self.previewCount }
    @Namespace private var zoom
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Splits a server heading like "More like Never Eat Alone" into eyebrow and title,
    /// so the long book title gets the full width and wraps instead of truncating.
    init(heading: String, books: [Book]) {
        let prefix = "More like "
        if heading.hasPrefix(prefix) {
            self.init(title: String(heading.dropFirst(prefix.count)), eyebrow: "More like", books: books)
        } else {
            self.init(title: heading, books: books)
        }
    }

    init(title: String, eyebrow: String? = nil, caption: String? = nil, books: [Book]) {
        self.title = title
        self.eyebrow = eyebrow
        self.caption = caption
        self.books = books
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                if let eyebrow {
                    HStack(alignment: .firstTextBaseline) {
                        Text(eyebrow.uppercased())
                            .font(.caption.weight(.semibold))
                            .tracking(1.2)
                            .foregroundColor(.secondary)
                        Spacer()
                        seeAllLink
                    }
                    Text(title)
                        .font(.system(size: 22, weight: .medium, design: .serif))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(title)
                            .font(.system(size: 24, weight: .medium, design: .serif))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        seeAllLink
                            .layoutPriority(1)
                    }
                }
                if let caption {
                    Text(caption)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isHeader)
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(books.prefix(previewCount)) { book in
                        NavigationLink {
                            BookDetailView(book: book)
                                .navigationTransition(.zoom(sourceID: book.id, in: zoom))
                        } label: {
                            ShelfBookCard(book: book, coverWidth: horizontalSizeClass == .regular ? 136 : 118, zoomNamespace: zoom)
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

    @ViewBuilder
    private var seeAllLink: some View {
        if books.count > previewCount {
            NavigationLink("See all") {
                BookGridView(title: eyebrow.map { "\($0) \(title)" } ?? title, books: books)
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
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
            EditorialCover(book: book, width: coverWidth)
                .zoomSource(id: book.id, in: zoomNamespace)

            VStack(alignment: .leading, spacing: 3) {
                // Main title only (subtitles live on the cover), wrapped, never cut off
                Text(book.shelfTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(book.shelfAuthor)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: coverWidth, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// A 2:3 book cover with a book-like shape (tighter corners at the spine) and a soft shadow.
/// Without a cover image (none stored, or it fails to load) it shows a `TypographicCover`
/// when it knows the title.
struct EditorialCover: View {
    let coverURL: String?
    let width: CGFloat
    var title: String? = nil
    var author: String? = nil

    init(coverURL: String?, width: CGFloat, title: String? = nil, author: String? = nil) {
        self.coverURL = coverURL
        self.width = width
        self.title = title
        self.author = author
    }

    init(book: Book, width: CGFloat) {
        self.init(coverURL: book.coverAssetName, width: width, title: book.title, author: book.formattedAuthors)
    }

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

    /// AsyncImage reports a load cancelled by a re-render as a failure and never retries, so retry once
    @State private var attempt = 0

    var body: some View {
        AsyncImage(url: URL.bookCover(from: coverURL)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .empty where URL.bookCover(from: coverURL) != nil:
                BookPlaceholderView.flexible(cornerRadius: 0, showLoading: false)
            case .failure where attempt == 0:
                BookPlaceholderView.flexible(cornerRadius: 0, showLoading: false)
                    .task {
                        try? await Task.sleep(for: .milliseconds(300))
                        attempt += 1
                    }
            default:
                if let title {
                    TypographicCover(title: title, author: author ?? "")
                } else {
                    BookPlaceholderView.flexible(cornerRadius: 0, showLoading: false)
                }
            }
        }
        .id(attempt)
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

    private let columns = [GridItem(.adaptive(minimum: 104, maximum: 150), spacing: 20, alignment: .top)]
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
