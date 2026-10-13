import Foundation

/// Lumi's guess for how today might feel.
struct FeelingForecast: Equatable, Sendable {
    enum Basis: Equatable, Sendable {
        /// The person logged this feeling most often around this cycle day in past cycles.
        case history(sampleCount: Int)
        /// Not enough history yet; a gentle default for the phase.
        case phase
    }

    let feeling: Feeling
    let basis: Basis
}

/// Guesses today's feeling from the person's own past cycles, falling back to the phase.
/// Only past cycles count (not earlier days of the current one), so the guess means "around this time".
enum FeelingForecastEngine {
    /// Past feelings within this many days of today's cycle day count as "around this time".
    static let dayWindow = 2
    static let minimumSamples = 2

    static func forecast(
        phase: LunePhase,
        cycleDay: Int,
        cycleStarts: [Date],
        checkIns: [DailyCheckInRecord],
        calendar: Calendar = .current
    ) -> FeelingForecast {
        let starts = cycleStarts.map { calendar.startOfDay(for: $0) }.sorted()
        guard let currentStart = starts.last else {
            return FeelingForecast(feeling: phaseDefault(for: phase), basis: .phase)
        }

        var counts: [Feeling: Int] = [:]
        var mostRecent: [Feeling: Date] = [:]
        for checkIn in checkIns {
            guard let feeling = checkIn.feeling else { continue }
            let day = calendar.startOfDay(for: checkIn.date)
            guard day < currentStart, let start = starts.last(where: { $0 <= day }) else { continue }
            let pastCycleDay = (calendar.dateComponents([.day], from: start, to: day).day ?? 0) + 1
            guard abs(pastCycleDay - cycleDay) <= dayWindow else { continue }
            counts[feeling, default: 0] += 1
            mostRecent[feeling] = max(mostRecent[feeling] ?? day, day)
        }

        let total = counts.values.reduce(0, +)
        guard total >= minimumSamples,
              let best = counts.max(by: {
                  ($0.value, mostRecent[$0.key, default: .distantPast])
                      < ($1.value, mostRecent[$1.key, default: .distantPast])
              })
        else {
            return FeelingForecast(feeling: phaseDefault(for: phase), basis: .phase)
        }
        return FeelingForecast(feeling: best.key, basis: .history(sampleCount: best.value))
    }

    /// Kind defaults that never guess a hard feeling: rest & recharge, energy, confidence, reflection.
    static func phaseDefault(for phase: LunePhase) -> Feeling {
        switch phase {
        case .reset: .tired
        case .bloom: .happy
        case .glow: .happy
        case .slow: .calm
        }
    }
}
