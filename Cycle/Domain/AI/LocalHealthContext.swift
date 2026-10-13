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
    private static let maxCycles = 12
    private static let maxCheckIns = 40
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
        now: Date = .now
    ) -> LocalHealthContext {
        var lines: [String] = []
        lines.append("Today: \(now.formatted(dateFormat))")
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

        let recentFlows = Array(flows.sorted { $0.date < $1.date }.suffix(30))
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
            lines.append("Prediction: \(prediction.explanation)")
            if let date = prediction.predictedDate {
                lines.append("Predicted next period: \(date.formatted(dateFormat)) (\(prediction.confidence.rawValue) confidence)")
            }
            if let ovulation = prediction.predictedOvulationDate {
                lines.append("Estimated ovulation: \(ovulation.formatted(dateFormat)) (~14 days before next period)")
            }
        }

        if !insights.isEmpty {
            lines.append("Evidence-based insights already computed on device:")
            for insight in insights.prefix(6) {
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
}
