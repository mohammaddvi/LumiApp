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

    static func messageKind(forNotificationId id: String) -> ReminderMessageKind? {
        switch id {
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
final class LuneNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = LuneNotificationDelegate()

    @MainActor
    weak var environment: AppEnvironment?

    @MainActor
    func configure(environment: AppEnvironment) {
        self.environment = environment
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

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let id = notification.request.identifier
        await MainActor.run {
            environment?.handleReminderNotification(id: id, autoPresentMessage: true)
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
            environment?.handleReminderNotification(id: id, autoPresentMessage: forceMessage)
        }
    }
}

@MainActor
@Observable
final class NotificationService {
    private let center = UNUserNotificationCenter.current()

    /// Days before predicted period start when PMS window often begins.
    static let pmsLeadDays = 5

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

    func reschedule(preferences: UserPreferences, predictedDate: Date?) async {
        center.removePendingNotificationRequests(withIdentifiers: LuneNotificationID.reminderIDs)

        guard preferences.notificationsEnabled || preferences.iMessageRemindersEnabled else { return }

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        let wantsOnDevice = preferences.notificationsEnabled
        let wantsIMessage = preferences.iMessageRemindersEnabled && !preferences.iMessageContacts.filter(\.isValid).isEmpty

        if wantsOnDevice, preferences.periodReminderEnabled, let predictedDate {
            await schedule(
                id: LuneNotificationID.periodReminder,
                on: predictedDate.addingDays(-1),
                hour: preferences.reminderHour,
                minute: preferences.reminderMinute,
                title: "Period window approaching",
                body: wantsIMessage
                    ? "Lune will open Messages so you can notify your people."
                    : "Your next period is likely soon. No pressure — log when you’re ready.",
                category: wantsIMessage ? LuneNotificationID.autoMessageCategory : nil
            )
        }

        if wantsOnDevice, preferences.pmsReminderEnabled, preferences.experiencesPMS, let predictedDate {
            await schedule(
                id: LuneNotificationID.pmsReminder,
                on: predictedDate.addingDays(-Self.pmsLeadDays),
                hour: preferences.reminderHour,
                minute: preferences.reminderMinute,
                title: "PMS window may be near",
                body: wantsIMessage
                    ? "Lune will open Messages so you can notify your people."
                    : pmsBody(preferences: preferences),
                category: wantsIMessage ? LuneNotificationID.autoMessageCategory : nil
            )
        }

        // Dedicated auto-iMessage notifications even if on-device banners are off
        if wantsIMessage, let predictedDate {
            if preferences.periodReminderEnabled || !preferences.notificationsEnabled {
                await schedule(
                    id: LuneNotificationID.iMessagePeriod,
                    on: predictedDate.addingDays(-1),
                    hour: preferences.reminderHour,
                    minute: preferences.reminderMinute,
                    title: "Send period heads-up",
                    body: "Tap to open Messages with your saved numbers — ready to send.",
                    category: LuneNotificationID.autoMessageCategory
                )
            }
            if preferences.experiencesPMS, preferences.pmsReminderEnabled || !preferences.notificationsEnabled {
                await schedule(
                    id: LuneNotificationID.iMessagePMS,
                    on: predictedDate.addingDays(-Self.pmsLeadDays),
                    hour: preferences.reminderHour,
                    minute: preferences.reminderMinute,
                    title: "Send PMS heads-up",
                    body: "Tap to open Messages with your saved numbers — ready to send.",
                    category: LuneNotificationID.autoMessageCategory
                )
            }
        }

        if wantsOnDevice, preferences.symptomReminderEnabled, let predictedDate {
            let hasSymptoms = !preferences.typicalPeriodSymptoms.isEmpty || !preferences.typicalPMSSymptoms.isEmpty
            guard hasSymptoms else { return }
            await schedule(
                id: LuneNotificationID.symptomReminder,
                on: predictedDate.addingDays(-3),
                hour: preferences.reminderHour,
                minute: preferences.reminderMinute,
                title: "Symptoms you often notice",
                body: symptomBody(preferences: preferences),
                category: nil
            )
        }

        if wantsOnDevice, preferences.checkInReminderEnabled {
            var components = DateComponents()
            components.hour = preferences.reminderHour
            components.minute = preferences.reminderMinute

            let content = UNMutableNotificationContent()
            content.title = "Quick check-in"
            content.body = "A short check-in keeps your personal patterns clear."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: LuneNotificationID.checkInReminder,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    private func schedule(
        id: String,
        on date: Date,
        hour: Int,
        minute: Int,
        title: String,
        body: String,
        category: String?
    ) async {
        guard date.startOfDay >= Date().startOfDay.addingDays(-1) else { return }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let category {
            content.categoryIdentifier = category
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    private func pmsBody(preferences: UserPreferences) -> String {
        let names = preferences.typicalPMSSymptoms.prefix(3).map(\.displayName)
        if names.isEmpty {
            return "A gentle heads-up that your usual pre-period days may be coming up."
        }
        return "You often notice \(names.joined(separator: ", ")) around this time. Log anything that shows up — no pressure."
    }

    private func symptomBody(preferences: UserPreferences) -> String {
        let combined = Array(Set(preferences.typicalPMSSymptoms + preferences.typicalPeriodSymptoms)).prefix(4)
        let names = combined.map(\.displayName)
        if names.isEmpty {
            return "A quiet reminder to check in with how you feel."
        }
        return "Based on what you shared: \(names.joined(separator: ", ")). Only patterns — not a diagnosis."
    }
}
