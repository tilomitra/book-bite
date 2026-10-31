import Foundation

/// The books this device already knows about, for searching without a connection: downloads, books with
/// reading progress, recently opened books and the last Discover feed. `readableIds` are the ones whose
/// summary is on the device, so they open fully offline.
struct LocalLibrary {
    let books: [Book]
    let readableIds: Set<String>

    /// Collects the books on this device, without duplicates, downloads first
    @MainActor
    static func onDevice(storage: OfflineStorageService = .shared,
                         progress: ReadingProgressStore = .shared,
                         recent: RecentBooksStore = .shared,
                         cache: CacheService = .shared) -> LocalLibrary {
        let downloads = storage.getAllOfflineBooks()
        var books = downloads.compactMap { storage.getOfflineBook(id: $0.bookId) }
        books += progress.entries.map(\.book)
        books += recent.books
        if let discover = cache.snapshot(DiscoverSnapshot.self, key: FeaturedBooksViewModel.snapshotKey) {
            books += discover.recommendations?.shelves.flatMap(\.books) ?? []
            books += discover.featuredBooks
            books += discover.nytBestsellerBooks
            books += discover.highlights?.items.map(\.book) ?? []
        }

        var seen = Set<String>()
        books = books.filter { seen.insert($0.id).inserted }

        let downloadedWithSummary = Set(downloads.filter(\.hasSummary).map(\.bookId))
        let readable = Set(books.map(\.id).filter { downloadedWithSummary.contains($0) || cache.isSummaryCached(bookId: $0) })
        return LocalLibrary(books: books, readableIds: readable)
    }

    /// Matches ranked like the server's search: title exact, title prefix, title contains, all words in
    /// title/subtitle/authors, subtitle, author, category, description. Within a rank, books readable
    /// offline come first, then the more popular.
    func search(_ query: String) -> [Book] {
        let needle = Self.normalize(query)
        guard !needle.isEmpty else { return [] }
        let words = needle.split(separator: " ").map(String.init)

        let ranked: [(book: Book, rank: Int)] = books.compactMap { book in
            Self.rank(book, needle: needle, words: words).map { (book: book, rank: $0) }
        }
        return ranked.sorted { a, b in
            if a.rank != b.rank { return a.rank < b.rank }
            let aReadable = readableIds.contains(a.book.id), bReadable = readableIds.contains(b.book.id)
            if aReadable != bReadable { return aReadable }
            let aScore = a.book.popularityScore ?? 0, bScore = b.book.popularityScore ?? 0
            if aScore != bScore { return aScore > bScore }
            return a.book.title < b.book.title
        }
        .map(\.book)
    }

    private static func rank(_ book: Book, needle: String, words: [String]) -> Int? {
        let title = normalize(book.title)
        let subtitle = normalize(book.subtitle ?? "")
        let authors = book.authors.map(normalize)

        if title == needle { return 0 }
        if title.hasPrefix(needle) { return 1 }
        if title.contains(needle) { return 2 }
        let text = ([title, subtitle] + authors).joined(separator: " ")
        if words.count > 1, words.allSatisfy({ text.contains($0) }) { return 3 }
        if subtitle.contains(needle) { return 4 }
        if authors.contains(where: { $0.contains(needle) }) { return 5 }
        if book.categories.contains(where: { normalize($0).contains(needle) }) { return 6 }
        if let description = book.description, normalize(description).contains(needle) { return 7 }
        return nil
    }

    /// Case and accents ignored, runs of spaces collapsed
    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
