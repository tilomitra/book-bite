import Foundation

class LocalBookRepository: BookRepository {
    private var books: [Book] = []
    private var summaries: [Summary] = []
    private let decoder = JSONDecoder()
    
    init() {
        Task {
            await loadData()
        }
    }
    
    private func loadData() async {
        do {
            books = try await loadBooks()
            summaries = try await loadSummaries()
        } catch {
            print("Error loading data: \(error)")
        }
    }
    
    private func loadBooks() async throws -> [Book] {
        guard let url = Bundle.main.url(forResource: "books", withExtension: "json") else {
            throw RepositoryError.fileNotFound("books.json")
        }
        
        let data = try Data(contentsOf: url)
        return try decoder.decode([Book].self, from: data)
    }
    
    private func loadSummaries() async throws -> [Summary] {
        guard let url = Bundle.main.url(forResource: "summaries", withExtension: "json") else {
            throw RepositoryError.fileNotFound("summaries.json")
        }
        
        let data = try Data(contentsOf: url)
        return try decoder.decode([Summary].self, from: data)
    }
    
    func fetchAllBooks() async throws -> [Book] {
        if books.isEmpty {
            await loadData()
        }
        
        try await Task.sleep(nanoseconds: 200_000_000)
        return books
    }
    
    func fetchBook(by id: String) async throws -> Book? {
        if books.isEmpty {
            await loadData()
        }
        
        try await Task.sleep(nanoseconds: 100_000_000)
        return books.first { $0.id == id }
    }
    
    func fetchSummary(for bookId: String) async throws -> Summary? {
        if summaries.isEmpty {
            await loadData()
        }
        
        try await Task.sleep(nanoseconds: 150_000_000)
        return summaries.first { $0.bookId == bookId }
    }
    
    func searchBooks(query: String) async throws -> [Book] {
        if books.isEmpty {
            await loadData()
        }
        
        let lowercasedQuery = query.lowercased()
        
        if lowercasedQuery.isEmpty {
            return books
        }
        
        try await Task.sleep(nanoseconds: 50_000_000)
        
        return books.filter { book in
            book.title.lowercased().contains(lowercasedQuery) ||
            book.subtitle?.lowercased().contains(lowercasedQuery) ?? false ||
            book.authors.contains { $0.lowercased().contains(lowercasedQuery) } ||
            book.categories.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }
}

enum RepositoryError: LocalizedError {
    case fileNotFound(String)
    case decodingError(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let filename):
            return "Could not find file: \(filename)"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        }
    }
}