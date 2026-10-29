import Foundation

/// Settings → Notifications: the daily idea reminder's switch and time. The pending notification
/// request is the source of truth, so this reads it back on appear instead of keeping its own copy.
@MainActor
final class ReminderSettingsViewModel: ObservableObject {
    @Published private(set) var isOn = false
    @Published private(set) var time: Date = ReminderSettingsViewModel.date(from: DailyIdeaReminder.defaultTime)
    /// Notifications are off for BookBite in the Settings app; the switch can't help until they're back on
    @Published private(set) var isDenied = false
    @Published private(set) var isLoaded = false

    func load() async {
        let scheduled = await DailyIdeaReminder.scheduledTime()
        isOn = scheduled != nil
        if let scheduled { time = Self.date(from: scheduled) }
        isDenied = await DailyIdeaReminder.isDenied()
        isLoaded = true
    }

    func setOn(_ on: Bool) async {
        if on {
            isOn = true
            let allowed = await DailyIdeaReminder.enable(at: components)
            isOn = allowed
            if !allowed {
                isDenied = await DailyIdeaReminder.isDenied()
            }
        } else {
            DailyIdeaReminder.disable()
            isOn = false
        }
    }

    func setTime(_ newTime: Date) async {
        time = newTime
        guard isOn else { return }
        await DailyIdeaReminder.enable(at: components)
    }

    private var components: DateComponents {
        Calendar.current.dateComponents([.hour, .minute], from: time)
    }

    private static func date(from components: DateComponents) -> Date {
        Calendar.current.date(bySettingHour: components.hour ?? 8, minute: components.minute ?? 0,
                              second: 0, of: .now) ?? .now
    }
}
