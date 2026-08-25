import Foundation
import Testing
@testable import Cycle

@Suite("CycleCalculator")
struct CycleCalculatorTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test("Builds completed cycles from consecutive starts")
    func completedCycles() {
        let starts = [
            date(2026, 1, 1),
            date(2026, 1, 29),
            date(2026, 2, 26)
        ]
        let completed = CycleCalculator.completedCycles(fromStarts: starts, calendar: calendar)
        #expect(completed.count == 2)
        #expect(completed[0].lengthDays == 28)
        #expect(completed[1].lengthDays == 28)
    }

    @Test("Handles leap year February")
    func leapYear() {
        let starts = [date(2024, 1, 31), date(2024, 3, 1)]
        let completed = CycleCalculator.completedCycles(fromStarts: starts, calendar: calendar)
        #expect(completed.count == 1)
        #expect(completed[0].lengthDays == 30)
    }

    @Test("Current cycle day is 1-based")
    func cycleDay() {
        let start = date(2026, 8, 20)
        let day = CycleCalculator.currentCycleDay(latestStart: start, on: date(2026, 8, 25), calendar: calendar)
        #expect(day == 6)
    }

    @Test("Estimates ovulation 14 days before next period")
    func ovulationFromNextPeriod() {
        let ovulation = CycleCalculator.estimatedOvulationDate(
            beforeNextPeriod: date(2026, 3, 29),
            calendar: calendar
        )
        #expect(ovulation == date(2026, 3, 15))
    }

    @Test("Estimates ovulation from cycle start and length")
    func ovulationFromCycleLength() {
        let ovulation = CycleCalculator.estimatedOvulationDate(
            cycleStart: date(2026, 3, 1),
            cycleLengthDays: 28,
            calendar: calendar
        )
        #expect(ovulation == date(2026, 3, 15))
    }

    @Test("Skips ovulation estimate for very short cycles")
    func ovulationTooShort() {
        let ovulation = CycleCalculator.estimatedOvulationDate(
            cycleStart: date(2026, 3, 1),
            cycleLengthDays: 18,
            calendar: calendar
        )
        #expect(ovulation == nil)
    }

    @Test("Detects overlapping period ranges")
    func overlap() {
        let existing = [(start: date(2026, 8, 1), end: date(2026, 8, 5) as Date?)]
        let overlaps = CycleCalculator.overlapsExistingPeriod(
            proposedStart: date(2026, 8, 4),
            proposedEnd: date(2026, 8, 6),
            existing: existing,
            calendar: calendar
        )
        #expect(overlaps)
    }
}

@Suite("PredictionEngine")
struct PredictionEngineTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let engine = PredictionEngine()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func cycles(_ lengths: [Int], starting: Date) -> [CompletedCycle] {
        var cursor = starting
        return lengths.map { length in
            let cycle = CompletedCycle(startDate: cursor, lengthDays: length, periodLengthDays: 5)
            cursor = calendar.date(byAdding: .day, value: length, to: cursor)!
            return cycle
        }
    }

    @Test("Insufficient history shows insufficient confidence")
    func insufficient() {
        let result = engine.predict(
            completedCycles: cycles([28, 29], starting: date(2026, 1, 1)),
            currentCycleStart: date(2026, 3, 1),
            typicalCycleLength: 28,
            now: date(2026, 3, 10),
            calendar: calendar
        )
        #expect(result.confidence == .insufficient)
        #expect(result.predictedDate != nil)
    }

    @Test("Low variability yields high confidence and narrow range")
    func highConfidence() {
        let result = engine.predict(
            completedCycles: cycles([28, 28, 27, 28, 28], starting: date(2026, 1, 1)),
            currentCycleStart: date(2026, 5, 20),
            now: date(2026, 5, 25),
            calendar: calendar
        )
        #expect(result.confidence == .high)
        #expect(result.medianCycleLength == 28)
        #expect(result.predictedOvulationDate == date(2026, 6, 3))
        let span = result.upperBound!.daysSince(result.lowerBound!)
        #expect(span <= 4)
    }

    @Test("High variability yields low confidence")
    func lowConfidence() {
        let result = engine.predict(
            completedCycles: cycles([20, 28, 35, 42, 48], starting: date(2026, 1, 1)),
            currentCycleStart: date(2026, 8, 1),
            now: date(2026, 8, 10),
            calendar: calendar
        )
        #expect(result.confidence == .low)
    }

    @Test("Median prefers central tendency over outliers")
    func medianRobustness() {
        #expect(PredictionEngine.median([28, 28, 28, 45, 27]) == 28)
    }
}

@Suite("InsightEngine")
struct InsightEngineTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let engine = InsightEngine()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test("Suppresses insights before evidence threshold")
    func suppressEarly() {
        let insights = engine.generate(
            completedCycles: [
                CompletedCycle(startDate: date(2026, 1, 1), lengthDays: 28, periodLengthDays: 5)
            ],
            checkIns: [],
            cycleStarts: [date(2026, 1, 1)],
            now: date(2026, 1, 20),
            calendar: calendar
        )
        #expect(insights.isEmpty)
    }

    @Test("Detects cycle length change with enough history")
    func cycleChange() {
        let completed = [
            CompletedCycle(startDate: date(2025, 10, 1), lengthDays: 28, periodLengthDays: 5),
            CompletedCycle(startDate: date(2025, 10, 29), lengthDays: 27, periodLengthDays: 5),
            CompletedCycle(startDate: date(2025, 11, 25), lengthDays: 28, periodLengthDays: 5),
            CompletedCycle(startDate: date(2025, 12, 23), lengthDays: 32, periodLengthDays: 5),
            CompletedCycle(startDate: date(2026, 1, 24), lengthDays: 33, periodLengthDays: 5),
            CompletedCycle(startDate: date(2026, 2, 26), lengthDays: 31, periodLengthDays: 5)
        ]
        let insights = engine.generate(
            completedCycles: completed,
            checkIns: [],
            cycleStarts: completed.map(\.startDate) + [date(2026, 3, 29)],
            now: date(2026, 4, 5),
            calendar: calendar
        )
        #expect(insights.contains { $0.kind == .cycleChange })
    }
}

@Suite("LunePhaseEngine")
struct LunePhaseEngineTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test("Period days map to Reset")
    func resetPhase() {
        let phase = LunePhaseEngine.resolvePhase(
            cycleDay: 3,
            periodLength: 5,
            predictedOvulation: date(2026, 8, 15),
            on: date(2026, 8, 7),
            calendar: calendar
        )
        #expect(phase == .reset)
    }

    @Test("Soft days headline appears before predicted reset")
    func softDays() {
        let snapshot = LunePhaseEngine.snapshot(
            cycleDay: 24,
            periodLengthDays: 5,
            predictedNextReset: date(2026, 8, 28),
            predictedOvulation: date(2026, 8, 14),
            todayCheckIn: nil,
            on: date(2026, 8, 25),
            calendar: calendar
        )
        #expect(snapshot?.isSoftDays == true)
        #expect(snapshot?.headline.contains("soft era") == true)
        #expect(snapshot?.moodLine.contains("soft") == true)
    }

    @Test("Check-in overrides default mood line")
    func checkInMood() {
        let checkIn = DailyCheckInRecord(
            id: UUID(),
            date: date(2026, 8, 25),
            mood: .great,
            energy: .high,
            sleepQuality: nil,
            symptoms: [],
            note: nil
        )
        let snapshot = LunePhaseEngine.snapshot(
            cycleDay: 12,
            periodLengthDays: 5,
            predictedNextReset: date(2026, 9, 10),
            predictedOvulation: date(2026, 8, 25),
            todayCheckIn: checkIn,
            on: date(2026, 8, 25),
            calendar: calendar
        )
        #expect(snapshot?.moodLine.contains("glowing") == true)
        #expect(snapshot?.energyLine.contains("up") == true)
    }
}
