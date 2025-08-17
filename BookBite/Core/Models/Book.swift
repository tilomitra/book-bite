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
    let coverAssetName: String?
    let description: String?
    let sourceAttribution: [String]
    let popularityRank: Int?
    let isFeatured: Bool?
    let isNYTBestseller: Bool?
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
    
    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        authors: [String] = [],
        isbn10: String? = nil,
        isbn13: String? = nil,
        publishedYear: Int? = nil,
        publisher: String? = nil,
        categories: [String] = [],
        coverAssetName: String? = nil,
        description: String? = nil,
        sourceAttribution: [String] = [],
        popularityRank: Int? = nil,
        isFeatured: Bool? = false,
        isNYTBestseller: Bool? = false,
        nytRank: Int? = nil,
        nytWeeksOnList: Int? = nil,
        nytList: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.authors = authors
        self.isbn10 = isbn10
        self.isbn13 = isbn13
        self.publishedYear = publishedYear
        self.publisher = publisher
        self.categories = categories
        self.coverAssetName = coverAssetName
        self.description = description
        self.sourceAttribution = sourceAttribution
        self.popularityRank = popularityRank
        self.isFeatured = isFeatured
        self.isNYTBestseller = isNYTBestseller
        self.nytRank = nytRank
        self.nytWeeksOnList = nytWeeksOnList
        self.nytList = nytList
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        authors = try container.decodeIfPresent([String].self, forKey: .authors) ?? []
        isbn10 = try container.decodeIfPresent(String.self, forKey: .isbn10)
        isbn13 = try container.decodeIfPresent(String.self, forKey: .isbn13)
        publishedYear = try container.decodeIfPresent(Int.self, forKey: .publishedYear)
        publisher = try container.decodeIfPresent(String.self, forKey: .publisher)
        categories = try container.decodeIfPresent([String].self, forKey: .categories) ?? []
        coverAssetName = try container.decodeIfPresent(String.self, forKey: .coverAssetName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        sourceAttribution = try container.decodeIfPresent([String].self, forKey: .sourceAttribution) ?? []
        popularityRank = try container.decodeIfPresent(Int.self, forKey: .popularityRank)
        isFeatured = try container.decodeIfPresent(Bool.self, forKey: .isFeatured) ?? false
        isNYTBestseller = try container.decodeIfPresent(Bool.self, forKey: .isNYTBestseller) ?? false
        nytRank = try container.decodeIfPresent(Int.self, forKey: .nytRank)
        nytWeeksOnList = try container.decodeIfPresent(Int.self, forKey: .nytWeeksOnList)
        nytList = try container.decodeIfPresent(String.self, forKey: .nytList)
    }
    
    var formattedAuthors: String {
        authors.joined(separator: ", ")
    }
    
    var formattedCategories: String {
        categories.joined(separator: " • ")
    }
    
    var nytBestsellerInfo: String? {
        guard isNYTBestseller == true else { return nil }
        
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