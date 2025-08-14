import Foundation

struct Book: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let authors: [String]
    let isbn10: String?
    let isbn13: String?
    let publishedYear: Int
    let publisher: String?
    let categories: [String]
    let coverAssetName: String
    let description: String
    let sourceAttribution: [String]
    
    var formattedAuthors: String {
        authors.joined(separator: ", ")
    }
    
    var formattedCategories: String {
        categories.joined(separator: " • ")
    }
}