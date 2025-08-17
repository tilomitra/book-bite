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

struct BookRequestResponse: Codable {
    let message: String
    let book: Book
    let warning: String?
}

struct BookRequestPayload: Codable {
    let googleBooksId: String
}

struct ExistingBookResponse: Codable {
    let book: Book
}

enum RequestState {
    case idle
    case searching
    case searchResults([GoogleBookSearchResult])
    case requestingBook(GoogleBookSearchResult)
    case bookRequested(Book)
    case error(String)
}