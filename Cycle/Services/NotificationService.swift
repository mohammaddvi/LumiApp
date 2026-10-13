import Foundation
import UserNotifications

enum LuneNotificationID {
    static let periodReminder = "lune.period.reminder"
    static let pmsReminder = "lune.pms.reminder"
    static let symptomReminder = "lune.symptom.reminder"
    static let checkInReminder = "lune.checkin.reminder"
    static let iMessagePeriod = "lune.imessage.period"
    static let iMessagePMS = "lune.imessage.pms"

    static let autoMessageCategory = "LUNE_AUTO_IMESSAGE"

    static var reminderIDs: [String] {
        [
            periodReminder, pmsReminder, symptomReminder, checkInReminder,
            iMessagePeriod, iMessagePMS
        ]
    }

    /// Scheduled ids carry a cycle suffix (`lune.period.reminder.1`); this returns the base id.
    static func baseID(_ id: String) -> String {
        guard let dot = id.lastIndex(of: "."), Int(id[id.index(after: dot)...]) != nil else { return id }
        return String(id[..<dot])
    }

    static func messageKind(forNotificationId id: String) -> ReminderMessageKind? {
        switch baseID(id) {
        case periodReminder, iMessagePeriod: .periodClose
        case pmsReminder, iMessagePMS: .pmsClose
        case symptomReminder: .custom
        default: nil
        }
    }
}

struct PendingIMessageDraft: Identifiable, Equatable, Sendable {
    let id = UUID()
    var kind: ReminderMessageKind
    var recipients: [String]
    var body: String
}

/// Bridges UserNotifications → AppEnvironment for automatic Messages drafts.
/// Installed at launch (Apple requires the delegate before launch finishes, or taps that open the
/// app are lost); taps that arrive before the environment exists wait until `configure` runs.
final class LuneNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = LuneNotificationDelegate()

    @MainActor
    weak var environment: AppEnvironment?

    @MainActor
    private var pendingTaps: [(id: String, autoPresentMessage: Bool)] = []

    /// Call from `App.init`.
    @MainActor
    func install() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let sendAction = UNNotificationAction(
            identifier: "LUNE_SEND_IMESSAGE",
            title: "Send iMessage",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: LuneNotificationID.autoMessageCategory,
            actions: [sendAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    @MainActor
    func configure(environment: AppEnvironment) {
        self.environment = environment
        let waiting = pendingTaps
        pendingTaps = []
        for tap in waiting {
            environment.handleReminderNotification(id: tap.id, autoPresentMessage: tap.autoPresentMessage)
        }
    }

    @MainActor
    private func handle(id: String, autoPresentMessage: Bool) {
        if let environment {
            environment.handleReminderNotification(id: id, autoPresentMessage: autoPresentMessage)
        } else {
            pendingTaps.append((id, autoPresentMessage))
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let id = notification.request.identifier
        await MainActor.run {
            handle(id: id, autoPresentMessage: true)
        }
        return [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let id = response.notification.request.identifier
        let forceMessage = response.actionIdentifier == "LUNE_SEND_IMESSAGE"
            || response.actionIdentifier == UNNotificationDefaultActionIdentifier
        await MainActor.run {
            handle(id: id, autoPresentMessage: forceMessage)
        }
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
            if let category = reminder.category {
                content.categoryIdentifier = category
            }
            let trigger = UNCalendarNotificationTrigger(dateMatching: reminder.fireDate, repeats: reminder.repeats)
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }
}
