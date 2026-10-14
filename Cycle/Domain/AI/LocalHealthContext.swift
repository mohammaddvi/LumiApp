import Foundation

/// On-device snapshot of cycle data prepared for local Gemma prompts.
/// Never includes contact numbers or anything meant to leave the device.
struct LocalHealthContext: Sendable, Equatable {
    let generatedAt: Date
    let promptBlock: String
    let cycleCount: Int
    let checkInCount: Int
}

enum LocalHealthContextBuilder {
    // Kept small: the whole prompt has to fit Gemma's on-device token budget with room for the reply.
    private static let maxCycles = 6
    private static let maxFlows = 14
    private static let maxCheckIns = 14
    private static let maxInsights = 4
    private static let followingCycles = 2
    private static let dateFormat: Date.FormatStyle = .dateTime.year().month(.abbreviated).day()

    static func build(
        preferences: UserPreferences,
        cycles: [CycleRecord],
        completedCycles: [CompletedCycle],
        checkIns: [DailyCheckInRecord],
        flows: [FlowEntryRecord],
        prediction: PredictionResult?,
        insights: [InsightResult],
        currentCycleDay: Int?,
        moment: CycleMoment? = nil,
        outlook: CycleOutlook? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> LocalHealthContext {
        var lines: [String] = []
        lines.append("Today: \(now.formatted(dateFormat))")
        if let name = preferences.userName {
            lines.append("The user's name: \(name) (use it now and then, warmly; not in every reply)")
        }
        lines.append(contentsOf: keyDateLines(prediction: prediction, outlook: outlook, now: now, calendar: calendar))
        if let day = currentCycleDay {
            lines.append("Current cycle day: \(day)")
        }
        if let moment {
            lines.append("Current phase: \(moment.displayName(experiencesPMS: preferences.experiencesPMS))")
        }
        if let typical = preferences.typicalCycleLength {
            lines.append("User-reported typical cycle length: \(typical) days")
        }
        lines.append("Experiences PMS: \(preferences.experiencesPMS ? "yes" : "no / unsure")")

        if !preferences.typicalPeriodSymptoms.isEmpty {
            let names = preferences.typicalPeriodSymptoms.map(\.displayName).joined(separator: ", ")
            lines.append("Typical period symptoms: \(names)")
        }
        if preferences.experiencesPMS, !preferences.typicalPMSSymptoms.isEmpty {
            let names = preferences.typicalPMSSymptoms.map(\.displayName).joined(separator: ", ")
            lines.append("Typical PMS symptoms: \(names)")
        }

        let recentCompleted = Array(completedCycles.suffix(maxCycles))
        if recentCompleted.isEmpty {
            lines.append("Completed cycles: none yet")
        } else {
            lines.append("Completed cycles (most recent last):")
            for cycle in recentCompleted {
                lines.append(
                    "- Start \(cycle.startDate.formatted(dateFormat)): length \(cycle.lengthDays)d, period \(cycle.periodLengthDays)d"
                )
            }
        }

        let recentCycles = Array(cycles.suffix(maxCycles))
        if !recentCycles.isEmpty {
            lines.append("Logged period starts:")
            for cycle in recentCycles {
                let end = cycle.endDate.map { $0.formatted(dateFormat) } ?? "open"
                lines.append("- \(cycle.startDate.formatted(dateFormat)) → \(end)")
            }
        }

        let recentFlows = Array(flows.sorted { $0.date < $1.date }.suffix(maxFlows))
        if !recentFlows.isEmpty {
            lines.append("Recent flow days:")
            for flow in recentFlows {
                var detail = flow.intensity.displayName.lowercased()
                if flow.spotting { detail += ", spotting" }
                lines.append("- \(flow.date.formatted(dateFormat)): \(detail)")
            }
        }

        let recentCheckIns = Array(checkIns.sorted { $0.date < $1.date }.suffix(maxCheckIns))
        if recentCheckIns.isEmpty {
            lines.append("Recent check-ins: none")
        } else {
            lines.append("Recent check-ins:")
            for checkIn in recentCheckIns {
                var parts: [String] = []
                if let feeling = checkIn.feeling { parts.append("feeling \(feeling.displayName)") }
                if let mood = checkIn.mood { parts.append("mood \(mood.displayName)") }
                if let energy = checkIn.energy { parts.append("energy \(energy.displayName)") }
                if let sleep = checkIn.sleepQuality { parts.append("sleep \(sleep.displayName)") }
                if !checkIn.symptoms.isEmpty {
                    let s = checkIn.symptoms.map {
                        "\($0.symptomType.displayName) (\($0.intensity.displayName))"
                    }.joined(separator: ", ")
                    parts.append("symptoms: \(s)")
                }
                if let note = checkIn.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                    let clipped = note.count > 120 ? String(note.prefix(117)) + "…" : note
                    parts.append("note: \(clipped)")
                }
                let body = parts.isEmpty ? "logged" : parts.joined(separator: "; ")
                lines.append("- \(checkIn.date.formatted(dateFormat)): \(body)")
            }
        }

        if let prediction {
            lines.append("Prediction note (\(prediction.confidence.rawValue) confidence): \(prediction.explanation)")
        }

        if !insights.isEmpty {
            lines.append("Evidence-based insights already computed on device:")
            for insight in insights.prefix(maxInsights) {
                lines.append("- \(insight.title): \(insight.body) (\(insight.evidence))")
            }
        }

        return LocalHealthContext(
            generatedAt: now,
            promptBlock: lines.joined(separator: "\n"),
            cycleCount: cycles.count,
            checkInCount: checkIns.count
        )
    }

    /// Upcoming dates worked out by the app, with "in N days", so the model never does date math.
    static func keyDateLines(
        prediction: PredictionResult?,
        outlook: CycleOutlook?,
        now: Date,
        calendar: Calendar = .current
    ) -> [String] {
        let today = calendar.startOfDay(for: now)
        var format = dateFormat
        format.timeZone = calendar.timeZone
        func describe(_ date: Date) -> String {
            let day = calendar.startOfDay(for: date)
            let days = calendar.dateComponents([.day], from: today, to: day).day ?? 0
            let relative = switch days {
            case 0: "today"
            case 1: "tomorrow"
            case 2...: "in \(days) days"
            case -1: "yesterday"
            default: "\(-days) days ago"
            }
            return "\(day.formatted(format)) (\(relative))"
        }

        let upcoming = (outlook?.cycles ?? []).filter { $0.periodEnd >= today }
        let periods = upcoming.map(\.periodStart)
        // The current cycle's ovulation may already be behind us; "next" means the first one still ahead.
        var ovulations = upcoming.map(\.ovulation).filter { $0 >= today }
        if ovulations.isEmpty, let ovulation = prediction?.predictedOvulationDate,
           calendar.startOfDay(for: ovulation) >= today {
            ovulations = [ovulation]
        }
        let nextPeriod = periods.first ?? prediction?.predictedDate
        guard nextPeriod != nil || !ovulations.isEmpty else { return [] }

        var lines = ["Key dates (calculated by the app; these are estimates, use them exactly):"]
        if let nextPeriod {
            var line = "- Next period: around \(describe(nextPeriod))"
            if let lower = prediction?.lowerBound, let upper = prediction?.upperBound,
               lower <= nextPeriod, nextPeriod <= upper {
                line += ", likely between \(lower.formatted(format)) and \(upper.formatted(format))"
            }
            lines.append(line)
        }
        if let ovulation = ovulations.first {
            lines.append("- Next ovulation (estimate): around \(describe(ovulation))")
            let fertile = CycleCalculator.fertileWindow(ovulation: ovulation, calendar: calendar)
            let span = "\(fertile.lowerBound.formatted(format)) to \(fertile.upperBound.formatted(format))"
            lines.append(fertile.lowerBound <= today
                ? "- Fertile window (estimate, not birth control): now, \(span)"
                : "- Fertile window (estimate, not birth control): \(span), starts \(describe(fertile.lowerBound))")
        }
        if let preStart = upcoming.first?.prePeriodStart, preStart >= today {
            lines.append("- PMS / pre-period days start: around \(describe(preStart))")
        }
        let laterPeriods = periods.dropFirst().prefix(followingCycles)
        if !laterPeriods.isEmpty {
            lines.append("- Following periods: " + laterPeriods.map { $0.formatted(format) }.joined(separator: ", "))
        }
        let laterOvulations = ovulations.dropFirst().prefix(followingCycles)
        if !laterOvulations.isEmpty {
            lines.append("- Following ovulations: " + laterOvulations.map { $0.formatted(format) }.joined(separator: ", "))
        }
        return lines
    }
}
