import Testing
import Foundation
@testable import BookBite

private final class OfflineConnectivity: ConnectivityChecking {
    var isOnline: Bool { false }
}

struct LocalLibrarySearchTests {
    private func book(_ id: String, _ title: String, subtitle: String? = nil, authors: [String] = [],
                      categories: [String] = [], popularity: Double? = nil) -> Book {
        Book(id: id, title: title, subtitle: subtitle, authors: authors, isbn10: nil, isbn13: nil,
             publishedYear: nil, publisher: nil, categories: categories, coverAssetName: nil,
             description: nil, sourceAttribution: [], popularityScore: popularity)
    }

    @Test("Title matches come before subtitle, author and category matches")
    func ranking() {
        let library = LocalLibrary(books: [
            book("category", "Make Time", categories: ["Habits"]),
            book("author", "Feel-Good Productivity", authors: ["Habits Person"]),
            book("subtitle", "Tiny Changes", subtitle: "Small habits for big results"),
            book("contains", "The Power of Habits"),
            book("prefix", "Habits of Mind"),
            book("exact", "Habits"),
        ], readableIds: [])
        #expect(library.search("habits").map(\.id) == ["exact", "prefix", "contains", "subtitle", "author", "category"])
    }

    @Test("Case, accents and extra spaces are ignored; every word may match a different field")
    func normalizing() {
        let library = LocalLibrary(books: [
            book("a", "Thinking, Fast and Slow", authors: ["Daniel Kahneman"]),
            book("b", "Sapiens"),
        ], readableIds: [])
        #expect(library.search("  KAHNEMAN ").map(\.id) == ["a"])
        #expect(library.search("thinking kahneman").map(\.id) == ["a"])
        #expect(library.search("sápiens").map(\.id) == ["b"])
        #expect(library.search("   ").isEmpty)
    }

    @Test("Within a rank, books readable offline come first, then the more popular")
    func readableFirst() {
        let library = LocalLibrary(books: [
            book("popular", "Deep Work", popularity: 900),
            book("readable", "Deep Work", popularity: 10),
            book("other", "Deep Work", popularity: 50),
        ], readableIds: ["readable"])
        #expect(library.search("deep work").map(\.id) == ["readable", "popular", "other"])
    }
}

@MainActor
struct OfflineSearchServiceTests {
    @Test("Offline, search uses the books on the device and makes no request")
    func offlineSearchIsLocal() async throws {
        let books = [Book(id: "local-1", title: "Atomic Habits", authors: ["James Clear"])]
        let service = SearchService(
            repository: MockBookRepository(),
            connectivity: OfflineConnectivity(),
            localLibrary: { LocalLibrary(books: books, readableIds: ["local-1"]) }
        )

        await service.performSearchAsync(query: "atomic")

        #expect(service.searchResults.map(\.id) == ["local-1"])
        #expect(service.isShowingLocalResults)
        #expect(service.searchError == nil)
        #expect(!service.hasMore)
        #expect(!service.isSearching)

        service.clearSearch()
        #expect(!service.isShowingLocalResults)
    }
}
