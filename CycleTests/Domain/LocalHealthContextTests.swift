import Testing
import Foundation
@testable import Cycle

struct LocalHealthContextTests {
    @Test func buildsPromptWithoutContactData() {
        var prefs = UserPreferences.default
        prefs.experiencesPMS = true
        prefs.typicalCycleLength = 28
        prefs.typicalPeriodSymptoms = [.cramps]
        prefs.iMessageContacts = [
            MessageContact(id: UUID(), label: "Friend", phoneNumber: "+15551234567")
        ]

        let cycles = [
            CycleRecord(
                id: UUID(),
                startDate: Date().addingDays(-60),
                endDate: Date().addingDays(-55),
                source: .user,
                createdAt: .now,
                updatedAt: .now
            )
        ]
        let completed = [
            CompletedCycle(
                startDate: Date().addingDays(-60),
                lengthDays: 28,
                periodLengthDays: 5
            )
        ]

        let context = LocalHealthContextBuilder.build(
            preferences: prefs,
            cycles: cycles,
            completedCycles: completed,
            checkIns: [],
            flows: [],
            prediction: nil,
            insights: [],
            currentCycleDay: 12
        )

        #expect(context.promptBlock.contains("Current cycle day: 12"))
        #expect(context.promptBlock.contains("28"))
        #expect(!context.promptBlock.contains("555"))
        #expect(!context.promptBlock.contains("Friend"))
        #expect(context.cycleCount == 1)
    }
}

@Suite("AI key dates")
struct LocalHealthContextKeyDatesTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func day(_ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day))!
    }

    private func outlook(nextPeriod: Date) -> CycleOutlook {
        CycleOutlookEngine.outlook(
            nextPeriodStart: nextPeriod,
            cycleLength: 28,
            periodLength: 5,
            baseUncertainty: 3,
            calendar: calendar
        )
    }

    @Test("Next ovulation is the first one still ahead, with days to go")
    func nextOvulationAhead() {
        // Period started Oct 7 → next period Nov 4, ovulation Oct 21.
        let lines = LocalHealthContextBuilder.keyDateLines(
            prediction: nil,
            outlook: outlook(nextPeriod: day(11, 4)),
            now: day(10, 14),
            calendar: calendar
        ).joined(separator: "\n")

        #expect(lines.contains("Next period: around Nov 4, 2026 (in 21 days)"))
        #expect(lines.contains("Next ovulation (estimate): around Oct 21, 2026 (in 7 days)"))
        #expect(lines.contains("PMS / pre-period days start: around Oct 30, 2026 (in 16 days)"))
        #expect(lines.contains("Fertile window (estimate, not birth control): Oct 16, 2026 to Oct 21, 2026, starts Oct 16, 2026 (in 2 days)"))
    }

    @Test("Inside the fertile window it says now")
    func fertileNow() {
        let lines = LocalHealthContextBuilder.keyDateLines(
            prediction: nil,
            outlook: outlook(nextPeriod: day(11, 4)),
            now: day(10, 18),
            calendar: calendar
        ).joined(separator: "\n")

        #expect(lines.contains("Fertile window (estimate, not birth control): now, Oct 16, 2026 to Oct 21, 2026"))
    }

    @Test("After this cycle's ovulation, the next cycle's is used")
    func ovulationAlreadyPassed() {
        let lines = LocalHealthContextBuilder.keyDateLines(
            prediction: nil,
            outlook: outlook(nextPeriod: day(11, 4)),
            now: day(10, 25),
            calendar: calendar
        ).joined(separator: "\n")

        #expect(lines.contains("Next ovulation (estimate): around Nov 18, 2026 (in 24 days)"))
    }

    @Test("No prediction, no key dates")
    func noPrediction() {
        #expect(LocalHealthContextBuilder.keyDateLines(prediction: nil, outlook: nil, now: day(10, 14), calendar: calendar).isEmpty)
    }
}
