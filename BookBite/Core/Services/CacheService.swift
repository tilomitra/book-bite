import Foundation

class CacheService {
    static let shared = CacheService()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsPath.appendingPathComponent("BookBiteCache")
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - File Paths
    
    private var booksPath: URL {
        cacheDirectory.appendingPathComponent("books.json")
    }
    
    private var summariesPath: URL {
        cacheDirectory.appendingPathComponent("summaries.json")
    }
    
    private var featuredBooksPath: URL {
        cacheDirectory.appendingPathComponent("featured_books.json")
    }
    
    private var nytBestsellerBooksPath: URL {
        cacheDirectory.appendingPathComponent("nyt_bestseller_books.json")
    }
    
    private func bookPath(id: String) -> URL {
        cacheDirectory.appendingPathComponent("book_\(id).json")
    }
    
    private func summaryPath(bookId: String) -> URL {
        cacheDirectory.appendingPathComponent("summary_\(bookId).json")
    }
    
    // MARK: - Book Caching
    
    func cacheBooks(_ books: [Book]) throws {
        let data = try JSONEncoder().encode(books)
        try data.write(to: booksPath)
    }
    
    func getCachedBooks() throws -> [Book]? {
        guard fileManager.fileExists(atPath: booksPath.path) else { return nil }
        
        let data = try Data(contentsOf: booksPath)
        return try JSONDecoder().decode([Book].self, from: data)
    }
    
    func cacheBook(_ book: Book) throws {
        let data = try JSONEncoder().encode(book)
        try data.write(to: bookPath(id: book.id))
    }
    
    func getCachedBook(id: String) throws -> Book? {
        let path = bookPath(id: id)
        guard fileManager.fileExists(atPath: path.path) else { return nil }
        
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode(Book.self, from: data)
    }
    
    func removeCachedBook(id: String) {
        let path = bookPath(id: id)
        try? fileManager.removeItem(at: path)
    }
    
    // MARK: - Featured Books Caching
    
    func cacheFeaturedBooks(_ books: [Book]) throws {
        let data = try JSONEncoder().encode(books)
        try data.write(to: featuredBooksPath)
    }
    
    func getCachedFeaturedBooks() throws -> [Book]? {
        guard fileManager.fileExists(atPath: featuredBooksPath.path) else { return nil }
        
        let data = try Data(contentsOf: featuredBooksPath)
        return try JSONDecoder().decode([Book].self, from: data)
    }
    
    // MARK: - NYT Bestseller Books Caching
    
    func cacheNYTBestsellerBooks(_ books: [Book]) throws {
        let data = try JSONEncoder().encode(books)
        try data.write(to: nytBestsellerBooksPath)
    }
    
    func getCachedNYTBestsellerBooks() throws -> [Book]? {
        guard fileManager.fileExists(atPath: nytBestsellerBooksPath.path) else { return nil }
        
        let data = try Data(contentsOf: nytBestsellerBooksPath)
        return try JSONDecoder().decode([Book].self, from: data)
    }
    
    // MARK: - Summary Caching
    
    func cacheSummary(_ summary: Summary) throws {
        let data = try JSONEncoder().encode(summary)
        try data.write(to: summaryPath(bookId: summary.bookId))
    }
    
    func getCachedSummary(bookId: String) throws -> Summary? {
        let path = summaryPath(bookId: bookId)
        guard fileManager.fileExists(atPath: path.path) else { return nil }
        
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode(Summary.self, from: data)
    }
    
    func removeCachedSummary(bookId: String) {
        let path = summaryPath(bookId: bookId)
        try? fileManager.removeItem(at: path)
    }
    
    // MARK: - Cache Management
    
    func clearAllCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func getCacheSize() -> Int64 {
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }
        
        return totalSize
    }
    
    func cleanOldCache(olderThan days: Int = 7) {
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(days * 24 * 60 * 60))
        
        guard let enumerator = fileManager.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return }
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.creationDateKey]),
                  let creationDate = resourceValues.creationDate else {
                continue
            }
            
            if creationDate < cutoffDate {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
    
    // MARK: - Cache Status
    
    func isBookCached(id: String) -> Bool {
        return fileManager.fileExists(atPath: bookPath(id: id).path)
    }
    
    func isSummaryCached(bookId: String) -> Bool {
        return fileManager.fileExists(atPath: summaryPath(bookId: bookId).path)
    }
    
    func getCacheInfo() -> CacheInfo {
        let size = getCacheSize()
        let fileCount = (try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil).count) ?? 0
        
        return CacheInfo(
            sizeInBytes: size,
            fileCount: fileCount,
            formattedSize: ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        )
    }
}

// MARK: - Supporting Types

struct CacheInfo {
    let sizeInBytes: Int64
    let fileCount: Int
    let formattedSize: String
}