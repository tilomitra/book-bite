import Foundation
import PostHog

/// Product analytics (PostHog). Events are a closed list on purpose: nothing a reader writes, such as
/// Ask questions, can reach an event. Off without a project key, and after the Settings switch.
enum AnalyticsEvent {
    case onboardingCompleted(topics: Int, goals: Int, likedBooks: Int)
    case signInPromptShown(reason: String)
    case bookViewed(Book)
    case bookSaved(Book)
    case readingStarted(Book)
    case readingFinished(Book)
    case audioStarted(Book)
    case ideaSaved(Book)
    case askSent(isFollowUp: Bool)
    case readingPassViewed
    case inviteRedeemed
    case subscriptionStarted
    case getBookClicked(Book, store: String)

    var name: String {
        switch self {
        case .onboardingCompleted: return "onboarding_completed"
        case .signInPromptShown: return "sign_in_prompt_shown"
        case .bookViewed: return "book_viewed"
        case .bookSaved: return "book_saved"
        case .readingStarted: return "reading_started"
        case .readingFinished: return "reading_finished"
        case .audioStarted: return "audio_started"
        case .ideaSaved: return "idea_saved"
        case .askSent: return "ask_sent"
        case .readingPassViewed: return "reading_pass_viewed"
        case .inviteRedeemed: return "invite_redeemed"
        case .subscriptionStarted: return "subscription_started"
        case .getBookClicked: return "get_book_clicked"
        }
    }

    var properties: [String: Any] {
        switch self {
        case .onboardingCompleted(let topics, let goals, let likedBooks):
            return ["topics": topics, "goals": goals, "liked_books": likedBooks]
        case .signInPromptShown(let reason):
            return ["reason": reason]
        case .bookViewed(let book), .bookSaved(let book), .readingStarted(let book),
             .readingFinished(let book), .audioStarted(let book), .ideaSaved(let book):
            return ["book_id": book.id, "book_title": book.title]
        case .askSent(let isFollowUp):
            return ["is_follow_up": isFollowUp]
        case .getBookClicked(let book, let store):
            return ["book_id": book.id, "book_title": book.title, "store": store]
        case .readingPassViewed, .inviteRedeemed, .subscriptionStarted:
            return [:]
        }
    }
}

enum Analytics {
    static let enabledKey = "analyticsEnabled"
    private static let identifiedUserKey = "analyticsIdentifiedUser"
    private static var isStarted = false

    /// Release builds read the key from Info.plist (`POSTHOG_PROJECT_KEY` build setting). Debug builds
    /// send nothing unless launched with that env var, so development stays out of the numbers.
    private static var projectKey: String? {
        #if DEBUG
        let key = ProcessInfo.processInfo.environment["POSTHOG_PROJECT_KEY"]
        #else
        let key = Bundle.main.object(forInfoDictionaryKey: "PostHogProjectKey") as? String
        #endif
        return key?.isEmpty == false ? key : nil
    }

    static func start() {
        guard !isStarted, let projectKey else { return }
        let config = PostHogConfig(apiKey: projectKey, host: "https://us.i.posthog.com")
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = false
        config.preloadFeatureFlags = false
        config.personProfiles = .identifiedOnly
        PostHogSDK.shared.setup(config)
        isStarted = true
        setEnabled(UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true)
    }

    static func setEnabled(_ enabled: Bool) {
        guard isStarted else { return }
        if enabled {
            PostHogSDK.shared.optIn()
        } else {
            PostHogSDK.shared.optOut()
        }
    }

    static func capture(_ event: AnalyticsEvent) {
        guard isStarted else { return }
        PostHogSDK.shared.capture(event.name, properties: event.properties)
    }

    /// Call when the signed-in user changes. Only the Supabase user id is sent, never email or name.
    /// Signing out starts a new anonymous id, so the next person on this device isn't linked.
    static func identify(_ userId: String?) {
        guard isStarted else { return }
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: identifiedUserKey)
        guard userId != previous else { return }
        if let userId {
            PostHogSDK.shared.identify(userId)
            defaults.set(userId, forKey: identifiedUserKey)
        } else {
            PostHogSDK.shared.reset()
            defaults.removeObject(forKey: identifiedUserKey)
        }
    }
}
