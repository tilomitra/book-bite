import Foundation
import Combine

class RemoteBookRepository: BookRepository {
    private let networkService = NetworkService.shared
    private let cacheService = CacheService.shared
    
    // MARK: - BookRepository Implementation
    
    func fetchAllBooks() async throws -> [Book] {
        // Check cache first
        if let cachedBooks = try? cacheService.getCachedBooks(), !cachedBooks.isEmpty {
            return cachedBooks
        }
        
        let response: BooksResponse = try await networkService.get(endpoint: "books")
        let books = response.books
        
        // Cache the results
        try? cacheService.cacheBooks(books)
        
        return books
    }
    
    func fetchBook(by id: String) async throws -> Book? {
        // Check cache first
        if let cachedBook = try? cacheService.getCachedBook(id: id) {
            return cachedBook
        }
        
        do {
            let book: Book = try await networkService.get(endpoint: "books/\(id)")
            
            // Cache the result
            try? cacheService.cacheBook(book)
            
            return book
        } catch let error as NetworkError {
            if case .clientError(404, _) = error {
                return nil
            }
            throw error
        }
    }
    
    func fetchSummary(for bookId: String) async throws -> Summary? {
        // Check cache first
        if let cachedSummary = try? cacheService.getCachedSummary(bookId: bookId) {
            return cachedSummary
        }
        
        do {
            let summary: Summary = try await networkService.get(endpoint: "summaries/book/\(bookId)")
            
            // Cache the result
            try? cacheService.cacheSummary(summary)
            
            return summary
        } catch let error as NetworkError {
            if case .clientError(404, _) = error {
                return nil
            }
            throw error
        }
    }
    
    func searchBooks(query: String) async throws -> [Book] {
        // For search, always go to server for fresh results
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let response: SearchResponse = try await networkService.get(endpoint: "books/search?q=\(encodedQuery)")
        
        return response.results
    }
    
    // MARK: - Additional Remote Methods
    
    func generateSummary(for bookId: String, style: Summary.SummaryStyle = .full) async throws -> SummaryGenerationJob {
        let body = GenerateSummaryRequest(style: style.rawValue)
        let job: SummaryGenerationJob = try await networkService.post(
            endpoint: "summaries/book/\(bookId)/generate",
            body: body
        )
        return job
    }
    
    func checkSummaryGenerationJob(jobId: String) async throws -> SummaryGenerationJob {
        return try await networkService.get(endpoint: "summaries/job/\(jobId)")
    }
    
    func importBook(isbn: String) async throws -> Book {
        let body = ImportBookRequest(isbn: isbn)
        let book: Book = try await networkService.post(endpoint: "books/import", body: body)
        
        // Cache the imported book
        try? cacheService.cacheBook(book)
        
        return book
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        cacheService.clearAllCache()
    }
    
    func refreshBook(_ bookId: String) async throws -> Book? {
        // Clear cached book first
        cacheService.removeCachedBook(id: bookId)
        
        // Fetch fresh data
        return try await fetchBook(by: bookId)
    }
    
    func refreshSummary(bookId: String) async throws -> Summary? {
        // Clear cached summary first
        cacheService.removeCachedSummary(bookId: bookId)
        
        // Fetch fresh data
        return try await fetchSummary(for: bookId)
    }
}

// MARK: - Response Models

private struct BooksResponse: Codable {
    let books: [Book]
    let total: Int
    let page: Int
    let totalPages: Int
}

private struct SearchResponse: Codable {
    let results: [Book]
}

struct SummaryGenerationJob: Codable {
    let id: String
    let bookId: String
    let status: JobStatus
    let message: String?
    
    enum JobStatus: String, Codable {
        case pending = "pending"
        case processing = "processing"
        case completed = "completed"
        case failed = "failed"
    }
}

private struct GenerateSummaryRequest: Codable {
    let style: String
}

private struct ImportBookRequest: Codable {
    let isbn: String
}