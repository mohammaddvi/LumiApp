import Foundation

/// What a future day is likely to be, for planning ahead.
enum PlannedDayKind: Equatable, Sendable {
    case period
    /// Lumi's "soft days" before a period (PMS days for people who get PMS).
    case prePeriod
    case ovulation
}

/// One predicted future cycle.
struct UpcomingCycle: Equatable, Sendable, Identifiable {
    let periodStart: Date
    let periodEnd: Date
    /// About how many days the period start could move either way.
    let uncertaintyDays: Int
    let prePeriodStart: Date
    let ovulation: Date

    var id: Date { periodStart }
}

/// A run of trip days that fall on one kind of predicted day.
struct PlanOverlap: Equatable, Sendable {
    let kind: PlannedDayKind
    let start: Date
    let end: Date
}

/// Upcoming cycles projected from the next predicted period, so people can plan trips and events.
struct CycleOutlook: Equatable, Sendable {
    let cycles: [UpcomingCycle]
    let calendar: Calendar

    /// Period beats ovulation beats pre-period when they touch.
    func kind(on date: Date) -> PlannedDayKind? {
        let day = calendar.startOfDay(for: date)
        for cycle in cycles {
            if day >= cycle.periodStart && day <= cycle.periodEnd { return .period }
        }
        for cycle in cycles where cycle.ovulation == day {
            return .ovulation
        }
        for cycle in cycles where day >= cycle.prePeriodStart && day < cycle.periodStart {
            return .prePeriod
        }
        return nil
    }

    /// Predicted days during a trip, merged into runs. Trips longer than ~4 months are clipped.
    func overlaps(tripStart: Date, tripEnd: Date) -> [PlanOverlap] {
        let start = calendar.startOfDay(for: min(tripStart, tripEnd))
        let end = calendar.startOfDay(for: max(tripStart, tripEnd))
        var runs: [PlanOverlap] = []
        var day = start
        var steps = 0
        while day <= end && steps < 124 {
            if let kind = kind(on: day) {
                if let last = runs.last, last.kind == kind,
                   calendar.date(byAdding: .day, value: 1, to: last.end) == day {
                    runs[runs.count - 1] = PlanOverlap(kind: kind, start: last.start, end: day)
                } else {
                    runs.append(PlanOverlap(kind: kind, start: day, end: day))
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
            steps += 1
        }
        return runs
    }
}

enum CycleOutlookEngine {
    /// About a year ahead.
    static let defaultCount = 13
    static let maxUncertainty = 7

    static func outlook(
        nextPeriodStart: Date,
        cycleLength: Int,
        periodLength: Int,
        baseUncertainty: Int,
        count: Int = defaultCount,
        calendar: Calendar = .current
    ) -> CycleOutlook {
        let first = calendar.startOfDay(for: nextPeriodStart)
        let length = max(15, cycleLength)
        let bleeding = max(1, periodLength)
        let cycles: [UpcomingCycle] = (0..<max(0, count)).compactMap { index in
            guard let start = calendar.date(byAdding: .day, value: index * length, to: first),
                  let end = calendar.date(byAdding: .day, value: bleeding - 1, to: start),
                  let prePeriod = calendar.date(byAdding: .day, value: -LunePhaseEngine.softDaysBeforeReset, to: start),
                  let ovulation = CycleCalculator.estimatedOvulationDate(beforeNextPeriod: start, calendar: calendar)
            else { return nil }
            return UpcomingCycle(
                periodStart: start,
                periodEnd: end,
                // Further-out cycles are less certain: widen by a day every other cycle.
                uncertaintyDays: min(maxUncertainty, max(1, baseUncertainty) + index / 2),
                prePeriodStart: prePeriod,
                ovulation: calendar.startOfDay(for: ovulation)
            )
        }
        return CycleOutlook(cycles: cycles, calendar: calendar)
    }
}
