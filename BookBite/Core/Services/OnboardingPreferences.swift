import Foundation

/// First-run onboarding state and the taste answers given during it: topics, reading goals and
/// books the reader loved. `FeaturedBooksViewModel` sends them to the server for personal shelves.
/// UI tests skip onboarding with the launch arguments `-hasCompletedOnboarding YES`.
enum OnboardingPreferences {
    static let completedKey = "hasCompletedOnboarding"
    /// Posted when topics or goals change after onboarding (Settings), so Discover rebuilds its shelves
    static let didChange = Notification.Name("OnboardingPreferencesDidChange")
    private static let genresKey = "preferredGenres"
    private static let goalsKey = "readingGoals"
    private static let likedBooksKey = "likedBookIds"

    /// Topics offered during onboarding. `genre` matches a Discover shelf in `FeaturedBooksViewModel`.
    static let topics: [(genre: String, label: String, icon: String)] = [
        ("Business", "Business", "briefcase"),
        ("Psychology", "Psychology", "brain.head.profile"),
        ("Self-Help", "Self-Help", "figure.mind.and.body"),
        ("Health", "Health", "heart"),
        ("History", "History", "building.columns"),
        ("Personal Development", "Personal Growth", "leaf"),
        ("Biography", "Biography", "person.text.rectangle"),
        ("Philosophy", "Philosophy", "lightbulb"),
        ("Economics", "Economics", "chart.line.uptrend.xyaxis"),
        ("Technology", "Technology", "cpu"),
        ("Politics", "Politics", "globe.americas"),
        ("Education", "Education", "graduationcap"),
        ("Arts & Culture", "Arts & Culture", "paintpalette"),
        ("Nature & Environment", "Nature & Environment", "tree")
    ]

    /// Reading goals offered during onboarding. `id` matches `READING_GOALS` in the server's
    /// recommendationService.ts, which holds the text that gets embedded.
    static let goals: [(id: String, label: String, icon: String)] = [
        ("habits", "Build better habits", "checkmark.circle"),
        ("work", "Grow at work", "person.3"),
        ("money", "Get better with money", "banknote"),
        ("mind", "Understand how people think", "brain"),
        ("health", "Feel healthier", "heart"),
        ("relationships", "Improve my relationships", "person.2"),
        ("meaning", "Find calm and meaning", "sun.horizon"),
        ("world", "Understand the world", "globe.europe.africa"),
        ("startup", "Start something", "sparkles"),
        ("creativity", "Be more creative", "paintbrush.pointed")
    ]

    static var preferredGenres: [String] {
        get { UserDefaults.standard.stringArray(forKey: genresKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: genresKey) }
    }

    /// Ids from `goals`
    static var readingGoals: [String] {
        get { UserDefaults.standard.stringArray(forKey: goalsKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: goalsKey) }
    }

    /// Books the reader picked as read or loved
    static var likedBookIds: [String] {
        get { UserDefaults.standard.stringArray(forKey: likedBooksKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: likedBooksKey) }
    }

    /// Call before the first read of `completedKey`: installs that already have a saved session or
    /// chose to browse as a guest predate onboarding and skip it.
    static func migrateExistingInstall() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: completedKey) == nil else { return }
        let returningUser = defaults.data(forKey: "supabaseSession") != nil
            || defaults.bool(forKey: "hasChosenAnonymous")
        if returningUser {
            defaults.set(true, forKey: completedKey)
        }
    }
}
