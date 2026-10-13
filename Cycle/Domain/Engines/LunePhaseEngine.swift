import Foundation

/// Maps cycle day + predictions into Lumi's moon phases and daily copy.
enum LunePhaseEngine {
    static let defaultPeriodLength = 5
    static let softDaysBeforeReset = 5
    static let ovulationWindowRadius = 2

    static func snapshot(
        cycleDay: Int?,
        periodLengthDays: Int,
        predictedNextReset: Date?,
        predictedOvulation: Date?,
        todayCheckIn: DailyCheckInRecord?,
        on date: Date = .now,
        calendar: Calendar = .current
    ) -> TodaysLuneSnapshot? {
        guard let cycleDay, cycleDay >= 1 else { return nil }

        let periodLength = max(1, periodLengthDays)
        let today = calendar.startOfDay(for: date)

        let daysUntilReset: Int? = predictedNextReset.flatMap {
            calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: $0)).day
        }

        let isSoftDays = {
            guard let daysUntilReset, daysUntilReset > 0 else { return false }
            return daysUntilReset <= softDaysBeforeReset
        }()

        let phase = resolvePhase(
            cycleDay: cycleDay,
            periodLength: periodLength,
            predictedOvulation: predictedOvulation,
            on: today,
            calendar: calendar
        )

        let illumination = moonIllumination(
            phase: phase,
            cycleDay: cycleDay,
            periodLength: periodLength
        )

        let headline = headline(for: phase, isSoftDays: isSoftDays)

        let energyLabel = todayCheckIn?.energy?.luneLabel ?? phase.defaultEnergyLabel
        let moodLabel = todayCheckIn?.mood?.luneLabel ?? (isSoftDays ? "soft" : phase.defaultMoodLabel)

        let energyLine = "energy · \(energyLabel)"
        let moodLine = "mood · \(moodLabel)"

        let bodyLine: String = {
            if isSoftDays {
                if let note = todayCheckIn?.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                    return note
                }
                return todayCheckIn != nil
                    ? "soft days = gentler pacing. rest counts."
                    : "your body might want extra rest rn."
            }
            if let note = todayCheckIn?.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                return note
            }
            return phase.defaultBodyLine
        }()

        return TodaysLuneSnapshot(
            phase: phase,
            cycleDay: cycleDay,
            isSoftDays: isSoftDays,
            moonIllumination: illumination,
            headline: headline,
            energyLine: energyLine,
            moodLine: moodLine,
            bodyLine: bodyLine
        )
    }

    static func resolvePhase(
        cycleDay: Int,
        periodLength: Int,
        predictedOvulation: Date?,
        on date: Date,
        calendar: Calendar = .current
    ) -> LunePhase {
        if cycleDay <= periodLength {
            return .reset
        }

        if let ovulation = predictedOvulation {
            let ovulationDay = calendar.startOfDay(for: ovulation)
            let distance = abs(calendar.dateComponents([.day], from: date, to: ovulationDay).day ?? 99)
            if distance <= ovulationWindowRadius {
                return .glow
            }
            if date < ovulationDay {
                return .bloom
            }
            return .slow
        }

        // Fallback split when ovulation isn't estimated yet.
        if cycleDay <= periodLength + 9 {
            return .bloom
        }
        if cycleDay <= periodLength + 16 {
            return .glow
        }
        return .slow
    }

    static func headline(for phase: LunePhase, isSoftDays: Bool) -> String {
        if isSoftDays {
            return "you're in your soft era"
        }
        switch phase {
        case .reset: return "reset era"
        case .bloom: return "bloom phase"
        case .glow: return "glow phase"
        case .slow: return "slow phase"
        }
    }

    static func moonIllumination(
        phase: LunePhase,
        cycleDay: Int,
        periodLength: Int
    ) -> Double {
        switch phase {
        case .reset:
            return 0.08
        case .glow:
            return 1.0
        case .bloom:
            let daysIntoBloom = max(0, cycleDay - periodLength)
            return min(0.82, 0.2 + Double(daysIntoBloom) * 0.06)
        case .slow:
            let daysIntoSlow = max(0, cycleDay - periodLength - 10)
            return max(0.14, 0.88 - Double(daysIntoSlow) * 0.05)
        }
    }
}
