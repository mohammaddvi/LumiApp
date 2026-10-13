import Foundation

/// What MyLune has learned from recent completed cycles (shown in Settings → Period).
struct CycleStats: Equatable, Sendable {
    let cycleCount: Int
    /// Median days from one period start to the next.
    let typicalCycleLength: Int
    let shortestCycle: Int
    let longestCycle: Int
    /// Median bleeding days, when known.
    let typicalPeriodLength: Int?

    /// Days between the shortest and longest recent cycle.
    var cycleDifference: Int { longestCycle - shortestCycle }

    /// Uses the same recent, plausible cycles as predictions; `nil` without one.
    static func from(_ cycles: [CompletedCycle], recent: Int = PredictionEngine.recentWindow) -> CycleStats? {
        let recentCycles = Array(CycleCalculator.plausible(cycles).suffix(recent))
        let lengths = recentCycles.map(\.lengthDays)
        guard let shortest = lengths.min(), let longest = lengths.max() else { return nil }
        let periods = recentCycles.map(\.periodLengthDays).filter { $0 > 0 }
        return CycleStats(
            cycleCount: recentCycles.count,
            typicalCycleLength: PredictionEngine.median(lengths),
            shortestCycle: shortest,
            longestCycle: longest,
            typicalPeriodLength: periods.isEmpty ? nil : PredictionEngine.median(periods)
        )
    }
}
