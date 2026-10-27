import AppIntents
import SwiftUI
import UIKit

/// "Today's idea in BookBite": speaks the idea of the day and shows it as a snippet, without opening the app.
struct TodaysIdeaIntent: AppIntent {
    static let title: LocalizedStringResource = "Today's Idea"
    static let description = IntentDescription(
        "One key idea from one book, picked fresh each day.",
        categoryName: "Reading"
    )

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let today = Self.localDate()
        guard let idea = await fetchIdea(for: today) ?? Self.cachedIdea(for: today) else {
            throw TodaysIdeaError.unavailable
        }

        let cover = await Self.loadCover(for: idea.book)
        let byline = idea.book.authors.first.map { " by \($0)" } ?? ""
        let dialog = IntentDialog(
            full: "Today's idea, from \(idea.book.shelfTitle)\(byline): \(idea.idea.idea)",
            supporting: "From \(idea.book.shelfTitle)\(byline)."
        )
        return .result(dialog: dialog, view: DailyIdeaSnippetView(idea: idea, cover: cover))
    }

    @MainActor
    private func fetchIdea(for date: String) async -> DailyIdea? {
        guard let provider = DependencyContainer.shared.bookRepository as? DailyIdeaProviding else { return nil }
        return try? await provider.fetchDailyIdea(for: date)
    }

    /// The idea the app last handed the widget, if it is today's (works offline).
    private static func cachedIdea(for date: String) -> DailyIdea? {
        guard let data = UserDefaults(suiteName: WidgetBridge.appGroup)?.data(forKey: WidgetBridge.dailyIdeaKey),
              let idea = try? NetworkService.makeDecoder().decode(DailyIdea.self, from: data),
              idea.date == date else { return nil }
        return idea
    }

    /// The user's local day, so the idea changes at their midnight (same as Discover and the widget)
    private static func localDate() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    /// Downloaded up front: snippets are rendered out of process, where AsyncImage can't load.
    private static func loadCover(for book: Book) async -> UIImage? {
        guard let cover = book.coverAssetName, let url = URL.bookCover(from: cover) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 4
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return UIImage(data: data)
    }
}

enum TodaysIdeaError: Error, CustomLocalizedStringResourceConvertible {
    case unavailable

    var localizedStringResource: LocalizedStringResource {
        "Today's idea isn't available right now. Try again in a moment."
    }
}
