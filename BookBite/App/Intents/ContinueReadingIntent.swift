import AppIntents

/// "Continue reading in Bookgist": opens the app on the summary the user was last reading.
struct ContinueReadingIntent: AppIntent {
    static let title: LocalizedStringResource = "Continue Reading"
    static let description = IntentDescription(
        "Opens the summary you were last reading.",
        categoryName: "Reading"
    )
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let entry = ReadingProgressStore.shared.inProgress.first else {
            return .result(dialog: "You're not partway through a summary yet. Pick one in Discover.")
        }
        DeepLinkRouter.shared.open(entry.book)
        return .result(dialog: "Here's \(entry.book.shelfTitle), where you left off.")
    }
}
