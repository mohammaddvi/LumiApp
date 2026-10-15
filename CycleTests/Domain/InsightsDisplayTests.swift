import Foundation
import Testing
@testable import Cycle

@Suite("Insights display")
struct InsightsDisplayTests {
    private let day = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func insight(_ kind: InsightKind, _ symptom: SymptomType? = nil, hits: Int? = nil, outOf: Int? = nil,
                         daysBefore: ClosedRange<Int>? = nil, delta: Int? = nil) -> InsightResult {
        InsightResult(id: UUID(), kind: kind, generatedAt: day, title: "", body: "", evidence: "", copyVersion: "",
                      symptom: symptom, hits: hits, outOf: outOf, daysBefore: daysBefore, deltaDays: delta)
    }

    @Test("One line per symptom, timing wins, cycle change first")
    func foldsInsights() {
        let notices = InsightsDisplay.notices(from: [
            insight(.frequency, .cramps, hits: 6, outOf: 6),
            insight(.symptomTiming, .cramps, hits: 5, outOf: 6, daysBefore: 2...4),
            insight(.frequency, .fatigue, hits: 5, outOf: 6),
            insight(.symptomIntensityChange, .headache),
            insight(.cycleChange, delta: -3),
        ])
        #expect(notices.map(\.id) == ["cycle", "cramps", "headache", "fatigue"])
        #expect(notices[0].detail == "about 3 days shorter lately")
        #expect(notices[1].detail == "usually 2–4 days before your period")
        #expect(notices[1].hits == 5 && notices[1].outOf == 6)
        #expect(notices[2].detail == "stronger this cycle" && notices[2].hits == nil)
        #expect(notices[3].detail == "shows up most cycles")
    }

    @Test("Vibe words follow how much cycles vary")
    func vibe() {
        func stats(count: Int, shortest: Int, longest: Int) -> CycleStats {
            CycleStats(cycleCount: count, typicalCycleLength: 28, shortestCycle: shortest, longestCycle: longest, typicalPeriodLength: 5)
        }
        #expect(InsightsDisplay.vibe(for: stats(count: 2, shortest: 28, longest: 28)) == "Getting to know you 🔮")
        #expect(InsightsDisplay.vibe(for: stats(count: 6, shortest: 27, longest: 29)) == "Steady ✨")
        #expect(InsightsDisplay.vibe(for: stats(count: 6, shortest: 23, longest: 28)) == "A little wavy 🌊")
        #expect(InsightsDisplay.vibe(for: stats(count: 6, shortest: 22, longest: 35)) == "Free-spirited 🦋")
    }

    @Test("Cycle bar dates: period end, cycle end, current cycle and next period")
    func cycleDates() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = { (y: Int, m: Int, d: Int) in calendar.date(from: DateComponents(year: y, month: m, day: d))! }
        let today = date(2026, 10, 15)

        let past = CycleSummary(id: UUID(), startDate: date(2026, 9, 17), cycleLength: 23, periodLength: 5, checkInCount: 3, isComplete: true)
        #expect(InsightsDisplay.dates(for: past, today: today, calendar: calendar)
            == CycleDates(period: "Sep 17 – Sep 21 · 5 days", cycle: "Sep 17 – Oct 9 · 23 days", nextPeriod: nil))

        let current = CycleSummary(id: UUID(), startDate: date(2026, 10, 10), cycleLength: nil, periodLength: 1, checkInCount: 1, isComplete: false)
        #expect(InsightsDisplay.dates(for: current, today: today, nextPeriod: date(2026, 11, 7), calendar: calendar)
            == CycleDates(period: "Oct 10 · 1 day", cycle: "Oct 10 – today · day 6", nextPeriod: "around Nov 7"))

        let lastYear = CycleSummary(id: UUID(), startDate: date(2025, 12, 20), cycleLength: 28, periodLength: nil, checkInCount: 0, isComplete: true)
        let dates = InsightsDisplay.dates(for: lastYear, today: today, calendar: calendar)
        #expect(dates.period == nil)
        #expect(dates.cycle == "Dec 20, 2025 – Jan 16 · 28 days")
    }
}
