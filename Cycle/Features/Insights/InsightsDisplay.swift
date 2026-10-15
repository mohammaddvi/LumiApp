import Foundation

/// One short "Lumi noticed" line: what, a few words about when, and how often (as dots).
struct LumiNotice: Identifiable, Equatable {
    let id: String
    let emoji: String
    let name: String
    let detail: String
    /// Cycles where it showed up, out of `outOf`; `nil` when there's nothing to count.
    let hits: Int?
    let outOf: Int?
}

enum InsightsDisplay {
    /// Folds the engine's insights into one line per symptom (plus cycle length), timing first.
    static func notices(from insights: [InsightResult]) -> [LumiNotice] {
        var notices: [LumiNotice] = []

        if let change = insights.first(where: { $0.kind == .cycleChange }), let delta = change.deltaDays, delta != 0 {
            let days = abs(delta)
            notices.append(LumiNotice(
                id: "cycle",
                emoji: "🌙",
                name: "Cycle length",
                detail: "about \(days) day\(days == 1 ? "" : "s") \(delta > 0 ? "longer" : "shorter") lately",
                hits: nil,
                outOf: nil
            ))
        }

        let bySymptom = Dictionary(grouping: insights.filter { $0.symptom != nil }, by: { $0.symptom! })
        for symptom in SymptomType.allCases {
            guard let found = bySymptom[symptom] else { continue }
            let timing = found.first { $0.kind == .symptomTiming }
            let frequency = found.first { $0.kind == .frequency }
            let stronger = found.contains { $0.kind == .symptomIntensityChange }

            var parts: [String] = []
            if let range = timing?.daysBefore {
                parts.append(range.lowerBound == range.upperBound
                    ? "usually \(range.lowerBound) day\(range.lowerBound == 1 ? "" : "s") before your period"
                    : "usually \(range.lowerBound)–\(range.upperBound) days before your period")
            } else if frequency != nil {
                parts.append("shows up most cycles")
            }
            if stronger { parts.append("stronger this cycle") }
            guard !parts.isEmpty else { continue }

            let counted = timing ?? frequency
            notices.append(LumiNotice(
                id: symptom.rawValue,
                emoji: symptom.lumiEmoji,
                name: symptom.displayName,
                detail: parts.joined(separator: " · "),
                hits: counted?.hits,
                outOf: counted?.outOf
            ))
        }
        return notices
    }

    /// A friendly word for how much cycle lengths vary, instead of statistics.
    static func vibe(for stats: CycleStats) -> String {
        guard stats.cycleCount >= 3 else { return "Getting to know you 🔮" }
        switch stats.cycleDifference {
        case ...3: return "Steady ✨"
        case ...7: return "A little wavy 🌊"
        default: return "Free-spirited 🦋"
        }
    }
}

/// The dates behind one cycle bar, shown when it's tapped open.
struct CycleDates: Equatable {
    /// "Sep 17 – Sep 21 · 5 days"; `nil` when no period days are known.
    let period: String?
    /// "Sep 17 – Oct 9 · 23 days", or "Oct 10 – today · day 6" for the current cycle.
    let cycle: String
    /// "around Nov 7", current cycle only.
    let nextPeriod: String?
}

extension InsightsDisplay {
    /// A period ends on its last logged day; a cycle runs to the day before the next period starts.
    static func dates(
        for summary: CycleSummary,
        today: Date = .now,
        nextPeriod: Date? = nil,
        calendar: Calendar = .current
    ) -> CycleDates {
        let start = calendar.startOfDay(for: summary.startDate)
        let now = calendar.startOfDay(for: today)
        func day(_ date: Date) -> String {
            var style = Date.FormatStyle.dateTime.month(.abbreviated).day()
            style.timeZone = calendar.timeZone
            if calendar.component(.year, from: date) != calendar.component(.year, from: now) {
                style = style.year()
            }
            return date.formatted(style)
        }
        func days(_ count: Int) -> String { "\(count) day\(count == 1 ? "" : "s")" }
        func span(_ from: Date, _ to: Date, _ label: String) -> String {
            calendar.isDate(from, inSameDayAs: to) ? "\(day(from)) · \(label)" : "\(day(from)) – \(day(to)) · \(label)"
        }

        let period = summary.periodLength.flatMap { length -> String? in
            guard length > 0, let end = calendar.date(byAdding: .day, value: length - 1, to: start) else { return nil }
            return span(start, end, days(length))
        }

        if let length = summary.cycleLength, let end = calendar.date(byAdding: .day, value: length - 1, to: start) {
            return CycleDates(period: period, cycle: span(start, end, days(length)), nextPeriod: nil)
        }
        let cycleDay = (calendar.dateComponents([.day], from: start, to: now).day ?? 0) + 1
        return CycleDates(
            period: period,
            cycle: "\(day(start)) – today · day \(cycleDay)",
            nextPeriod: nextPeriod.map { "around \(day(calendar.startOfDay(for: $0)))" }
        )
    }
}

extension SymptomType {
    var lumiEmoji: String {
        switch self {
        case .cramps: "🌀"
        case .headache: "🤕"
        case .backPain: "💢"
        case .bloating: "🎈"
        case .breastTenderness: "🫶"
        case .nausea: "🤢"
        case .acne: "🫧"
        case .fatigue: "😴"
        case .mood: "💭"
        case .appetite: "🍫"
        case .energy: "⚡️"
        case .sleep: "🌙"
        }
    }
}
