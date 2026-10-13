import Foundation
import Testing
@testable import Cycle

@Suite("ReminderPlanner")
struct ReminderPlannerTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private var allOn: UserPreferences {
        var prefs = UserPreferences.default
        prefs.notificationsEnabled = true
        prefs.periodReminderEnabled = true
        prefs.pmsReminderEnabled = true
        prefs.experiencesPMS = true
        prefs.symptomReminderEnabled = true
        prefs.checkInReminderEnabled = true
        prefs.reminderHour = 9
        prefs.reminderMinute = 30
        return prefs
    }

    @Test("Daily check-in is scheduled even when symptom reminders have no symptoms (regression)")
    func checkInSurvivesEmptySymptoms() {
        var prefs = allOn
        prefs.typicalPeriodSymptoms = []
        prefs.typicalPMSSymptoms = []
        let plan = ReminderPlanner.plan(preferences: prefs, periodStarts: [date(2026, 11, 5)], now: date(2026, 10, 13), calendar: calendar)
        let checkIn = plan.first { $0.id == LuneNotificationID.checkInReminder }
        #expect(checkIn?.repeats == true)
        #expect(checkIn?.fireDate.hour == 9 && checkIn?.fireDate.minute == 30)
        #expect(!plan.contains { $0.id.hasPrefix(LuneNotificationID.symptomReminder) })
    }

    @Test("Period, PMS and symptom reminders land on the right days for each upcoming cycle")
    func cycleReminders() {
        var prefs = allOn
        prefs.typicalPMSSymptoms = [.cramps]
        let plan = ReminderPlanner.plan(
            preferences: prefs,
            periodStarts: [date(2026, 11, 5), date(2026, 12, 3), date(2026, 12, 31), date(2027, 1, 28)],
            now: date(2026, 10, 13),
            calendar: calendar
        )
        func day(_ id: String) -> DateComponents? { plan.first { $0.id == id }?.fireDate }
        #expect(day("lune.period.reminder.0")?.day == 4)
        #expect(day("lune.pms.reminder.0")?.day == 31)
        #expect(day("lune.symptom.reminder.0")?.day == 2)
        #expect(day("lune.period.reminder.2")?.month == 12 && day("lune.period.reminder.2")?.day == 30)
        // Only the next three cycles.
        #expect(day("lune.period.reminder.3") == nil)
    }

    @Test("Reminders whose moment has passed are skipped")
    func skipsPast() {
        let plan = ReminderPlanner.plan(preferences: allOn, periodStarts: [date(2026, 10, 14)], now: date(2026, 10, 13, 12), calendar: calendar)
        // Period reminder would be Oct 13 9:30, already past at noon; PMS would be Oct 9.
        #expect(!plan.contains { $0.id.hasPrefix(LuneNotificationID.periodReminder) })
        #expect(!plan.contains { $0.id.hasPrefix(LuneNotificationID.pmsReminder) })
    }

    @Test("Nothing is planned when reminders and iMessage are off")
    func allOff() {
        #expect(ReminderPlanner.plan(preferences: .default, periodStarts: [date(2026, 11, 5)], now: date(2026, 10, 13), calendar: calendar).isEmpty)
    }

    @Test("iMessage heads-ups are planned with the Messages action")
    func iMessage() {
        var prefs = allOn
        prefs.iMessageRemindersEnabled = true
        prefs.iMessageContacts = [MessageContact(label: "Sam", phoneNumber: "+31612345678")]
        let plan = ReminderPlanner.plan(preferences: prefs, periodStarts: [date(2026, 11, 5)], now: date(2026, 10, 13), calendar: calendar)
        let heads = plan.first { $0.id == "lune.imessage.period.0" }
        #expect(heads?.category == LuneNotificationID.autoMessageCategory)
        #expect(LuneNotificationID.messageKind(forNotificationId: "lune.imessage.period.0") == .periodClose)
        #expect(LuneNotificationID.messageKind(forNotificationId: "lune.pms.reminder.2") == .pmsClose)
        #expect(LuneNotificationID.messageKind(forNotificationId: LuneNotificationID.checkInReminder) == nil)
    }
}
