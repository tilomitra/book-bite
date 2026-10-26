import Foundation

/// First-run onboarding state and the topics picked during it (Discover shows those shelves first).
/// UI tests skip onboarding with the launch arguments `-hasCompletedOnboarding YES`.
enum OnboardingPreferences {
    static let completedKey = "hasCompletedOnboarding"
    private static let genresKey = "preferredGenres"

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

    static var preferredGenres: [String] {
        get { UserDefaults.standard.stringArray(forKey: genresKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: genresKey) }
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
