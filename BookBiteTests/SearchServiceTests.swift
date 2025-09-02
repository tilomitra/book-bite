import Testing
import Foundation
@testable import BookBite

@MainActor
struct SearchServiceTests {
    
    func createMockRepository() -> MockBookRepository {
        return MockBookRepository()
    }
    
    @Test("SearchService should filter books by title")
    func testSearchByTitle() async throws {
        let repository = createMockRepository()
        let searchService = SearchService(repository: repository)
        
        searchService.search(query: "Manager")
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(searchService.searchResults.count == 1)
        #expect(searchService.searchResults.first?.title.contains("Manager") == true)
    }
    
    @Test("SearchService should filter books by author")
    func testSearchByAuthor() async throws {
        let repository = createMockRepository()
        let searchService = SearchService(repository: repository)
        
        searchService.search(query: "Fournier")
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(searchService.searchResults.count == 1)
        #expect(searchService.searchResults.first?.authors.contains("Camille Fournier") == true)
    }
    
    @Test("SearchService should handle empty query")
    func testSearchByEmptyQuery() async throws {
        let repository = createMockRepository()
        let searchService = SearchService(repository: repository)
        
        searchService.search(query: "")
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(searchService.searchResults.count == 2)
    }
}

class MockBookRepository: BookRepository {
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
            extendedSummary: "Extended test summary"
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