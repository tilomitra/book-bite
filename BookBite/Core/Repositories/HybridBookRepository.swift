import Foundation
import Network

class HybridBookRepository: BookRepository {
    private let remoteRepository = RemoteBookRepository()
    private let localRepository = LocalBookRepository()
    private let networkMonitor = NWPathMonitor()
    private var isConnected = true
    
    init() {
        startNetworkMonitoring()
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    // MARK: - BookRepository Implementation
    
    func fetchAllBooks() async throws -> [Book] {
        if isConnected {
            do {
                // Try remote first
                let books = try await remoteRepository.fetchAllBooks()
                
                // Cache successful results for offline use
                try? await cacheBooks(books)
                
                return books
            } catch {
                // Fall back to local on network error
                print("Remote fetch failed, falling back to local: \(error)")
                return try await localRepository.fetchAllBooks()
            }
        } else {
            // Use local when offline
            return try await localRepository.fetchAllBooks()
        }
    }
    
    func fetchBook(by id: String) async throws -> Book? {
        if isConnected {
            do {
                // Try remote first
                let book = try await remoteRepository.fetchBook(by: id)
                
                // Cache successful results
                if let book = book {
                    try? await cacheBook(book)
                }
                
                return book
            } catch {
                // Fall back to local on network error
                print("Remote book fetch failed, falling back to local: \(error)")
                return try await localRepository.fetchBook(by: id)
            }
        } else {
            // Use local when offline
            return try await localRepository.fetchBook(by: id)
        }
    }
    
    func fetchSummary(for bookId: String) async throws -> Summary? {
        if isConnected {
            do {
                // Try remote first
                let summary = try await remoteRepository.fetchSummary(for: bookId)
                
                // Cache successful results
                if let summary = summary {
                    try? await cacheSummary(summary)
                }
                
                return summary
            } catch {
                // Fall back to local on network error
                print("Remote summary fetch failed, falling back to local: \(error)")
                return try await localRepository.fetchSummary(for: bookId)
            }
        } else {
            // Use local when offline
            return try await localRepository.fetchSummary(for: bookId)
        }
    }
    
    func searchBooks(query: String) async throws -> [Book] {
        if isConnected {
            do {
                // Use remote search for better results
                return try await remoteRepository.searchBooks(query: query)
            } catch {
                // Fall back to local search
                print("Remote search failed, falling back to local: \(error)")
                return try await localRepository.searchBooks(query: query)
            }
        } else {
            // Use local search when offline
            return try await localRepository.searchBooks(query: query)
        }
    }
    
    // MARK: - Remote-Only Features (with offline awareness)
    
    func generateSummary(for bookId: String, style: Summary.SummaryStyle = .full) async throws -> SummaryGenerationJob? {
        guard isConnected else {
            throw RepositoryError.offlineError("Summary generation requires internet connection")
        }
        
        guard let remoteRepo = remoteRepository as? RemoteBookRepository else {
            throw RepositoryError.featureNotAvailable("Summary generation not available")
        }
        
        return try await remoteRepo.generateSummary(for: bookId, style: style)
    }
    
    func checkSummaryGenerationJob(jobId: String) async throws -> SummaryGenerationJob? {
        guard isConnected else {
            throw RepositoryError.offlineError("Job status check requires internet connection")
        }
        
        guard let remoteRepo = remoteRepository as? RemoteBookRepository else {
            throw RepositoryError.featureNotAvailable("Job status check not available")
        }
        
        return try await remoteRepo.checkSummaryGenerationJob(jobId: jobId)
    }
    
    func importBook(isbn: String) async throws -> Book? {
        guard isConnected else {
            throw RepositoryError.offlineError("Book import requires internet connection")
        }
        
        guard let remoteRepo = remoteRepository as? RemoteBookRepository else {
            throw RepositoryError.featureNotAvailable("Book import not available")
        }
        
        let book = try await remoteRepo.importBook(isbn: isbn)
        
        // Cache imported book for offline access
        try? await cacheBook(book)
        
        return book
    }
    
    // MARK: - Cache Management
    
    private func cacheBooks(_ books: [Book]) async throws {
        // This could be implemented to sync with local repository's cache
        // For now, we rely on the RemoteRepository's own caching
    }
    
    private func cacheBook(_ book: Book) async throws {
        // This could be implemented to sync with local repository's cache
        // For now, we rely on the RemoteRepository's own caching
    }
    
    private func cacheSummary(_ summary: Summary) async throws {
        // This could be implemented to sync with local repository's cache
        // For now, we rely on the RemoteRepository's own caching
    }
    
    func clearCache() {
        if let remoteRepo = remoteRepository as? RemoteBookRepository {
            remoteRepo.clearCache()
        }
    }
    
    func refreshBook(_ bookId: String) async throws -> Book? {
        guard isConnected else {
            // Return cached version when offline
            return try await localRepository.fetchBook(by: bookId)
        }
        
        guard let remoteRepo = remoteRepository as? RemoteBookRepository else {
            return try await fetchBook(by: bookId)
        }
        
        return try await remoteRepo.refreshBook(bookId)
    }
    
    func refreshSummary(bookId: String) async throws -> Summary? {
        guard isConnected else {
            // Return cached version when offline
            return try await localRepository.fetchSummary(for: bookId)
        }
        
        guard let remoteRepo = remoteRepository as? RemoteBookRepository else {
            return try await fetchSummary(for: bookId)
        }
        
        return try await remoteRepo.refreshSummary(bookId: bookId)
    }
    
    // MARK: - Status Properties
    
    var isOnline: Bool {
        return isConnected
    }
    
    var dataSourceStatus: DataSourceStatus {
        if isConnected {
            return .online
        } else {
            return .offline
        }
    }
}

// MARK: - Supporting Types

enum DataSourceStatus {
    case online
    case offline
    case syncing
}

extension RepositoryError {
    static func offlineError(_ message: String) -> RepositoryError {
        return RepositoryError.decodingError(message)
    }
    
    static func featureNotAvailable(_ message: String) -> RepositoryError {
        return RepositoryError.decodingError(message)
    }
}