import Foundation
import Combine

/// One item of the Discover feed below the idea of the day
enum DiscoverBlock: Identifiable {
    case shelf(title: String, books: [Book])
    case spotlight(Highlight)
    case passage(Highlight)
    case quickBites(title: String, caption: String, highlights: [Highlight])

    var id: String {
        switch self {
        // Highlight shelf titles repeat once their list cycles; the first book keeps ids unique
        case .shelf(let title, let books): return "shelf:\(title):\(books.first?.id ?? "")"
        case .spotlight(let highlight): return "spotlight:\(highlight.id)"
        case .passage(let highlight): return "passage:\(highlight.id)"
        case .quickBites(_, _, let highlights): return "bites:\(highlights.map(\.id).joined(separator: ","))"
        }
    }
}

@MainActor
class FeaturedBooksViewModel: ObservableObject {
    @Published var dailyIdea: DailyIdea?
    @Published var booksByGenre: [(genre: String, books: [Book])] = []
    /// The endless feed: shelves with editorial cards between them, then editorial cards and
    /// shelves made from highlights once the genre shelves run out. Grows through `loadMore()`.
    @Published private(set) var blocks: [DiscoverBlock] = []
    @Published private(set) var isLoadingMore = false
    @Published var isLoading = false
    @Published var error: Error?

    private let bookRepository: BookRepository
    private var featuredBooks: [Book] = []
    private var nytBestsellerBooks: [Book] = []
    /// Personal shelves and per-book scores from the server; nil before they load or if they fail
    private var recommendations: Recommendations?

    // Feed state
    private var pendingShelves: [(genre: String, books: [Book])] = []
    private var highlightQueue: [Highlight] = []
    private var nextHighlightsPage = 1
    private var hasMoreHighlights = true
    /// Books already in the feed (ids and "title|author", to skip other editions): each book shows up once
    private var usedBookKeys = Set<String>()
    /// Card kinds left in this round, in random order: 0 spotlight, 1 quick bites, 2 passage, 3 highlight shelf
    private var editorialDeck: [Int] = []
    private var lastEditorialKind: Int?
    /// Shelves since the last card, and how many (one or two, at random) come before the next one
    private var shelfStep = 0
    private var shelvesBeforeCard = 2
    /// Where the card and shelf titles start, and how many of each the feed has used
    private var titleOffset = 0
    private var biteCards = 0
    private var highlightShelves = 0

    // A new order on every visit (launch, pull to refresh, return after a while): one seed drives the
    // shelf order, the books in each shelf, the card rotation and the server's highlight order.
    private var feedSeed = 1
    private var generator = SeededGenerator(seed: 1)
    /// Books shown on earlier visits; they move further back so the top of the feed changes
    private var shownBefore = Set<String>()
    private let highlightsPageSize = 24
    /// Blocks added per `loadMore()`
    private let chunkSize = 6

    private static let biteTitles: [(title: String, caption: String)] = [
        ("Quick bites", "Start here"),
        ("Big ideas, briefly", "In one sentence"),
        ("Worth your time", "Readers keep coming back"),
        ("Before your next coffee", "In brief"),
    ]
    private static let highlightShelfTitles = ["More to explore", "Keep reading", "Also worth a look", "From the stacks"]

    init(bookRepository: BookRepository) {
        self.bookRepository = bookRepository

        Task {
            await loadFeaturedBooks()
        }
    }

    var showEmptyState: Bool {
        !isLoading && error == nil && booksByGenre.isEmpty
    }

    func loadFeaturedBooks() async {
        isLoading = true
        error = nil

        // Clear cache to ensure fresh data
        bookRepository.clearCache()
        startNewOrder()

        // Loads alongside the books; a failure only hides the card
        let dailyIdeaTask = Task { await fetchIdea() }
        let recommendationsTask = Task { await fetchRecommendations() }

        do {
            async let featuredBooksTask = bookRepository.fetchFeaturedBooks()
            async let nytBooksTask = bookRepository.fetchNYTBestsellerBooks()

            let (featured, nytBooks) = try await (featuredBooksTask, nytBooksTask)

            featuredBooks = featured
            nytBestsellerBooks = nytBooks
            // Wait for the personal shelves too, so the page doesn't reshuffle while someone reads it
            recommendations = await recommendationsTask.value ?? recommendations
            groupBooksByGenre()
            // Before the feed, so its book isn't repeated on a card
            dailyIdea = await dailyIdeaTask.value ?? dailyIdea
            await resetFeed()
        } catch {
            // Don't show cancellation errors to user - they're expected during rapid refreshes
            if !(error is CancellationError) {
                self.error = error
                print("Failed to load books: \(error)")
            }
        }

        dailyIdea = await dailyIdeaTask.value ?? dailyIdea
        isLoading = false
    }

    var canLoadMore: Bool {
        !pendingShelves.isEmpty || !highlightQueue.isEmpty || hasMoreHighlights
    }

    /// Appends the next few blocks, fetching another page of highlights when the queue runs low.
    /// Called as the reader nears the end of the feed.
    func loadMore() async {
        guard !isLoadingMore, !isLoading, canLoadMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        await appendChunk()
    }

    private func appendChunk() async {
        // Enough for a full rotation (spotlight, three bites, passage, a shelf of eight)
        while highlightQueue.count < 14 && hasMoreHighlights {
            await fetchNextHighlights()
        }

        var added: [DiscoverBlock] = []
        while added.count < chunkSize, let block = nextBlock() {
            added.append(block)
        }
        blocks.append(contentsOf: added)
        DiscoverHistory.record(added.flatMap(shownBookIds))
    }

    private func startNewOrder() {
        feedSeed = Int.random(in: 1...Int(Int32.max))
        generator = SeededGenerator(seed: UInt64(feedSeed))
        shownBefore = DiscoverHistory.shownBookIds
    }

    /// Books a block puts on screen (a shelf only its preview), for `DiscoverHistory`
    private func shownBookIds(_ block: DiscoverBlock) -> [String] {
        switch block {
        case .shelf(_, let books): return books.prefix(BookShelf.previewCount).map(\.id)
        case .spotlight(let highlight), .passage(let highlight): return [highlight.book.id]
        case .quickBites(_, _, let highlights): return highlights.map(\.book.id)
        }
    }

    /// Ranked books, mixed for this visit; books shown on earlier visits move back
    private func mixedBooks(_ books: [Book], spread: Double = 1.5) -> [Book] {
        let shown = shownBefore
        return FeedShuffle.jittered(books, spread: spread, pushedBack: { shown.contains($0.id) }, using: &generator)
    }

    private func mixed<T>(_ items: [T], spread: Double) -> [T] {
        FeedShuffle.jittered(items, spread: spread, using: &generator)
    }

    private func resetFeed() async {
        pendingShelves = booksByGenre
        highlightQueue = []
        nextHighlightsPage = 1
        hasMoreHighlights = bookRepository is HighlightsProviding
        usedBookKeys = []
        editorialDeck = []
        lastEditorialKind = nil
        shelfStep = 0
        shelvesBeforeCard = 2
        titleOffset = Int.random(in: 0..<12, using: &generator)
        biteCards = 0
        highlightShelves = 0
        if let dailyIdea { markUsed(dailyIdea.book) }
        blocks = []
        await appendChunk()
    }

    private func fetchNextHighlights() async {
        guard let provider = bookRepository as? HighlightsProviding else {
            hasMoreHighlights = false
            return
        }
        do {
            let page = try await provider.fetchHighlights(page: nextHighlightsPage, limit: highlightsPageSize, seed: feedSeed)
            nextHighlightsPage += 1
            hasMoreHighlights = page.hasMore
            // The server mixes the order per seed; within a page, the ones closest to the reader's taste first
            var items = page.items
            if let scores = recommendations?.scores, !scores.isEmpty {
                items = items.enumerated()
                    .sorted { (scores[$0.element.id] ?? -1, -$0.offset) > (scores[$1.element.id] ?? -1, -$1.offset) }
                    .map(\.element)
            }
            // Books shown on earlier visits go to the end of the page
            let shown = shownBefore
            items = items.filter { !shown.contains($0.book.id) } + items.filter { shown.contains($0.book.id) }
            highlightQueue += items.filter { !isUsed($0.book) }
        } catch {
            // The feed ends with the shelves; the next scroll to the bottom tries again
            print("Failed to load highlights: \(error)")
            if highlightQueue.isEmpty { hasMoreHighlights = false }
        }
    }

    private func bookKeys(_ book: Book) -> [String] {
        [book.id, "\(book.shelfTitle.lowercased())|\(book.authors.first?.lowercased() ?? "")"]
    }

    private func isUsed(_ book: Book) -> Bool {
        bookKeys(book).contains { usedBookKeys.contains($0) }
    }

    private func markUsed(_ book: Book) {
        usedBookKeys.formUnion(bookKeys(book))
    }

    /// Next unused highlight, optionally only a quotable one
    private func takeHighlight(quotable: Bool = false) -> Highlight? {
        highlightQueue.removeAll { isUsed($0.book) }
        guard let index = highlightQueue.firstIndex(where: { !quotable || $0.isQuotable }) else { return nil }
        let highlight = highlightQueue.remove(at: index)
        markUsed(highlight.book)
        return highlight
    }

    private func takeHighlights(_ count: Int) -> [Highlight] {
        var taken: [Highlight] = []
        while taken.count < count, let highlight = takeHighlight() {
            taken.append(highlight)
        }
        return taken
    }

    /// One or two shelves, then an editorial card, while genre shelves last; after that editorial cards
    /// alternate with shelves built from highlights. Card kinds come in a random order each round.
    private func nextBlock() -> DiscoverBlock? {
        if shelfStep < shelvesBeforeCard, let shelf = takeShelf() {
            shelfStep += 1
            return shelf
        }
        shelfStep = 0
        shelvesBeforeCard = Int.random(in: 1...2, using: &generator)

        if let block = editorialBlock(nextEditorialKind()) {
            return block
        }
        // Not enough highlights for that card: fall back to whatever is left
        if let shelf = takeShelf() {
            return shelf
        }
        if let highlight = takeHighlight() {
            return .spotlight(highlight)
        }
        return nil
    }

    /// Next pending shelf without the books already shown; shelves left with fewer than 4 books are skipped
    private func takeShelf() -> DiscoverBlock? {
        while !pendingShelves.isEmpty {
            let shelf = pendingShelves.removeFirst()
            let books = unusedBooks(shelf.books)
            guard books.count >= 4 else { continue }
            // Only the books the shelf shows; the rest are behind "See all" and may still get a card
            books.prefix(BookShelf.previewCount).forEach(markUsed)
            return .shelf(title: shelf.genre, books: books)
        }
        return nil
    }

    /// Books not in the feed yet, one edition each
    private func unusedBooks(_ books: [Book]) -> [Book] {
        var seen = Set<String>()
        return books.filter { book in
            let keys = bookKeys(book)
            guard !isUsed(book), keys.allSatisfy({ !seen.contains($0) }) else { return false }
            seen.formUnion(keys)
            return true
        }
    }

    /// Each kind once per round in a shuffled order, never the same kind twice in a row.
    /// Highlight shelves join the rounds once the genre shelves run out.
    private func nextEditorialKind() -> Int {
        if editorialDeck.isEmpty {
            var kinds = pendingShelves.isEmpty ? [0, 1, 2, 3] : [0, 1, 2]
            kinds.shuffle(using: &generator)
            if kinds.first == lastEditorialKind {
                kinds.swapAt(0, kinds.count - 1)
            }
            editorialDeck = kinds
        }
        let kind = editorialDeck.removeFirst()
        lastEditorialKind = kind
        return kind
    }

    private func editorialBlock(_ kind: Int) -> DiscoverBlock? {
        switch kind {
        case 0:
            return takeHighlight().map(DiscoverBlock.spotlight)
        case 1:
            guard highlightQueue.count >= 3 else { return nil }
            let titles = Self.biteTitles[(titleOffset + biteCards) % Self.biteTitles.count]
            biteCards += 1
            return .quickBites(title: titles.title, caption: titles.caption, highlights: takeHighlights(3))
        case 2:
            return takeHighlight(quotable: true).map(DiscoverBlock.passage)
        default:
            guard highlightQueue.count >= 6 else { return nil }
            let books = takeHighlights(8).map(\.book)
            let title = Self.highlightShelfTitles[(titleOffset + highlightShelves) % Self.highlightShelfTitles.count]
            highlightShelves += 1
            return .shelf(title: title, books: books)
        }
    }

    /// A new idea each time the app opens: on launch, pull to refresh and return from the background.
    /// Only the card changes, so the feed below doesn't move.
    func refreshIdea() async {
        if let idea = await fetchIdea() { dailyIdea = idea }
    }

    private static let lastIdeaBookKey = "lastIdeaBookId"

    private func fetchIdea() async -> DailyIdea? {
        guard let provider = bookRepository as? DailyIdeaProviding else { return nil }
        // Skip the book shown last time, also across launches
        let last = dailyIdea?.book.id ?? UserDefaults.standard.string(forKey: Self.lastIdeaBookKey)
        do {
            let idea = try await provider.fetchRandomIdea(excluding: last)
            if let idea { UserDefaults.standard.set(idea.book.id, forKey: Self.lastIdeaBookKey) }
            return idea
        } catch {
            print("Failed to load idea: \(error)")
            return nil
        }
    }

    /// Taste answers from onboarding plus books opened since. Empty for a reader who skipped everything.
    private func makeRecommendationRequest() -> RecommendationRequest {
        // Only books from our catalog have embeddings (search can open Google Books results)
        let recent = RecentBooksStore.shared.books.map(\.id).filter { UUID(uuidString: $0) != nil }
        return RecommendationRequest(
            likedBookIds: OnboardingPreferences.likedBookIds,
            recentBookIds: Array(recent.prefix(10)),
            goals: OnboardingPreferences.readingGoals,
            genres: OnboardingPreferences.preferredGenres
        )
    }

    private func fetchRecommendations() async -> Recommendations? {
        guard let provider = bookRepository as? RecommendationsProviding else { return nil }
        let request = makeRecommendationRequest()
        guard !request.isEmpty else { return nil }
        do {
            return try await provider.fetchRecommendations(request)
        } catch {
            // Discover works without them: genre shelves in the default order
            print("Failed to load recommendations: \(error)")
            return nil
        }
    }

    /// Books closest to the reader's taste first; books without a score keep their order after them
    private func sortedByScore(_ books: [Book], scores: [String: Double]) -> [Book] {
        let scored = books.filter { scores[$0.id] != nil }.sorted { scores[$0.id]! > scores[$1.id]! }
        return scored + books.filter { scores[$0.id] == nil }
    }

    /// How close a shelf is to the reader's taste: mean score of its five closest books
    private func affinity(of books: [Book], scores: [String: Double]) -> Double {
        let top = books.compactMap { scores[$0.id] }.sorted(by: >).prefix(5)
        return top.isEmpty ? 0 : top.reduce(0, +) / Double(top.count)
    }

    /// Most popular first, then alphabetical; `mixedBooks` then varies it per visit
    private func sortedByPopularity(_ books: [Book]) -> [Book] {
        books.sorted { book1, book2 in
            switch (book1.popularityScore, book2.popularityScore) {
            case let (score1?, score2?) where score1 != score2:
                return score1 > score2
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                return book1.title.localizedCaseInsensitiveCompare(book2.title) == .orderedAscending
            }
        }
    }

    private func groupBooksByGenre() {
        // Create genre groups based on categories
        var genreMap: [String: [Book]] = [:]
        
        // Predefined genre sections for NYT bestsellers to ensure consistent ordering
        let primaryGenres = [
            "Business",
            "Self-Help",
            "Biography", 
            "Personal Development",
            "Psychology",
            "Health",
            "History",
            "Politics",
            "Philosophy",
            "Economics",
            "Technology",
            "Education",
            "Arts & Culture",
            "Nature & Environment"
        ]
        
        // Track which books have been assigned to prevent duplicates across genres
        var assignedBookIds = Set<String>()
        
        // Map books to their primary genre (first matching category only)
        for book in featuredBooks + nytBestsellerBooks {
            // Skip if this book is already assigned to a genre
            if assignedBookIds.contains(book.id) {
                continue
            }
            
            // Find the first matching primary genre for this book
            var assignedGenre: String? = nil
            for category in book.categories {
                let mainGenre = mapCategoryToGenre(category)
                if primaryGenres.contains(mainGenre) {
                    assignedGenre = mainGenre
                    break
                }
            }
            
            // If no primary genre match, use the first category mapped to any genre
            if assignedGenre == nil {
                for category in book.categories {
                    let mainGenre = mapCategoryToGenre(category)
                    assignedGenre = mainGenre
                    break
                }
            }
            
            // Assign book to the determined genre
            if let genre = assignedGenre {
                if genreMap[genre] == nil {
                    genreMap[genre] = []
                }
                genreMap[genre]!.append(book)
                assignedBookIds.insert(book.id)
            }
        }
        
        // Create ordered genre list
        var orderedGenres: [(genre: String, books: [Book])] = []
        var otherPicksBooks: [Book] = []
        
        // Add primary genres first (if they have 4+ books)
        for genre in primaryGenres {
            if let books = genreMap[genre], !books.isEmpty {
                if books.count >= 4 {
                    orderedGenres.append((genre: genre, books: sortedByPopularity(books)))
                } else {
                    // Add books to "More Books" if less than 4 books
                    otherPicksBooks.append(contentsOf: books)
                }
                genreMap.removeValue(forKey: genre)
            }
        }
        
        // Add any remaining genres (if they have 4+ books)
        for (genre, books) in genreMap.sorted(by: { $0.key < $1.key }) {
            if !books.isEmpty {
                if books.count >= 4 {
                    orderedGenres.append((genre: genre, books: sortedByPopularity(books)))
                } else {
                    // Add books to "More Books" if less than 4 books
                    otherPicksBooks.append(contentsOf: books)
                }
            }
        }
        
        // Add "More Books" shelf if we have books for it
        if !otherPicksBooks.isEmpty {
            orderedGenres.append((genre: "More Books", books: sortedByPopularity(otherPicksBooks)))
        }
        
        let preferred = Set(OnboardingPreferences.preferredGenres)
        let scores = recommendations?.scores ?? [:]
        // "More Books" stays last
        let moreBooks = orderedGenres.filter { $0.genre == "More Books" }
        orderedGenres.removeAll { $0.genre == "More Books" }

        // Each visit mixes the ranked order (best shelves and books still lean to the top)
        if scores.isEmpty {
            // Topics picked during onboarding come first
            orderedGenres = mixed(orderedGenres.filter { preferred.contains($0.genre) }, spread: 0.8)
                + mixed(orderedGenres.filter { !preferred.contains($0.genre) }, spread: 0.8)
        } else {
            // Shelves closest to the reader's taste first (picked topics get a nudge)
            orderedGenres = mixed(orderedGenres
                .map { (genre: $0.genre, books: sortedByScore($0.books, scores: scores)) }
                .map { shelf in (shelf, affinity(of: shelf.books, scores: scores) + (preferred.contains(shelf.genre) ? 0.05 : 0)) }
                .sorted { $0.1 > $1.1 }
                .map(\.0), spread: 0.8)
        }
        orderedGenres = (orderedGenres + moreBooks).map { (genre: $0.genre, books: mixedBooks($0.books)) }

        // Personal shelves ("For you", "More like …", goals) go above the genre shelves; "For you" stays first
        let genreNames = Set(orderedGenres.map(\.genre))
        let personal = (recommendations?.shelves ?? [])
            .filter { !genreNames.contains($0.title) && !$0.books.isEmpty }
            .map { (genre: $0.title, books: mixedBooks($0.books, spread: 1.0)) }
        booksByGenre = Array(personal.prefix(1)) + mixed(Array(personal.dropFirst()), spread: 0.8) + orderedGenres
    }
    
    private func mapCategoryToGenre(_ category: String) -> String {
        let lowercased = category.lowercased()
        
        // Map specific categories to main NYT genres
        if lowercased.contains("business") || lowercased.contains("management") ||
           lowercased.contains("leadership") || lowercased.contains("entrepreneur") ||
           lowercased.contains("strategy") || lowercased.contains("corporate") {
            return "Business"
        } else if lowercased.contains("self-help") || lowercased.contains("self help") ||
                  lowercased.contains("personal") || lowercased.contains("productivity") ||
                  lowercased.contains("habit") || lowercased.contains("improvement") {
            return "Self-Help"
        } else if lowercased.contains("biography") || lowercased.contains("memoir") ||
                  lowercased.contains("life") && (lowercased.contains("story") || lowercased.contains("journey")) {
            return "Biography"
        } else if lowercased.contains("personal development") || lowercased.contains("development") ||
                  lowercased.contains("growth") || lowercased.contains("mindfulness") ||
                  lowercased.contains("meditation") || lowercased.contains("wellness") {
            return "Personal Development"
        } else if lowercased.contains("politics") || lowercased.contains("government") ||
                  lowercased.contains("democracy") || lowercased.contains("election") {
            return "Politics"
        } else if lowercased.contains("health") || lowercased.contains("medicine") ||
                  lowercased.contains("fitness") || lowercased.contains("nutrition") ||
                  lowercased.contains("wellness") {
            return "Health"
        } else if lowercased.contains("history") || lowercased.contains("historical") ||
                  lowercased.contains("war") || lowercased.contains("ancient") {
            return "History"
        } else if lowercased.contains("psychology") || lowercased.contains("mental") ||
                  lowercased.contains("mind") || lowercased.contains("behavior") ||
                  lowercased.contains("social science") {
            return "Psychology"
        } else if lowercased.contains("philosophy") || lowercased.contains("ethics") ||
                  lowercased.contains("wisdom") || lowercased.contains("meaning") ||
                  lowercased.contains("spiritual") {
            return "Philosophy"
        } else if lowercased.contains("economics") || lowercased.contains("economy") ||
                  lowercased.contains("finance") || lowercased.contains("money") ||
                  lowercased.contains("wealth") || lowercased.contains("investing") {
            return "Economics"
        } else if lowercased.contains("technology") || lowercased.contains("tech") ||
                  lowercased.contains("digital") || lowercased.contains("computer") ||
                  lowercased.contains("artificial intelligence") || lowercased.contains("ai") {
            return "Technology"
        } else if lowercased.contains("education") || lowercased.contains("learning") ||
                  lowercased.contains("teaching") || lowercased.contains("school") ||
                  lowercased.contains("university") {
            return "Education"
        } else if lowercased.contains("art") || lowercased.contains("culture") ||
                  lowercased.contains("music") || lowercased.contains("literature") ||
                  lowercased.contains("design") || lowercased.contains("creative") {
            return "Arts & Culture"
        } else if lowercased.contains("nature") || lowercased.contains("environment") ||
                  lowercased.contains("climate") || lowercased.contains("ecology") ||
                  lowercased.contains("sustainability") {
            return "Nature & Environment"
        } else {
            // Return the original category if it doesn't match any mapping
            return category
        }
    }
}
