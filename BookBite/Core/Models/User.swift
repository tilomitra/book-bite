import Foundation

struct User: Codable, Identifiable {
    let id: String
    let email: String?
    let createdAt: Date
    let updatedAt: Date?
    
    // Profile information
    var displayName: String?
    var avatarURL: String?
    var bio: String?
    
    // Preferences
    var favoriteCategories: [String]?
    var readingGoal: Int?
    
    // Statistics
    var booksRead: Int?
    var totalReadingTime: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case bio
        case favoriteCategories = "favorite_categories"
        case readingGoal = "reading_goal"
        case booksRead = "books_read"
        case totalReadingTime = "total_reading_time"
    }
}

// MARK: - Auth State
enum AuthState: Equatable {
    case authenticated(User)
    case anonymous
    case unauthenticated
    case loading
    
    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.authenticated(let user1), .authenticated(let user2)):
            return user1.id == user2.id
        case (.anonymous, .anonymous):
            return true
        case (.unauthenticated, .unauthenticated):
            return true
        case (.loading, .loading):
            return true
        default:
            return false
        }
    }
    
    var isAuthenticated: Bool {
        if case .authenticated = self {
            return true
        }
        return false
    }
    
    var isAnonymous: Bool {
        if case .anonymous = self {
            return true
        }
        return false
    }
    
    var user: User? {
        if case .authenticated(let user) = self {
            return user
        }
        return nil
    }
}