import Foundation

/// Where any past or present day sat in its cycle.
struct CycleDayState: Equatable, Sendable {
    let cycleDay: Int
    let phase: LunePhase
    /// One of the few days right before the next period (PMS days).
    let isPrePeriod: Bool
}

enum CycleDayEngine {
    /// - Parameters:
    ///   - cycleStarts: every logged period start.
    ///   - periodLength: bleeding days of the cycle containing `date`.
    ///   - predictedNextStart: used when `date` is in the current cycle (no later start logged yet).
    static func state(
        on date: Date,
        cycleStarts: [Date],
        periodLength: Int,
        predictedNextStart: Date?,
        calendar: Calendar = .current
    ) -> CycleDayState? {
        let day = calendar.startOfDay(for: date)
        let starts = cycleStarts.map { calendar.startOfDay(for: $0) }.sorted()
        guard let start = starts.last(where: { $0 <= day }) else { return nil }

        let cycleDay = (calendar.dateComponents([.day], from: start, to: day).day ?? 0) + 1
        let nextStart = starts.first(where: { $0 > day }) ?? predictedNextStart.map { calendar.startOfDay(for: $0) }
        let ovulation = nextStart.flatMap { CycleCalculator.estimatedOvulationDate(beforeNextPeriod: $0, calendar: calendar) }
        let phase = LunePhaseEngine.resolvePhase(
            cycleDay: cycleDay,
            periodLength: max(1, periodLength),
            predictedOvulation: ovulation,
            on: day,
            calendar: calendar
        )
        let daysUntilNext = nextStart.flatMap { calendar.dateComponents([.day], from: day, to: $0).day }
        let isPrePeriod = phase != .reset
            && (daysUntilNext.map { (1...LunePhaseEngine.softDaysBeforeReset).contains($0) } ?? false)
        return CycleDayState(cycleDay: cycleDay, phase: phase, isPrePeriod: isPrePeriod)
    }
}
