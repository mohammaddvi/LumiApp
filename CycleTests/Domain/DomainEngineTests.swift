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

    @Test("Ignores impossible cycle lengths, such as a period logged twice a few days apart")
    func ignoresImplausibleCycles() {
        // Reproduces a real store: starts Aug 14, Aug 21, Aug 26, Oct 7 → lengths 7, 5, 42.
        let result = engine.predict(
            completedCycles: [
                CompletedCycle(startDate: date(2026, 8, 14), lengthDays: 7, periodLengthDays: 5),
                CompletedCycle(startDate: date(2026, 8, 21), lengthDays: 5, periodLengthDays: 5),
                CompletedCycle(startDate: date(2026, 8, 26), lengthDays: 42, periodLengthDays: 1),
            ],
            currentCycleStart: date(2026, 10, 7),
            typicalCycleLength: 29,
            now: date(2026, 10, 13),
            calendar: calendar
        )
        #expect(result.predictedDate == date(2026, 11, 5))
        #expect(result.confidence == .insufficient)
    }

    @Test("Short and very long gaps don't count as cycles")
    func plausibleFilter() {
        let filtered = CycleCalculator.plausible(cycles([5, 14, 15, 28, 60, 61], starting: date(2026, 1, 1)))
        #expect(filtered.map(\.lengthDays) == [15, 28, 60])
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
        #expect((insights.first { $0.kind == .cycleChange }?.deltaDays ?? 0) > 0)
    }

    @Test("Symptom timing carries counts and days for the screen")
    func symptomTimingDetails() {
        let starts = (0..<6).map { date(2026, 1, 1).addingDays($0 * 28) }
        let checkIns = starts.dropFirst().flatMap { start in
            (2...3).map { before in
                DailyCheckInRecord(
                    id: UUID(),
                    date: start.addingDays(-before),
                    symptoms: [SymptomOccurrence(symptomType: .cramps, intensity: .moderate)]
                )
            }
        }
        let insights = engine.generate(
            completedCycles: [],
            checkIns: checkIns,
            cycleStarts: starts,
            now: starts.last!.addingDays(5),
            calendar: calendar
        )
        let timing = try? #require(insights.first { $0.kind == .symptomTiming && $0.symptom == .cramps })
        #expect(timing?.hits == 5)
        #expect(timing?.outOf == 6)
        #expect(timing?.daysBefore != nil)
        #expect(timing?.body == "You often log cramps shortly before your period.")
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

@Suite("Feeling")
struct FeelingTests {
    private let day = Date(timeIntervalSince1970: 1_735_689_600)

    @Test("Applying a feeling keeps symptoms, sleep and note")
    func applyKeepsDetails() {
        let checkIn = DailyCheckInRecord(
            id: UUID(),
            date: day,
            mood: .great,
            energy: .high,
            sleepQuality: nil,
            symptoms: [SymptomOccurrence(symptomType: .cramps, intensity: .mild)],
            note: "note"
        )
        let updated = checkIn.applying(.sad)
        #expect(updated.feeling == .sad)
        #expect(updated.mood == .low)
        #expect(updated.energy == .high)
        #expect(updated.symptoms == checkIn.symptoms)
        #expect(updated.note == "note")
        #expect(updated.id == checkIn.id)
    }

    @Test("Tired also logs drained energy")
    func tiredSetsEnergy() {
        let checkIn = DailyCheckInRecord(id: UUID(), date: day, mood: nil, energy: .high, sleepQuality: nil, symptoms: [], note: nil)
        #expect(checkIn.applying(.tired).energy == .drained)
    }

    @Test("Every feeling maps to a mood level")
    func moodMapping() {
        #expect(Feeling.happy.moodLevel == .great)
        #expect(Feeling.calm.moodLevel == .good)
        #expect(Feeling.tired.moodLevel == .okay)
        for feeling in [Feeling.anxious, .irritable, .sad] {
            #expect(feeling.moodLevel == .low)
        }
    }
}

@Suite("FeelingForecastEngine")
struct FeelingForecastEngineTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func checkIn(_ day: Date, _ feeling: Feeling?) -> DailyCheckInRecord {
        DailyCheckInRecord(id: UUID(), date: day, mood: nil, energy: nil, sleepQuality: nil, symptoms: [], note: nil, feeling: feeling)
    }

    /// Cycles starting Jan 1, Jan 29, Feb 26 (current).
    private var starts: [Date] { [date(2026, 1, 1), date(2026, 1, 29), date(2026, 2, 26)] }

    @Test("Uses the feeling logged most around this cycle day in past cycles")
    func usesHistory() {
        // Today is cycle day 10 of the current cycle.
        let history = [
            checkIn(date(2026, 1, 10), .anxious), // day 10
            checkIn(date(2026, 2, 7), .anxious),  // day 10
            checkIn(date(2026, 2, 8), .calm),     // day 11
            checkIn(date(2026, 1, 20), .happy),   // day 20, outside the window
        ]
        let forecast = FeelingForecastEngine.forecast(phase: .bloom, cycleDay: 10, cycleStarts: starts, checkIns: history, calendar: calendar)
        #expect(forecast == FeelingForecast(feeling: .anxious, basis: .history(sampleCount: 2)))
    }

    @Test("Ties go to the most recent feeling")
    func tieBreaksByRecency() {
        let history = [
            checkIn(date(2026, 1, 10), .sad),
            checkIn(date(2026, 2, 7), .calm),
        ]
        let forecast = FeelingForecastEngine.forecast(phase: .bloom, cycleDay: 10, cycleStarts: starts, checkIns: history, calendar: calendar)
        #expect(forecast.feeling == .calm)
    }

    @Test("Ignores the current cycle and check-ins without a feeling")
    func ignoresCurrentCycle() {
        let history = [
            checkIn(date(2026, 3, 5), .irritable), // current cycle, day 8
            checkIn(date(2026, 3, 6), .irritable), // current cycle, day 9
            checkIn(date(2026, 2, 7), nil),
        ]
        let forecast = FeelingForecastEngine.forecast(phase: .bloom, cycleDay: 10, cycleStarts: starts, checkIns: history, calendar: calendar)
        #expect(forecast == FeelingForecast(feeling: .happy, basis: .phase))
    }

    @Test("Phase defaults never guess a hard feeling")
    func gentleDefaults() {
        for phase in LunePhase.allCases {
            let feeling = FeelingForecastEngine.phaseDefault(for: phase)
            #expect([Feeling.happy, .calm, .tired].contains(feeling))
        }
    }
}

@Suite("CycleStats")
struct CycleStatsTests {
    private let start = Date(timeIntervalSince1970: 1_735_689_600)

    @Test("Summarizes cycle length, difference and period length")
    func summarizes() throws {
        let cycles = [
            CompletedCycle(startDate: start, lengthDays: 26, periodLengthDays: 5),
            CompletedCycle(startDate: start, lengthDays: 30, periodLengthDays: 4),
            CompletedCycle(startDate: start, lengthDays: 28, periodLengthDays: 0),
        ]
        let stats = try #require(CycleStats.from(cycles))
        #expect(stats.cycleCount == 3)
        #expect(stats.typicalCycleLength == 28)
        #expect(stats.cycleDifference == 4)
        #expect(stats.shortestCycle == 26)
        #expect(stats.longestCycle == 30)
        #expect(stats.typicalPeriodLength != nil)
    }

    @Test("No completed cycles, no stats")
    func empty() {
        #expect(CycleStats.from([]) == nil)
    }
}

@Suite("CycleTips")
struct CycleTipsTests {
    private func snapshot(_ phase: LunePhase, softDays: Bool = false) -> TodaysLuneSnapshot {
        TodaysLuneSnapshot(phase: phase, cycleDay: 10, isSoftDays: softDays, moonIllumination: 0.5, headline: "", energyLine: "", moodLine: "", bodyLine: "")
    }

    @Test("Maps phases to cycle moments, soft days become pre-period")
    func moments() {
        #expect(CycleMoment(snapshot: snapshot(.reset)) == .period)
        #expect(CycleMoment(snapshot: snapshot(.reset, softDays: true)) == .period)
        #expect(CycleMoment(snapshot: snapshot(.bloom)) == .follicular)
        #expect(CycleMoment(snapshot: snapshot(.glow)) == .ovulation)
        #expect(CycleMoment(snapshot: snapshot(.slow)) == .luteal)
        #expect(CycleMoment(snapshot: snapshot(.slow, softDays: true)) == .prePeriod)
    }

    @Test("Every moment has one tip per topic, each asking the AI about that moment")
    func tipsCoverTopics() {
        for moment in CycleMoment.allCases {
            let tips = CycleTipsEngine.tips(for: moment, experiencesPMS: true)
            #expect(tips.map(\.topic) == WellnessTopic.allCases)
            for tip in tips {
                #expect(!tip.text.isEmpty)
                #expect(tip.prompt.contains(moment.displayName(experiencesPMS: true)))
            }
        }
    }
}

@Suite("CycleOutlookEngine")
struct CycleOutlookEngineTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private var outlook: CycleOutlook {
        CycleOutlookEngine.outlook(
            nextPeriodStart: date(2026, 11, 5),
            cycleLength: 28,
            periodLength: 5,
            baseUncertainty: 2,
            count: 3,
            calendar: calendar
        )
    }

    @Test("Projects cycles forward by the cycle length")
    func projects() {
        let starts = outlook.cycles.map(\.periodStart)
        #expect(starts == [date(2026, 11, 5), date(2026, 12, 3), date(2026, 12, 31)])
        #expect(outlook.cycles[0].periodEnd == date(2026, 11, 9))
        #expect(outlook.cycles[0].ovulation == date(2026, 10, 22))
        #expect(outlook.cycles[0].prePeriodStart == date(2026, 10, 31))
    }

    @Test("Further cycles are less certain")
    func uncertaintyGrows() {
        #expect(outlook.cycles.map(\.uncertaintyDays) == [2, 2, 3])
    }

    @Test("Classifies days, period first")
    func kinds() {
        #expect(outlook.kind(on: date(2026, 11, 5)) == .period)
        #expect(outlook.kind(on: date(2026, 11, 9)) == .period)
        #expect(outlook.kind(on: date(2026, 11, 10)) == nil)
        #expect(outlook.kind(on: date(2026, 11, 4)) == .prePeriod)
        #expect(outlook.kind(on: date(2026, 11, 19)) == .ovulation)
    }

    @Test("The 5 days before ovulation are fertile days")
    func fertileDays() {
        // Ovulation Oct 22 → fertile Oct 17–21.
        #expect(outlook.cycles[0].fertileStart == date(2026, 10, 17))
        #expect(outlook.kind(on: date(2026, 10, 16)) == nil)
        #expect(outlook.kind(on: date(2026, 10, 17)) == .fertile)
        #expect(outlook.kind(on: date(2026, 10, 21)) == .fertile)
        #expect(outlook.kind(on: date(2026, 10, 22)) == .ovulation)
        #expect(outlook.kind(on: date(2026, 10, 23)) == nil)
        #expect(outlook.overlaps(tripStart: date(2026, 10, 15), tripEnd: date(2026, 10, 23)) == [
            PlanOverlap(kind: .fertile, start: date(2026, 10, 17), end: date(2026, 10, 21)),
            PlanOverlap(kind: .ovulation, start: date(2026, 10, 22), end: date(2026, 10, 22)),
        ])
    }

    @Test("Trip overlaps merge into runs")
    func tripOverlaps() {
        let overlaps = outlook.overlaps(tripStart: date(2026, 11, 2), tripEnd: date(2026, 11, 7))
        #expect(overlaps == [
            PlanOverlap(kind: .prePeriod, start: date(2026, 11, 2), end: date(2026, 11, 4)),
            PlanOverlap(kind: .period, start: date(2026, 11, 5), end: date(2026, 11, 7)),
        ])
        #expect(outlook.overlaps(tripStart: date(2026, 11, 10), tripEnd: date(2026, 11, 13)).isEmpty)
    }
}

@Suite("CycleDayEngine")
struct CycleDayEngineTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private var starts: [Date] { [date(2026, 9, 1), date(2026, 9, 29)] }

    @Test("Past day uses its own cycle and the next logged start")
    func pastDay() throws {
        // Sep 1 → Sep 29 is a 28-day cycle; ovulation estimated Sep 15.
        let period = try #require(CycleDayEngine.state(on: date(2026, 9, 3), cycleStarts: starts, periodLength: 5, predictedNextStart: nil, calendar: calendar))
        #expect(period == CycleDayState(cycleDay: 3, phase: .reset, isPrePeriod: false))

        let ovulation = try #require(CycleDayEngine.state(on: date(2026, 9, 15), cycleStarts: starts, periodLength: 5, predictedNextStart: nil, calendar: calendar))
        #expect(ovulation.phase == .glow)

        let prePeriod = try #require(CycleDayEngine.state(on: date(2026, 9, 26), cycleStarts: starts, periodLength: 5, predictedNextStart: nil, calendar: calendar))
        #expect(prePeriod.isPrePeriod)
        #expect(prePeriod.cycleDay == 26)
    }

    @Test("Fertile window covers the 5 days before ovulation and ovulation day")
    func fertileWindow() throws {
        // Ovulation Sep 15 → fertile Sep 10–15.
        func state(_ day: Int) throws -> CycleDayState {
            try #require(CycleDayEngine.state(on: date(2026, 9, day), cycleStarts: starts, periodLength: 5, predictedNextStart: nil, calendar: calendar))
        }
        #expect(try !state(9).isFertile)
        #expect(try state(10).isFertile)
        #expect(try !state(14).isOvulationDay)
        #expect(try state(15).isFertile && state(15).isOvulationDay)
        #expect(try !state(16).isFertile)
    }

    @Test("Current cycle falls back to the predicted next start")
    func currentCycle() throws {
        let state = try #require(CycleDayEngine.state(on: date(2026, 10, 24), cycleStarts: starts, periodLength: 5, predictedNextStart: date(2026, 10, 27), calendar: calendar))
        #expect(state.cycleDay == 26)
        #expect(state.isPrePeriod)
    }

    @Test("Days before the first logged period have no state")
    func beforeHistory() {
        #expect(CycleDayEngine.state(on: date(2026, 8, 20), cycleStarts: starts, periodLength: 5, predictedNextStart: nil, calendar: calendar) == nil)
    }

    @Test("A period day joins a period within two days, otherwise starts a new one")
    func periodToExtend() {
        let id = UUID()
        let periods = [(id: id, days: [date(2026, 10, 7), date(2026, 10, 8), date(2026, 10, 9)])]
        #expect(CycleCalculator.periodToExtend(day: date(2026, 10, 11), periods: periods, calendar: calendar) == id)
        #expect(CycleCalculator.periodToExtend(day: date(2026, 10, 5), periods: periods, calendar: calendar) == id)
        #expect(CycleCalculator.periodToExtend(day: date(2026, 10, 12), periods: periods, calendar: calendar) == nil)
        #expect(CycleCalculator.periodToExtend(day: date(2026, 10, 4), periods: periods, calendar: calendar) == nil)
    }
}

@Suite("LumiTone")
struct LumiToneTests {
    @Test("Reply tone picks Lumi's sticker face")
    func tones() {
        #expect(LumiTone.feeling(for: "Try an earlier bedtime and a little rest 🌙") == .tired)
        #expect(LumiTone.feeling(for: "A warm chamomile tea can feel calming 🍵") == .calm)
        #expect(LumiTone.feeling(for: "I'm sorry today feels hard. If it keeps worrying you, talk to a clinician.") == .sad)
        #expect(LumiTone.feeling(for: "Colorful smoothies and a dance class! ✨") == .happy)
        // Whole words only: "steadier" must not count as "tea", "interest" not as "rest".
        #expect(LumiTone.feeling(for: "Your logs show steadier energy and more interest in plans ✨") == .happy)
    }
}
