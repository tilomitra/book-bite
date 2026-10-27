import AppIntents

/// Siri phrases and Shortcuts/Spotlight actions, available without any setup.
struct BookBiteShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TodaysIdeaIntent(),
            phrases: [
                "Today's idea in \(.applicationName)",
                "What's today's idea in \(.applicationName)",
                "Get the idea of the day from \(.applicationName)",
            ],
            shortTitle: "Today's Idea",
            systemImageName: "quote.opening"
        )
        AppShortcut(
            intent: ContinueReadingIntent(),
            phrases: [
                "Continue reading in \(.applicationName)",
                "Keep reading in \(.applicationName)",
                "Resume my summary in \(.applicationName)",
            ],
            shortTitle: "Continue Reading",
            systemImageName: "book"
        )
    }
}
