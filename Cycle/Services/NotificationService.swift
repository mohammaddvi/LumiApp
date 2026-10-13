import Foundation
import UserNotifications

enum LuneNotificationID {
    static let periodReminder = "lune.period.reminder"
    static let pmsReminder = "lune.pms.reminder"
    static let symptomReminder = "lune.symptom.reminder"
    static let checkInReminder = "lune.checkin.reminder"
}

/// Shows Lumi's reminders while the app is open; a tap simply opens the app.
/// Installed at launch: Apple requires the delegate before launch finishes.
final class LuneNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = LuneNotificationDelegate()

    /// Call from `App.init`.
    @MainActor
    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    // Completion-handler versions on purpose: the async versions finished iOS's completion handler
    // off the main thread, and UIKit aborted when a tap launched the app.

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let completion = MainThreadCompletion(completionHandler)
        Task { @MainActor in
            completion.call([.banner, .sound, .list])
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let completion = MainThreadCompletion(completionHandler)
        Task { @MainActor in
            completion.call(())
        }
    }
}

/// Carries a UserNotifications completion handler to the main actor, where it is called exactly once.
private struct MainThreadCompletion<Value>: @unchecked Sendable {
    private let handler: (Value) -> Void

    init(_ handler: @escaping (Value) -> Void) {
        self.handler = handler
    }

    @MainActor
    func call(_ value: Value) {
        handler(value)
    }
}

@MainActor
@Observable
final class NotificationService {
    private let center = UNUserNotificationCenter.current()

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Replaces every pending Lumi reminder with a fresh plan for the next few predicted periods.
    func reschedule(preferences: UserPreferences, periodStarts: [Date]) async {
        let ours = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix("lune.") }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        let plan = ReminderPlanner.plan(preferences: preferences, periodStarts: periodStarts)
        guard !plan.isEmpty else { return }

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        for reminder in plan {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: reminder.fireDate, repeats: reminder.repeats)
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }
}
