import Testing
import Foundation
@testable import BookBite

/// Every request fails: anything on screen came from a snapshot
private final class OfflineRepository: BookRepository, HighlightsProviding {
    private struct Offline: Error {}

    func fetchAllBooks() async throws -> [Book] { throw Offline() }
    func fetchFeaturedBooks() async throws -> [Book] { throw Offline() }
    func fetchNYTBestsellerBooks() async throws -> [Book] { throw Offline() }
    func fetchBook(by id: String) async throws -> Book? { throw Offline() }
    func fetchSummary(for bookId: String) async throws -> Summary? { throw Offline() }
    func searchBooks(query: String) async throws -> [Book] { throw Offline() }
    func fetchCategories() async throws -> [BookCategory] { throw Offline() }
    func fetchBooksByCategory(_ category: String, page: Int, limit: Int) async throws -> [Book] { throw Offline() }
    func fetchHighlights(page: Int, limit: Int, seed: Int) async throws -> HighlightsPage { throw Offline() }
    func clearCache() {}
}

// Tests share CacheService.shared
@Suite(.serialized)
@MainActor
struct SnappyLoadingTests {
    private func book(_ number: Int, category: String = "Business") -> Book {
        Book(id: "book-\(number)", title: "Book \(number)", authors: ["Author \(number)"], categories: [category],
             coverAssetName: "https://example.com/\(number).jpg", isFeatured: true)
    }

    private func highlight(_ number: Int) -> Highlight {
        let idea = KeyIdea(id: "idea-\(number)", idea: "An idea long enough to stand alone as a quote, number \(number).",
                           tags: [], confidence: .high, sources: [])
        return Highlight(book: book(number), hook: "Hook \(number)", idea: idea)
    }

    private func snapshot() -> DiscoverSnapshot {
        DiscoverSnapshot(
            featuredBooks: (1...8).map { book($0) },
            nytBestsellerBooks: [],
            recommendations: Recommendations(shelves: [], scores: ["book-1": 0.9]),
            highlights: HighlightsPage(items: (100...123).map(highlight), page: 1, hasMore: true)
        )
    }

    @Test("Discover shows the last snapshot in the first frame, without the network")
    func discoverOpensFromSnapshot() {
        CacheService.shared.clearAllCache()
        CacheService.shared.saveSnapshot(snapshot(), key: "discover")

        let viewModel = FeaturedBooksViewModel(bookRepository: OfflineRepository())

        #expect(!viewModel.blocks.isEmpty)
        #expect(viewModel.dailyIdea != nil)
        #expect(!viewModel.isLoading)
        #expect(viewModel.error == nil)
        CacheService.shared.clearAllCache()
    }

    @Test("Discover waits for the network only without a snapshot")
    func discoverWithoutSnapshot() {
        CacheService.shared.clearAllCache()
        let viewModel = FeaturedBooksViewModel(bookRepository: OfflineRepository())
        #expect(viewModel.blocks.isEmpty)
    }

    @Test("A summary survives the round trip through the cache")
    func summaryRoundTrip() throws {
        CacheService.shared.clearAllCache()
        let summary = Summary(
            id: "summary", bookId: "book", oneSentenceHook: "Hook",
            keyIdeas: [KeyIdea(id: "1", idea: "An idea", tags: ["a"], confidence: .high, sources: ["b"])],
            howToApply: [], commonPitfalls: [], critiques: [], whoShouldRead: "Everyone", limitations: "None",
            citations: [], readTimeMinutes: 10, style: .full, extendedSummary: "## One\nText",
            audioUrl: nil, audioDurationSeconds: nil, audioFileSizeBytes: nil, audioVoiceId: nil
        )
        try CacheService.shared.cacheSummary(summary)

        let cached = try #require(try CacheService.shared.getCachedSummary(bookId: "book"))
        #expect(cached.keyIdeas.first?.idea == "An idea")
        #expect(cached.extendedSummary == "## One\nText")
        CacheService.shared.clearAllCache()
    }

    @Test("The book page opens with its cached summary and keeps it when offline")
    func bookPageUsesCachedSummary() async throws {
        CacheService.shared.clearAllCache()
        let summary = Summary(
            id: "summary", bookId: "book-1", oneSentenceHook: "Hook", keyIdeas: [], howToApply: [], commonPitfalls: [],
            critiques: [], whoShouldRead: "", limitations: "", citations: [], readTimeMinutes: 10, style: .full,
            extendedSummary: nil, audioUrl: nil, audioDurationSeconds: nil, audioFileSizeBytes: nil, audioVoiceId: nil
        )
        try CacheService.shared.cacheSummary(summary)

        let viewModel = BookDetailViewModel(book: book(1), repository: OfflineRepository())
        #expect(viewModel.summary?.id == "summary")

        await viewModel.loadSummary()
        #expect(viewModel.summary?.id == "summary")
        #expect(viewModel.summaryError == nil)
        CacheService.shared.clearAllCache()
    }

    @Test("A category opens with last time's first page")
    func categoryOpensFromSnapshot() {
        CacheService.shared.clearAllCache()
        CacheService.shared.saveSnapshot([book(1)], key: "category-business")

        let category = BookCategory(name: "Business", iconName: "briefcase")
        let viewModel = CategoryBooksViewModel(category: category, bookRepository: OfflineRepository())

        #expect(viewModel.books.map(\.id) == ["book-1"])
        CacheService.shared.clearAllCache()
    }

    @Test("Cover URLs ask the host for the width they're shown at")
    func coverURLs() {
        let google = "https://books.google.com/books/publisher/content/images/frontcover/abc?fife=w1200-h1800&source=gbs_api"
        #expect(URL.bookCover(from: google, maxWidth: 400)?.absoluteString.contains("fife=w400-h600") == true)
        #expect(URL.bookCover(from: google, maxWidth: 400)?.absoluteString.contains("w1200") == false)
        #expect(URL.bookCover(from: google)?.absoluteString == google)

        let apple = "https://is1-ssl.mzstatic.com/image/thumb/Publication221/v4/8a/book.d.jpg/1600x1600bb.jpg"
        #expect(URL.bookCover(from: apple, maxWidth: 400)?.absoluteString.hasSuffix("book.d.jpg/400x600bb.jpg") == true)

        let thumbnail = "http://books.google.com/books/content?id=abc&zoom=1&edge=curl"
        let resized = URL.bookCover(from: thumbnail, maxWidth: 400)?.absoluteString ?? ""
        #expect(resized.hasPrefix("https://") && resized.contains("fife=w400") && resized.contains("zoom=1") && !resized.contains("edge"))

        let openLibrary = "https://covers.openlibrary.org/b/id/1-L.jpg"
        #expect(URL.bookCover(from: openLibrary, maxWidth: 400)?.absoluteString == openLibrary)
    }

    @Test("Covers decode at one of a few sizes, big enough for the screen")
    func coverPixelWidths() {
        #expect(CoverImageLoader.pixelWidth(forPoints: 14) >= 28)
        #expect(CoverImageLoader.pixelWidth(forPoints: 118) >= 236)
        #expect(CoverImageLoader.pixelWidth(forPoints: 118) <= 360)
        #expect(CoverImageLoader.pixelWidth(forPoints: 2000) == 1080)
    }
}
