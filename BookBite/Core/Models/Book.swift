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
    let description: String?
    let sourceAttribution: [String]
    let popularityRank: Int?
    let isFeatured: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, authors, isbn10, isbn13, publisher, categories, description
        case publishedYear = "published_year"
        case coverAssetName = "cover_url"
        case sourceAttribution = "source_attribution"
        case popularityRank = "popularity_rank"
        case isFeatured = "is_featured"
    }
    
    var formattedAuthors: String {
        authors.joined(separator: ", ")
    }
    
    var formattedCategories: String {
        categories.joined(separator: " • ")
    }
}