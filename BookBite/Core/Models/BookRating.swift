import Foundation

class BookRating: NSObject, Codable {
    let average: Double
    let count: Int
    let distribution: RatingDistribution?
    let source: String
    
    init(average: Double, count: Int, distribution: RatingDistribution? = nil, source: String) {
        self.average = average
        self.count = count
        self.distribution = distribution
        self.source = source
        super.init()
    }
    
    struct RatingDistribution: Codable, Hashable {
        let one: Int?
        let two: Int?
        let three: Int?
        let four: Int?
        let five: Int?
        
        enum CodingKeys: String, CodingKey {
            case one = "1"
            case two = "2"
            case three = "3"
            case four = "4"
            case five = "5"
        }
    }
    
    var formattedAverage: String {
        String(format: "%.1f", average)
    }
    
    var formattedCount: String {
        if count >= 1000 {
            let thousands = Double(count) / 1000.0
            return String(format: "%.1fk", thousands)
        }
        return "\(count)"
    }
    
    var starIcons: String {
        let fullStars = Int(average)
        let hasHalfStar = average - Double(fullStars) >= 0.5
        
        var stars = String(repeating: "★", count: fullStars)
        if hasHalfStar && fullStars < 5 {
            stars += "☆"
        }
        let emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0)
        stars += String(repeating: "☆", count: emptyStars)
        
        return stars
    }
}

struct BookReview: Codable, Hashable, Identifiable {
    let id: String
    let rating: Int
    let text: String?
    let author: String?
    let date: String?
    let source: String
    let helpfulCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, rating, text, author, date, source
        case helpfulCount = "helpful_count"
    }
    
    var formattedDate: String? {
        guard let date = date else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let dateObj = formatter.date(from: date) {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: dateObj)
        }
        
        return date
    }
    
    var starIcons: String {
        let fullStars = String(repeating: "★", count: rating)
        let emptyStars = String(repeating: "☆", count: 5 - rating)
        return fullStars + emptyStars
    }
}

// Response models for API calls
struct BookRatingResponse: Codable {
    let bookId: String
    let rating: BookRating
    
    enum CodingKeys: String, CodingKey {
        case bookId = "book_id"
        case rating
    }
}

struct BookReviewsResponse: Codable {
    let bookId: String
    let reviews: [BookReview]
    let pagination: ReviewPagination?
    
    enum CodingKeys: String, CodingKey {
        case bookId = "book_id"
        case reviews
        case pagination
    }
}

struct ReviewPagination: Codable {
    let page: Int
    let totalPages: Int
    let totalReviews: Int
    
    enum CodingKeys: String, CodingKey {
        case page, totalPages = "total_pages", totalReviews = "total_reviews"
    }
}