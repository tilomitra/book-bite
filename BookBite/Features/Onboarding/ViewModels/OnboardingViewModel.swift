import Foundation
import SwiftUI

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Step {
        case welcome, topics, goals, books, notifications
    }

    @Published var step: Step = .welcome
    @Published var selectedGenres: Set<String> = Set(OnboardingPreferences.preferredGenres)
    @Published var selectedGoals: Set<String> = Set(OnboardingPreferences.readingGoals)
    @Published var likedBookIds: Set<String> = Set(OnboardingPreferences.likedBookIds)
    /// Featured books for the welcome hero and the notification preview; empty until loaded or offline
    @Published private(set) var books: [Book] = []
    /// Popular featured books with covers, for "Pick books you've loved"
    @Published private(set) var popularBooks: [Book] = []
    @Published private(set) var dailyIdea: DailyIdea?

    private let bookRepository: BookRepository

    init(bookRepository: BookRepository) {
        self.bookRepository = bookRepository
    }

    func load() async {
        guard books.isEmpty else { return }

        async let idea = fetchDailyIdea()
        if let featured = try? await bookRepository.fetchFeaturedBooks() {
            let withCovers = featured.filter { $0.coverAssetName?.isEmpty == false }
                .sorted { ($0.popularityScore ?? 0) > ($1.popularityScore ?? 0) }
            books = Array(withCovers.prefix(12))
            popularBooks = Array(withCovers.prefix(36))
        }
        dailyIdea = await idea
    }

    func toggle(_ genre: String) {
        selectedGenres.formSymmetricDifference([genre])
    }

    func toggleGoal(_ id: String) {
        selectedGoals.formSymmetricDifference([id])
    }

    func toggleLiked(_ bookId: String) {
        likedBookIds.formSymmetricDifference([bookId])
    }

    /// Popular books, those in the picked topics first, so the grid feels relevant
    var pickerBooks: [Book] {
        let keywords = selectedGenres.compactMap { $0.lowercased().split(separator: " ").first.map(String.init) }
        guard !keywords.isEmpty else { return popularBooks }
        func matches(_ book: Book) -> Bool {
            book.categories.contains { category in keywords.contains { category.lowercased().contains($0) } }
        }
        return popularBooks.filter(matches) + popularBooks.filter { !matches($0) }
    }

    func saveTopics() {
        // Keep the onboarding order so Discover's shelf order is predictable
        OnboardingPreferences.preferredGenres = OnboardingPreferences.topics
            .map(\.genre)
            .filter { selectedGenres.contains($0) }
    }

    func saveGoals() {
        OnboardingPreferences.readingGoals = OnboardingPreferences.goals
            .map(\.id)
            .filter { selectedGoals.contains($0) }
    }

    func saveLikedBooks() {
        // In grid order, so the first picks seed the "More like …" shelves
        OnboardingPreferences.likedBookIds = pickerBooks.map(\.id).filter { likedBookIds.contains($0) }
    }

    private func fetchDailyIdea() async -> DailyIdea? {
        guard let provider = bookRepository as? DailyIdeaProviding else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return try? await provider.fetchDailyIdea(for: formatter.string(from: Date()))
    }
}
