import Foundation

/// Deterministic, evidence-based personal insights. Never diagnoses.
struct InsightEngine: Sendable {
    static let copyVersion = "1.1.0"

    func generate(
        completedCycles: [CompletedCycle],
        checkIns: [DailyCheckInRecord],
        cycleStarts: [Date],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [InsightResult] {
        var insights: [InsightResult] = []

        if let cycleChange = cycleLengthChangeInsight(completedCycles: completedCycles, now: now) {
            insights.append(cycleChange)
        }

        insights.append(contentsOf: symptomTimingInsights(
            checkIns: checkIns,
            cycleStarts: cycleStarts,
            now: now,
            calendar: calendar
        ))

        insights.append(contentsOf: frequencyInsights(
            checkIns: checkIns,
            cycleStarts: cycleStarts,
            now: now,
            calendar: calendar
        ))

        insights.append(contentsOf: intensityChangeInsights(
            checkIns: checkIns,
            cycleStarts: cycleStarts,
            now: now,
            calendar: calendar
        ))

        return insights
    }

    // MARK: - Cycle change (≥3 recent vs prior baseline)

    private func cycleLengthChangeInsight(
        completedCycles: [CompletedCycle],
        now: Date
    ) -> InsightResult? {
        guard completedCycles.count >= 6 else { return nil }
        let recent = Array(completedCycles.suffix(3))
        let prior = Array(completedCycles.dropLast(3).suffix(3))
        guard prior.count == 3 else { return nil }

        let recentAvg = Double(recent.map(\.lengthDays).reduce(0, +)) / 3.0
        let priorAvg = Double(prior.map(\.lengthDays).reduce(0, +)) / 3.0
        let delta = recentAvg - priorAvg
        guard abs(delta) >= 2 else { return nil }

        let days = Int(abs(delta).rounded())
        let direction = delta > 0 ? "longer" : "shorter"
        return InsightResult(
            id: UUID(),
            kind: .cycleChange,
            generatedAt: now,
            title: "Cycle length shift",
            body: "Your recent cycles have been about \(days) day\(days == 1 ? "" : "s") \(direction) than your earlier average.",
            evidence: "Comparing your last 3 cycles to the 3 before that.",
            copyVersion: Self.copyVersion,
            deltaDays: Int(delta.rounded())
        )
    }

    // MARK: - Symptom timing (≥4 cycles with ≥3 occurrences in similar window)

    private func symptomTimingInsights(
        checkIns: [DailyCheckInRecord],
        cycleStarts: [Date],
        now: Date,
        calendar: Calendar
    ) -> [InsightResult] {
        let starts = cycleStarts.map { calendar.startOfDay(for: $0) }.sorted()
        guard starts.count >= 4 else { return [] }

        let recentStarts = Array(starts.suffix(6))
        var results: [InsightResult] = []

        for symptom in SymptomType.allCases where symptom != .mood && symptom != .energy && symptom != .sleep {
            var cycleHits = 0
            var offsets: [Int] = []

            for start in recentStarts {
                let nextStart = starts.first(where: { $0 > start })
                let windowEnd = nextStart ?? now.startOfDay
                let inCycle = checkIns.filter {
                    let d = calendar.startOfDay(for: $0.date)
                    return d >= start && d < windowEnd && $0.symptoms.contains { $0.symptomType == symptom }
                }
                if let first = inCycle.min(by: { $0.date < $1.date }) {
                    let offset = calendar.dateComponents(
                        [.day],
                        from: start,
                        to: calendar.startOfDay(for: first.date)
                    ).day ?? 0
                    // Prefer pre-period window: last 3 days of typical cycle (~days before next start)
                    if let next = nextStart {
                        let daysBefore = calendar.dateComponents(
                            [.day],
                            from: calendar.startOfDay(for: first.date),
                            to: next
                        ).day ?? 0
                        if daysBefore >= 0 && daysBefore <= 3 {
                            cycleHits += 1
                            offsets.append(daysBefore)
                        }
                    } else if offset >= 0 {
                        // open cycle — skip for timing against next period
                    }
                }
            }

            guard cycleHits >= 3, recentStarts.count >= 4 else { continue }
            let avgBefore = offsets.isEmpty ? 1 : Int((Double(offsets.reduce(0, +)) / Double(offsets.count)).rounded())
            let low = max(1, avgBefore - 1)
            let high = avgBefore + 1

            results.append(
                InsightResult(
                    id: UUID(),
                    kind: .symptomTiming,
                    generatedAt: now,
                    title: "\(symptom.displayName) timing",
                    body: "You often log \(symptom.displayName.lowercased()) shortly before your period.",
                    evidence: "Logged in \(cycleHits) of your last \(recentStarts.count) cycles, usually \(low)–\(high) day\(high == 1 ? "" : "s") before your period.",
                    copyVersion: Self.copyVersion,
                    symptom: symptom,
                    hits: cycleHits,
                    outOf: recentStarts.count,
                    daysBefore: low...high
                )
            )
        }

        return results
    }

    // MARK: - Frequency (≥6 opportunities)

    private func frequencyInsights(
        checkIns: [DailyCheckInRecord],
        cycleStarts: [Date],
        now: Date,
        calendar: Calendar
    ) -> [InsightResult] {
        let starts = cycleStarts.map { calendar.startOfDay(for: $0) }.sorted()
        let recentStarts = Array(starts.suffix(6))
        guard recentStarts.count >= 6 else { return [] }

        var results: [InsightResult] = []
        for symptom in [SymptomType.fatigue, .cramps, .bloating, .headache] {
            var hits = 0
            for start in recentStarts {
                let next = starts.first(where: { $0 > start }) ?? now.startOfDay.addingDays(1)
                let found = checkIns.contains {
                    let d = calendar.startOfDay(for: $0.date)
                    return d >= start && d < next && $0.symptoms.contains { $0.symptomType == symptom }
                }
                if found { hits += 1 }
            }
            guard hits >= 5 else { continue }
            results.append(
                InsightResult(
                    id: UUID(),
                    kind: .frequency,
                    generatedAt: now,
                    title: "\(symptom.displayName) often present",
                    body: "\(symptom.displayName) showed up in most of your recent cycles.",
                    evidence: "Logged in \(hits) of your last \(recentStarts.count) cycles.",
                    copyVersion: Self.copyVersion,
                    symptom: symptom,
                    hits: hits,
                    outOf: recentStarts.count
                )
            )
        }
        return results
    }

    // MARK: - Intensity change (≥4 comparable records)

    private func intensityChangeInsights(
        checkIns: [DailyCheckInRecord],
        cycleStarts: [Date],
        now: Date,
        calendar: Calendar
    ) -> [InsightResult] {
        guard let latestStart = cycleStarts.map({ calendar.startOfDay(for: $0) }).max() else { return [] }
        let priorStarts = cycleStarts
            .map { calendar.startOfDay(for: $0) }
            .filter { $0 < latestStart }
            .sorted()
        guard priorStarts.count >= 1 else { return [] }

        var results: [InsightResult] = []
        for symptom in [SymptomType.cramps, .headache, .bloating] {
            let currentIntensities = intensities(
                for: symptom,
                from: latestStart,
                until: now.startOfDay.addingDays(1),
                in: checkIns,
                calendar: calendar
            )
            let historical = priorStarts.suffix(4).flatMap { start -> [Int] in
                let next = cycleStarts
                    .map { calendar.startOfDay(for: $0) }
                    .first(where: { $0 > start }) ?? now.startOfDay
                return intensities(for: symptom, from: start, until: next, in: checkIns, calendar: calendar)
            }

            guard currentIntensities.count >= 1, historical.count >= 4 else { continue }
            let currentAvg = Double(currentIntensities.reduce(0, +)) / Double(currentIntensities.count)
            let histAvg = Double(historical.reduce(0, +)) / Double(historical.count)
            guard currentAvg - histAvg >= 0.75 else { continue }

            results.append(
                InsightResult(
                    id: UUID(),
                    kind: .symptomIntensityChange,
                    generatedAt: now,
                    title: "Stronger \(symptom.displayName.lowercased())",
                    body: "\(symptom.displayName) felt stronger than usual this cycle.",
                    evidence: "Compared \(currentIntensities.count) log\(currentIntensities.count == 1 ? "" : "s") this cycle to \(historical.count) earlier records.",
                    copyVersion: Self.copyVersion,
                    symptom: symptom
                )
            )
        }
        return results
    }

    private func intensities(
        for symptom: SymptomType,
        from start: Date,
        until end: Date,
        in checkIns: [DailyCheckInRecord],
        calendar: Calendar
    ) -> [Int] {
        checkIns.compactMap { entry in
            let d = calendar.startOfDay(for: entry.date)
            guard d >= start && d < end else { return nil }
            return entry.symptoms.first { $0.symptomType == symptom }?.intensity.rawValue
        }
    }
}
