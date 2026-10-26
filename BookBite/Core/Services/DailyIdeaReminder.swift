import Foundation
import UserNotifications

/// A local notification every morning pointing at the idea of the day.
/// The idea itself is only known on the day, so the reminder text is generic.
enum DailyIdeaReminder {
    private static let identifier = "daily-idea-reminder"

    /// Asks for permission and schedules the reminder. Returns whether notifications are allowed.
    @discardableResult
    static func enable(hour: Int = 8) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }

        let content = UNMutableNotificationContent()
        content.title = "Your idea of the day"
        content.body = "One big idea from a great book. It takes a minute to read."
        content.sound = .default

        var time = DateComponents()
        time.hour = hour
        time.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)

        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        return true
    }
}
