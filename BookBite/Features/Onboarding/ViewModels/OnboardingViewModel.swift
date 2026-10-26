import Foundation
import SwiftUI

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Step {
        case welcome, topics, notifications
    }

    @Published var step: Step = .welcome
    @Published var selectedGenres: Set<String> = Set(OnboardingPreferences.preferredGenres)
    /// Featured books for the welcome hero and the notification preview; empty until loaded or offline
    @Published private(set) var books: [Book] = []
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
            books = Array(withCovers.sorted { ($0.popularityScore ?? 0) > ($1.popularityScore ?? 0) }.prefix(12))
        }
        dailyIdea = await idea
    }

    func toggle(_ genre: String) {
        if selectedGenres.contains(genre) {
            selectedGenres.remove(genre)
        } else {
            selectedGenres.insert(genre)
        }
    }

    func saveTopics() {
        // Keep the onboarding order so Discover's shelf order is predictable
        OnboardingPreferences.preferredGenres = OnboardingPreferences.topics
            .map(\.genre)
            .filter { selectedGenres.contains($0) }
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
