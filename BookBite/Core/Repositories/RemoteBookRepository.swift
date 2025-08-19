import Foundation
import Combine

class RemoteBookRepository: BookRepository, SummaryGenerationCapable {
    private let networkService = NetworkService.shared
    private let cacheService = CacheService.shared
    
    // MARK: - BookRepository Implementation
    
    func fetchAllBooks() async throws -> [Book] {
        let response: BooksResponse = try await networkService.get(endpoint: "books")
        let books = response.books
        
        // Cache the results for performance
        try? cacheService.cacheBooks(books)
        
        return books
    }
    
    func fetchFeaturedBooks() async throws -> [Book] {
        // Fetch books marked as featured (is_featured = true)
        let endpoint = "books/featured"
        let freshEndpoint = "\(endpoint)?fresh=true"
        let response: BooksResponse = try await networkService.get(endpoint: freshEndpoint)
        let books = response.books.filter { $0.isFeatured == true }
        
        // Cache the results for performance
        try? cacheService.cacheFeaturedBooks(books)
        
        return books
    }
    
    func fetchNYTBestsellerBooks() async throws -> [Book] {
        // Fetch all NYT bestsellers (is_nyt_bestseller = true)
        let endpoint = "books/nyt-bestsellers"
        let freshEndpoint = "\(endpoint)?fresh=true"
        let response: BooksResponse = try await networkService.get(endpoint: freshEndpoint)
        let books = response.books
        
        // Cache the results for performance
        try? cacheService.cacheNYTBestsellerBooks(books)
        
        return books
    }
    
    func fetchBook(by id: String) async throws -> Book? {
        do {
            let book: Book = try await networkService.get(endpoint: "books/\(id)")
            
            // Cache the result for performance
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
        do {
            let summary: Summary = try await networkService.get(endpoint: "summaries/book/\(bookId)")
            
            // Cache the result for performance
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
    
    func fetchCategories() async throws -> [BookCategory] {
        struct CategoryResponse: Codable {
            let name: String
            let count: Int
        }
        
        let response: [CategoryResponse] = try await networkService.get(endpoint: "books/categories")
        
        return response.map { categoryResponse in
            BookCategory(
                name: categoryResponse.name,
                iconName: BookCategory.getCategoryIcon(for: categoryResponse.name),
                bookCount: categoryResponse.count
            )
        }
    }
    
    func fetchBooksByCategory(_ category: String, page: Int, limit: Int) async throws -> [Book] {
        let encodedCategory = category.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? category
        let endpoint = "books/category/\(encodedCategory)?page=\(page)&limit=\(limit)"
        
        struct CategoryBooksResponse: Codable {
            let books: [Book]
            let page: Int
            let limit: Int
            let total: Int
            let totalPages: Int
        }
        
        let response: CategoryBooksResponse = try await networkService.get(endpoint: endpoint)
        return response.books
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