import Foundation
import UserNotifications

/// A local notification every morning pointing at the idea of the day.
/// The idea itself is only known on the day, so the reminder text is generic.
/// The pending request is the source of truth: Settings reads its time back with `scheduledTime()`.
enum DailyIdeaReminder {
    private static let identifier = "daily-idea-reminder"
    static let defaultTime = DateComponents(hour: 8, minute: 0)

    /// Asks for permission and schedules the reminder. Returns whether notifications are allowed.
    @discardableResult
    static func enable(at time: DateComponents = defaultTime) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }

        let content = UNMutableNotificationContent()
        content.title = "Your idea of the day"
        content.body = "One big idea from a great book. It takes a minute to read."
        content.sound = .default

        let components = DateComponents(hour: time.hour ?? 8, minute: time.minute ?? 0)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        return true
    }

    static func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Hour and minute of the scheduled reminder, or nil when it is off
    static func scheduledTime() async -> DateComponents? {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        guard let trigger = requests.first(where: { $0.identifier == identifier })?.trigger
                as? UNCalendarNotificationTrigger else { return nil }
        return DateComponents(hour: trigger.dateComponents.hour, minute: trigger.dateComponents.minute)
    }

    /// True when the user turned notifications off for BookBite in the Settings app
    static func isDenied() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }
}
