import Testing
import Foundation
@testable import BookBite

/// SearchService talks to `/books/search` directly, so the tests stub that endpoint
/// with the mock books and let the real request/decoding path run.
final class StubSearchURLProtocol: URLProtocol {
    static let books = MockBookRepository().mockBooksForStub

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.path.hasSuffix("/books/search") == true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let query = (items.first { $0.name == "q" }?.value ?? "").lowercased()
        let results = query.isEmpty ? Self.books : Self.books.filter { book in
            book.title.lowercased().contains(query) ||
            book.authors.contains { $0.lowercased().contains(query) }
        }
        let body: [String: Any] = [
            "results": (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(results))) ?? [],
            "pagination": ["page": 1, "limit": 20, "total": results.count, "totalPages": 1, "hasMore": false]
        ]
        let data = try! JSONSerialization.data(withJSONObject: body)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@MainActor
@Suite(.serialized)
struct SearchServiceTests {
    
    init() {
        URLProtocol.registerClass(StubSearchURLProtocol.self)
    }
    
    func createMockRepository() -> MockBookRepository {
        return MockBookRepository()
    }
    
    /// Wait for the search task to finish instead of sleeping a fixed amount
    func waitForResults(_ searchService: SearchService) async throws {
        for _ in 0..<50 {
            try await Task.sleep(nanoseconds: 20_000_000)
            if !searchService.isSearching && (!searchService.searchResults.isEmpty || searchService.searchError != nil) {
                return
            }
        }
    }
    
    @Test("SearchService should filter books by title")
    func testSearchByTitle() async throws {
        let repository = createMockRepository()
        let searchService = SearchService(repository: repository)
        
        searchService.search(query: "Manager")
        
        try await waitForResults(searchService)
        
        #expect(searchService.searchResults.count == 1)
        #expect(searchService.searchResults.first?.title.contains("Manager") == true)
    }
    
    @Test("SearchService should filter books by author")
    func testSearchByAuthor() async throws {
        let repository = createMockRepository()
        let searchService = SearchService(repository: repository)
        
        searchService.search(query: "Fournier")
        
        try await waitForResults(searchService)
        
        #expect(searchService.searchResults.count == 1)
        #expect(searchService.searchResults.first?.authors.contains("Camille Fournier") == true)
    }
    
    @Test("SearchService should handle empty query")
    func testSearchByEmptyQuery() async throws {
        let repository = createMockRepository()
        let searchService = SearchService(repository: repository)
        
        searchService.search(query: "")
        
        try await waitForResults(searchService)
        
        #expect(searchService.searchResults.count == 2)
    }
}

class MockBookRepository: BookRepository {
    var mockBooksForStub: [Book] { mockBooks }

    private let mockBooks = [
        Book(
            id: "1",
            title: "The Manager's Path",
            subtitle: "Guide for Tech Leaders",
            authors: ["Camille Fournier"],
            isbn10: nil,
            isbn13: nil,
            publishedYear: 2017,
            publisher: "O'Reilly",
            categories: ["Management"],
            coverAssetName: "managers_path",
            description: "Test description",
            sourceAttribution: ["Test"]
        ),
        Book(
            id: "2",
            title: "Clean Code",
            subtitle: "A Handbook of Agile Software Craftsmanship",
            authors: ["Robert C. Martin"],
            isbn10: nil,
            isbn13: nil,
            publishedYear: 2008,
            publisher: "Prentice Hall",
            categories: ["Programming"],
            coverAssetName: "clean_code",
            description: "Test description",
            sourceAttribution: ["Test"]
        )
    ]
    
    private let mockSummaries = [
        Summary(
            id: "s1",
            bookId: "1",
            oneSentenceHook: "Test hook",
            keyIdeas: [],
            howToApply: [],
            commonPitfalls: [],
            critiques: [],
            whoShouldRead: "Test",
            limitations: "Test",
            citations: [],
            readTimeMinutes: 5,
            style: .full,
            extendedSummary: "Extended test summary",
            audioUrl: nil,
            audioDurationSeconds: nil,
            audioFileSizeBytes: nil,
            audioVoiceId: nil
        )
    ]
    
    func fetchAllBooks() async throws -> [Book] {
        return mockBooks
    }
    
    func fetchBook(by id: String) async throws -> Book? {
        return mockBooks.first { $0.id == id }
    }
    
    func fetchSummary(for bookId: String) async throws -> Summary? {
        return mockSummaries.first { $0.bookId == bookId }
    }
    
    func searchBooks(query: String) async throws -> [Book] {
        if query.isEmpty {
            return mockBooks
        }
        
        return mockBooks.filter { book in
            book.title.lowercased().contains(query.lowercased()) ||
            book.authors.contains { $0.lowercased().contains(query.lowercased()) }
        }
    }
    
    func fetchFeaturedBooks() async throws -> [Book] {
        return mockBooks.filter { $0.isFeatured == true }
    }
    
    func fetchNYTBestsellerBooks() async throws -> [Book] {
        return mockBooks.filter { $0.isNYTBestseller == true }
    }
    
    func fetchCategories() async throws -> [BookCategory] {
        return [
            BookCategory(name: "Management", iconName: "briefcase", bookCount: 1),
            BookCategory(name: "Programming", iconName: "laptopcomputer", bookCount: 1)
        ]
    }
    
    func fetchBooksByCategory(_ category: String, page: Int, limit: Int) async throws -> [Book] {
        return mockBooks.filter { book in
            book.categories.contains(category)
        }
    }
    
    func clearCache() {
        // Mock implementation - no-op
    }
}