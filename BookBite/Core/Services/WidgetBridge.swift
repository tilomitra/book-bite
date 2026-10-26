import Foundation
import WidgetKit

/// Shares data with the idea-of-the-day widget (`BookBiteWidget` target) through the app group.
/// The widget fetches the idea itself; the app gives it the server URL and its latest idea as a fallback.
enum WidgetBridge {
    static let appGroup = "group.tilo.BookBite"
    static let serverURLKey = "serverBaseURL"
    static let dailyIdeaKey = "dailyIdea"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func publishServerURL(_ url: String) {
        guard defaults?.string(forKey: serverURLKey) != url else { return }
        defaults?.set(url, forKey: serverURLKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func publish(_ dailyIdea: DailyIdea) {
        guard let data = try? JSONEncoder().encode(dailyIdea),
              defaults?.data(forKey: dailyIdeaKey) != data else { return }
        defaults?.set(data, forKey: dailyIdeaKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
