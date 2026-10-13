import Foundation

/// One local notification to schedule. Plain data so the plan can be tested without UserNotifications.
struct PlannedReminder: Equatable, Sendable {
    let id: String
    /// Full date + time for one-off reminders; hour + minute only when `repeats`.
    let fireDate: DateComponents
    let repeats: Bool
    let title: String
    let body: String
    let category: String?
}

/// Decides which reminders to schedule. Covers the next few predicted periods, so reminders keep
/// arriving even if the app isn't opened for a while (each launch replans).
enum ReminderPlanner {
    /// Predicted periods to schedule ahead (iOS allows 64 pending notifications; this stays far below).
    static let cyclesAhead = 3
    /// Days before the predicted period start.
    static let periodLeadDays = 1
    static let pmsLeadDays = 5
    static let symptomLeadDays = 3

    static func plan(
        preferences: UserPreferences,
        periodStarts: [Date],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [PlannedReminder] {
        let wantsOnDevice = preferences.notificationsEnabled
        let wantsIMessage = preferences.iMessageRemindersEnabled
            && !preferences.iMessageContacts.filter(\.isValid).isEmpty
        guard wantsOnDevice || wantsIMessage else { return [] }

        var reminders: [PlannedReminder] = []

        func add(_ id: String, index: Int, daysBefore: Int, start: Date, title: String, body: String, category: String?) {
            guard let day = calendar.date(byAdding: .day, value: -daysBefore, to: calendar.startOfDay(for: start)) else { return }
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = preferences.reminderHour
            components.minute = preferences.reminderMinute
            // Skip reminders whose moment has already passed: iOS would never deliver them.
            guard let fire = calendar.date(from: components), fire > now else { return }
            reminders.append(PlannedReminder(
                id: "\(id).\(index)",
                fireDate: components,
                repeats: false,
                title: title,
                body: body,
                category: category
            ))
        }

        let hasSymptoms = !preferences.typicalPeriodSymptoms.isEmpty || !preferences.typicalPMSSymptoms.isEmpty
        let messageCategory = wantsIMessage ? LuneNotificationID.autoMessageCategory : nil
        let messageBody = "Lumi will open Messages so you can notify your people."

        for (index, start) in periodStarts.prefix(cyclesAhead).enumerated() {
            if wantsOnDevice, preferences.periodReminderEnabled {
                add(LuneNotificationID.periodReminder, index: index, daysBefore: periodLeadDays, start: start,
                    title: "Period window approaching",
                    body: wantsIMessage ? messageBody : "Your next period is likely soon. No pressure — log when you’re ready.",
                    category: messageCategory)
            }
            if wantsOnDevice, preferences.pmsReminderEnabled, preferences.experiencesPMS {
                add(LuneNotificationID.pmsReminder, index: index, daysBefore: pmsLeadDays, start: start,
                    title: "PMS window may be near",
                    body: wantsIMessage ? messageBody : pmsBody(preferences),
                    category: messageCategory)
            }
            if wantsIMessage {
                if preferences.periodReminderEnabled || !preferences.notificationsEnabled {
                    add(LuneNotificationID.iMessagePeriod, index: index, daysBefore: periodLeadDays, start: start,
                        title: "Send period heads-up",
                        body: "Tap to open Messages with your saved numbers — ready to send.",
                        category: LuneNotificationID.autoMessageCategory)
                }
                if preferences.experiencesPMS, preferences.pmsReminderEnabled || !preferences.notificationsEnabled {
                    add(LuneNotificationID.iMessagePMS, index: index, daysBefore: pmsLeadDays, start: start,
                        title: "Send PMS heads-up",
                        body: "Tap to open Messages with your saved numbers — ready to send.",
                        category: LuneNotificationID.autoMessageCategory)
                }
            }
            if wantsOnDevice, preferences.symptomReminderEnabled, hasSymptoms {
                add(LuneNotificationID.symptomReminder, index: index, daysBefore: symptomLeadDays, start: start,
                    title: "Symptoms you often notice",
                    body: symptomBody(preferences),
                    category: nil)
            }
        }

        if wantsOnDevice, preferences.checkInReminderEnabled {
            var components = DateComponents()
            components.hour = preferences.reminderHour
            components.minute = preferences.reminderMinute
            reminders.append(PlannedReminder(
                id: LuneNotificationID.checkInReminder,
                fireDate: components,
                repeats: true,
                title: "How are you today?",
                body: "Tap to tell Lumi how you feel 🌙",
                category: nil
            ))
        }

        return reminders
    }

    private static func pmsBody(_ preferences: UserPreferences) -> String {
        let names = preferences.typicalPMSSymptoms.prefix(3).map(\.displayName)
        if names.isEmpty {
            return "A gentle heads-up that your usual pre-period days may be coming up."
        }
        return "You often notice \(names.joined(separator: ", ")) around this time. Log anything that shows up — no pressure."
    }

    private static func symptomBody(_ preferences: UserPreferences) -> String {
        let names = Array(Set(preferences.typicalPMSSymptoms + preferences.typicalPeriodSymptoms))
            .sorted { $0.rawValue < $1.rawValue }
            .prefix(4)
            .map(\.displayName)
        return "Based on what you shared: \(names.joined(separator: ", ")). Only patterns — not a diagnosis."
    }
}
