import Foundation

/// Pure domain helpers for building completed cycles and calendar day state.
enum CycleCalculator {
    /// Typical luteal-phase length used for ovulation estimates (not a medical claim).
    static let typicalLutealPhaseDays = 14

    /// Minimum cycle length before we trust an ovulation estimate.
    static let minimumCycleLengthForOvulation = 21

    /// Estimated ovulation from cycle start + length: `start + (length − luteal days)`.
    static func estimatedOvulationDate(
        cycleStart: Date,
        cycleLengthDays: Int,
        calendar: Calendar = .current
    ) -> Date? {
        guard cycleLengthDays >= minimumCycleLengthForOvulation else { return nil }
        let offset = cycleLengthDays - typicalLutealPhaseDays
        guard offset > 0 else { return nil }
        let start = calendar.startOfDay(for: cycleStart)
        return calendar.date(byAdding: .day, value: offset, to: start)
    }

    /// Estimated ovulation from a predicted (or observed) next-period start.
    static func estimatedOvulationDate(
        beforeNextPeriod nextPeriodStart: Date,
        calendar: Calendar = .current
    ) -> Date? {
        let next = calendar.startOfDay(for: nextPeriodStart)
        return calendar.date(byAdding: .day, value: -typicalLutealPhaseDays, to: next)
    }

    /// Builds completed cycles from ordered period starts (ascending).
    /// Cycle length = days from this start to the next start.
    static func completedCycles(
        fromStarts starts: [Date],
        periodLengthsByStart: [Date: Int] = [:],
        calendar: Calendar = .current
    ) -> [CompletedCycle] {
        let sorted = starts.map { calendar.startOfDay(for: $0) }.sorted()
        guard sorted.count >= 2 else { return [] }

        var result: [CompletedCycle] = []
        for index in 0..<(sorted.count - 1) {
            let start = sorted[index]
            let next = sorted[index + 1]
            let length = calendar.dateComponents([.day], from: start, to: next).day ?? 0
            guard length > 0 else { continue }
            let periodLength = periodLengthsByStart[start] ?? min(5, length)
            result.append(
                CompletedCycle(
                    startDate: start,
                    lengthDays: length,
                    periodLengthDays: periodLength
                )
            )
        }
        return result
    }

    static func currentCycleDay(
        latestStart: Date?,
        on date: Date = .now,
        calendar: Calendar = .current
    ) -> Int? {
        guard let latestStart else { return nil }
        let day = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: latestStart),
            to: calendar.startOfDay(for: date)
        ).day
        guard let day, day >= 0 else { return nil }
        return day + 1
    }

    static func overlapsExistingPeriod(
        proposedStart: Date,
        proposedEnd: Date?,
        existing: [(start: Date, end: Date?)],
        calendar: Calendar = .current
    ) -> Bool {
        let start = calendar.startOfDay(for: proposedStart)
        let end = calendar.startOfDay(for: proposedEnd ?? proposedStart)
        for entry in existing {
            let otherStart = calendar.startOfDay(for: entry.start)
            let otherEnd = calendar.startOfDay(for: entry.end ?? entry.start)
            if start <= otherEnd && end >= otherStart {
                return true
            }
        }
        return false
    }
}
