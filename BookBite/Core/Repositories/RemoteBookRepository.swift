import Foundation
import Combine

class RemoteBookRepository: BookRepository, SummaryGenerationCapable, FavoriteRepository, DailyIdeaProviding, RecommendationsProviding, HighlightsProviding, AskProviding {
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
    
    func fetchDailyIdea(for date: String) async throws -> DailyIdea? {
        do {
            return try await networkService.get(endpoint: "summaries/daily-idea?date=\(date)")
        } catch let error as NetworkError {
            if case .clientError(404, _) = error {
                return nil
            }
            throw error
        }
    }

    func fetchRandomIdea(excluding bookId: String?) async throws -> DailyIdea? {
        let query = bookId.map { "?exclude=\($0)" } ?? ""
        do {
            return try await networkService.get(endpoint: "summaries/random-idea\(query)")
        } catch let error as NetworkError {
            if case .clientError(404, _) = error {
                return nil
            }
            throw error
        }
    }

    func fetchHighlights(page: Int, limit: Int) async throws -> HighlightsPage {
        return try await networkService.get(endpoint: "summaries/highlights?page=\(page)&limit=\(limit)")
    }

    func fetchRecommendations(_ request: RecommendationRequest) async throws -> Recommendations {
        return try await networkService.post(endpoint: "books/for-you", body: request)
    }

    func fetchAskHome(date: String) async throws -> AskHome {
        return try await networkService.get(endpoint: "ask/home?date=\(date)")
    }

    func fetchAskMatches(for question: String) async throws -> [Book] {
        let response: AskMatches = try await networkService.post(endpoint: "ask/matches", body: ["question": question])
        return response.books
    }

    /// Server-sent events: `sources`, then `delta`s, then `done` (or `error`)
    func ask(_ request: AskRequest) -> AsyncThrowingStream<AskStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let url = URL(string: "\(AppConfiguration.shared.baseServerURL)/ask") else {
                        throw NetworkError.invalidResponse
                    }
                    var urlRequest = URLRequest(url: url)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    urlRequest.timeoutInterval = 90
                    urlRequest.httpBody = try JSONEncoder().encode(request)

                    let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                    guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
                    guard http.statusCode == 200 else { throw NetworkError.unexpectedStatusCode(http.statusCode) }

                    let decoder = NetworkService.makeDecoder()
                    for try await line in bytes.lines where line.hasPrefix("data: ") {
                        let event = try decoder.decode(AskServerEvent.self, from: Data(line.dropFirst(6).utf8))
                        switch event.type {
                        case "sources": continuation.yield(.sources(event.books ?? []))
                        case "delta": continuation.yield(.delta(event.text ?? ""))
                        case "done":
                            continuation.finish()
                            return
                        case "error":
                            throw NetworkError.networkFailure(NSError(domain: "AskError", code: -1, userInfo: [NSLocalizedDescriptionKey: event.error ?? "Couldn’t answer that"]))
                        default: break
                        }
                    }
                    // The stream ended without `done`: the connection dropped mid-answer
                    throw NetworkError.invalidResponse
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func searchBooks(query: String) async throws -> [Book] {
        // For search, always go to server for fresh results
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? query
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
    
    // MARK: - FavoriteRepository Implementation
    
    /// /user/* routes require the signed-in user's Supabase access token
    @MainActor
    private func authHeaders() async throws -> [String: String] {
        guard let token = try await DependencyContainer.shared.authService.getAccessToken() else {
            throw NetworkError.clientError(401, Data())
        }
        return ["Authorization": "Bearer \(token)"]
    }
    
    func checkFavoriteStatus(for bookId: String) async throws -> Bool {
        struct FavoriteStatusResponse: Codable {
            let is_favorite: Bool
        }
        
        let response: FavoriteStatusResponse = try await networkService.get(endpoint: "user/favorites/\(bookId)", headers: await authHeaders())
        return response.is_favorite
    }
    
    func addToFavorites(_ bookId: String) async throws {
        let body = ["book_id": bookId]
        let _: EmptyResponse = try await networkService.post(endpoint: "user/favorites", body: body, headers: await authHeaders())
    }
    
    func removeFromFavorites(_ bookId: String) async throws {
        try await networkService.delete(endpoint: "user/favorites/\(bookId)", headers: await authHeaders())
    }
    
    func fetchFavorites() async throws -> [Book] {
        struct FavoritesResponse: Codable {
            let favorites: [FavoriteItem]

            struct FavoriteItem: Codable {
                let id: String
                let created_at: String
                let books: Book
            }
        }

        let response: FavoritesResponse = try await networkService.get(endpoint: "user/favorites", headers: await authHeaders())
        return response.favorites.map { $0.books }
    }

    func downloadFavoriteForOffline(_ book: Book) async throws {
        let offlineStorage = OfflineStorageService.shared

        // Fetch summary if available (don't fail if not available)
        var summary: Summary?
        do {
            summary = try await fetchSummary(for: book.id)
        } catch {
            if AppConfiguration.shared.isLoggingEnabled {
                print("⚠️ RemoteBookRepository: Summary not available for offline download: \(error)")
            }
        }

        // Save book and summary for offline
        try offlineStorage.downloadBookForOffline(book, summary: summary)

        // Download cover image if available
        if let coverURL = book.coverAssetName, !coverURL.isEmpty {
            do {
                try await offlineStorage.downloadCoverImage(from: coverURL, for: book.id)
            } catch {
                if AppConfiguration.shared.isLoggingEnabled {
                    print("⚠️ RemoteBookRepository: Cover image not available for offline download: \(error)")
                }
                // Don't fail - book is still usable without cover
            }
        }
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
    let bookId: String?
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

private struct EmptyResponse: Codable {
    // Empty struct for endpoints that don't return data
}

private struct AskServerEvent: Decodable {
    let type: String
    let books: [Book]?
    let text: String?
    let error: String?
}

