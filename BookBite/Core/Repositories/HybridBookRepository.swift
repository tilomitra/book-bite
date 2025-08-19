import Foundation

class HybridBookRepository: BookRepository, SummaryGenerationCapable {
    private let remoteRepository = RemoteBookRepository()
    
    init() {
        // Simplified - no network monitoring needed
    }
    
    // MARK: - BookRepository Implementation
    
    func fetchAllBooks() async throws -> [Book] {
        return try await remoteRepository.fetchAllBooks()
    }
    
    func fetchFeaturedBooks() async throws -> [Book] {
        return try await remoteRepository.fetchFeaturedBooks()
    }
    
    func fetchNYTBestsellerBooks() async throws -> [Book] {
        return try await remoteRepository.fetchNYTBestsellerBooks()
    }
    
    func fetchBook(by id: String) async throws -> Book? {
        return try await remoteRepository.fetchBook(by: id)
    }
    
    func fetchSummary(for bookId: String) async throws -> Summary? {
        return try await remoteRepository.fetchSummary(for: bookId)
    }
    
    func searchBooks(query: String) async throws -> [Book] {
        return try await remoteRepository.searchBooks(query: query)
    }
    
    func fetchCategories() async throws -> [BookCategory] {
        return try await remoteRepository.fetchCategories()
    }
    
    func fetchBooksByCategory(_ category: String, page: Int, limit: Int) async throws -> [Book] {
        return try await remoteRepository.fetchBooksByCategory(category, page: page, limit: limit)
    }
    
    // MARK: - Additional Remote Features
    
    func generateSummary(for bookId: String, style: Summary.SummaryStyle = .full) async throws -> SummaryGenerationJob {
        return try await remoteRepository.generateSummary(for: bookId, style: style)
    }
    
    func checkSummaryGenerationJob(jobId: String) async throws -> SummaryGenerationJob {
        return try await remoteRepository.checkSummaryGenerationJob(jobId: jobId)
    }
    
    func importBook(isbn: String) async throws -> Book {
        return try await remoteRepository.importBook(isbn: isbn)
    }
    
    func refreshBook(_ bookId: String) async throws -> Book? {
        return try await remoteRepository.refreshBook(bookId)
    }
    
    func refreshSummary(bookId: String) async throws -> Summary? {
        return try await remoteRepository.refreshSummary(bookId: bookId)
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        remoteRepository.clearCache()
    }
}