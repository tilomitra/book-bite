import Foundation

/// What the app knows about the reader's taste, sent to `POST books/for-you`.
struct RecommendationRequest: Codable, Equatable {
    /// Books picked during onboarding as read or loved
    let likedBookIds: [String]
    /// Books opened in the app, newest first
    let recentBookIds: [String]
    /// Ids from `OnboardingPreferences.goals`
    let goals: [String]
    /// Discover shelf names from `OnboardingPreferences.topics`
    let genres: [String]

    var isEmpty: Bool {
        likedBookIds.isEmpty && recentBookIds.isEmpty && goals.isEmpty && genres.isEmpty
    }
}

/// Personal shelves ("For you", "More like …", goal shelves) plus a similarity score per book
/// (0–1, higher is closer to the reader's taste) used to order the genre shelves.
struct Recommendations: Codable {
    let shelves: [Shelf]
    let scores: [String: Double]

    struct Shelf: Codable, Identifiable {
        let id: String
        let kind: String
        let title: String
        let books: [Book]
    }
}
