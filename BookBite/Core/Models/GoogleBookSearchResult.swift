import Foundation

struct GoogleBookSearchResult: Identifiable, Codable {
    let googleBooksId: String
    let title: String
    let subtitle: String?
    let authors: [String]
    let description: String?
    let categories: [String]
    let publisher: String?
    let publishedYear: Int?
    let isbn10: String?
    let isbn13: String?
    let coverUrl: String?
    let inDatabase: Bool
    
    enum CodingKeys: String, CodingKey {
        case googleBooksId, title, subtitle, authors, description, categories
        case publisher, publishedYear, isbn10, isbn13, coverUrl, inDatabase
    }
    
    var id: String { googleBooksId }
    
    var formattedAuthors: String {
        authors.joined(separator: ", ")
    }
    
    var formattedCategories: String {
        categories.joined(separator: " • ")
    }
}

struct GoogleBookSearchResponse: Codable {
    let query: String
    let total: Int
    let results: [GoogleBookSearchResult]
}

struct BookWithSummary: Codable {
    let book: Book
    let summary: Summary?
    
    init(from decoder: Decoder) throws {
        // Handle both nested and flat structure from server
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode as nested book first
        if let bookData = try? container.decode(Book.self, forKey: .book) {
            self.book = bookData
            self.summary = try? container.decode(Summary.self, forKey: .summary)
        } else {
            // Fall back to flat structure (book properties at root level)
            self.book = try Book(from: decoder)
            self.summary = try? container.decode(Summary.self, forKey: .summary)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case book, summary
    }
}

struct BookRequestResponse: Codable {
    let message: String
    let book: BookWithSummary
    let warning: String?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.message = try container.decode(String.self, forKey: .message)
        self.warning = try? container.decode(String.self, forKey: .warning)
        
        // The server sends book data with embedded summary
        // Try to decode the complex structure
        if let bookContainer = try? container.decode(BookWithSummary.self, forKey: .book) {
            self.book = bookContainer
        } else {
            // Fallback: decode book without summary
            let plainBook = try container.decode(Book.self, forKey: .book)
            self.book = BookWithSummary(book: plainBook, summary: nil)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case message, book, warning
    }
}

extension BookWithSummary {
    init(book: Book, summary: Summary?) {
        self.book = book
        self.summary = summary
    }
}

struct BookRequestPayload: Codable {
    let googleBooksId: String
}

struct ExistingBookResponse: Codable {
    let book: BookWithSummary
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode as BookWithSummary first
        if let bookWithSummary = try? container.decode(BookWithSummary.self, forKey: .book) {
            self.book = bookWithSummary
        } else {
            // Fallback to plain book
            let plainBook = try container.decode(Book.self, forKey: .book)
            self.book = BookWithSummary(book: plainBook, summary: nil)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case book
    }
}

enum RequestState {
    case idle
    case searching
    case searchResults([GoogleBookSearchResult])
    case requestingBook(GoogleBookSearchResult)
    case bookRequested(Book)
    case error(String)
}