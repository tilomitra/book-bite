import Foundation

struct Book: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let authors: [String]
    let isbn10: String?
    let isbn13: String?
    let publishedYear: Int?
    let publisher: String?
    let categories: [String]
    let coverAssetName: String
    let description: String?
    let sourceAttribution: [String]
    let popularityRank: Int?
    let isFeatured: Bool
    let isNYTBestseller: Bool
    let nytRank: Int?
    let nytWeeksOnList: Int?
    let nytList: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, authors, isbn10, isbn13, publisher, categories, description
        case publishedYear = "published_year"
        case coverAssetName = "cover_url"
        case sourceAttribution = "source_attribution"
        case popularityRank = "popularity_rank"
        case isFeatured = "is_featured"
        case isNYTBestseller = "is_nyt_bestseller"
        case nytRank = "nyt_rank"
        case nytWeeksOnList = "nyt_weeks_on_list"
        case nytList = "nyt_list"
    }
    
    var formattedAuthors: String {
        authors.joined(separator: ", ")
    }
    
    var formattedCategories: String {
        categories.joined(separator: " • ")
    }
    
    var nytBestsellerInfo: String? {
        guard isNYTBestseller else { return nil }
        
        var info = ""
        if let rank = nytRank {
            info += "NYT #\(rank)"
        }
        if let weeks = nytWeeksOnList, weeks > 1 {
            info += info.isEmpty ? "\(weeks) weeks" : " • \(weeks) weeks"
        }
        return info.isEmpty ? nil : info
    }
}