import Foundation

/// Explainable, conservative next-period prediction from completed cycle lengths.
/// Uses median of recent cycles and robust variability for range + confidence.
struct PredictionEngine: Sendable {
    static let modelVersion = "1.0.0"
    static let minimumCompletedCycles = 3
    static let recentWindow = 6

    func predict(
        completedCycles: [CompletedCycle],
        currentCycleStart: Date?,
        typicalCycleLength: Int? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> PredictionResult {
        let recent = Array(CycleCalculator.plausible(completedCycles).suffix(Self.recentWindow))

        guard recent.count >= Self.minimumCompletedCycles else {
            let fallbackLength = typicalCycleLength ?? 28
            let predicted: Date? = currentCycleStart.map {
                calendar.date(byAdding: .day, value: fallbackLength, to: calendar.startOfDay(for: $0)) ?? $0
            }
            return PredictionResult(
                calculatedAt: now,
                predictedDate: predicted,
                lowerBound: predicted.map { $0.addingDays(-3) },
                upperBound: predicted.map { $0.addingDays(3) },
                predictedOvulationDate: predicted.flatMap {
                    CycleCalculator.estimatedOvulationDate(beforeNextPeriod: $0, calendar: calendar)
                },
                confidence: .insufficient,
                medianCycleLength: typicalCycleLength,
                explanation: "We need a little more history to personalize this prediction. Keep logging — about \(Self.minimumCompletedCycles) completed cycles helps.",
                modelVersion: Self.modelVersion
            )
        }

        let lengths = recent.map(\.lengthDays)
        let median = Self.median(lengths)
        let mad = Self.medianAbsoluteDeviation(lengths, around: median)
        let halfRange = max(1, min(7, Int((Double(mad) * 1.5).rounded(.up))))

        let confidence: PredictionConfidence
        if mad <= 1 {
            confidence = .high
        } else if mad <= 3 {
            confidence = .medium
        } else {
            confidence = .low
        }

        guard let currentStart = currentCycleStart.map({ calendar.startOfDay(for: $0) }) else {
            return PredictionResult(
                calculatedAt: now,
                predictedDate: nil,
                lowerBound: nil,
                upperBound: nil,
                predictedOvulationDate: nil,
                confidence: confidence,
                medianCycleLength: median,
                explanation: "Log your current period start to estimate the next one.",
                modelVersion: Self.modelVersion
            )
        }

        let predicted = calendar.date(byAdding: .day, value: median, to: currentStart) ?? currentStart
        let lower = predicted.addingDays(-halfRange)
        let upper = predicted.addingDays(halfRange)
        let ovulation = CycleCalculator.estimatedOvulationDate(beforeNextPeriod: predicted, calendar: calendar)

        let daysIntoCycle = calendar.dateComponents(
            [.day],
            from: currentStart,
            to: calendar.startOfDay(for: now)
        ).day ?? 0

        var explanation: String
        switch confidence {
        case .high:
            explanation = "Based on your recent cycles (median \(median) days), your next period is likely around this date."
        case .medium:
            explanation = "Your recent cycles vary a bit. Next period is likely within this range (median \(median) days)."
        case .low:
            explanation = "Your cycles vary quite a bit lately. This wider range reflects that variability — not a medical issue."
        case .insufficient:
            explanation = "Building personal history."
        }

        if daysIntoCycle > median + halfRange {
            explanation = "This cycle is longer than your recent pattern. The estimate will update when you log your next period start."
        }

        return PredictionResult(
            calculatedAt: now,
            predictedDate: predicted,
            lowerBound: lower,
            upperBound: upper,
            predictedOvulationDate: ovulation,
            confidence: confidence,
            medianCycleLength: median,
            explanation: explanation,
            modelVersion: Self.modelVersion
        )
    }

    // MARK: - Stats

    static func median(_ values: [Int]) -> Int {
        guard !values.isEmpty else { return 28 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return Int((Double(sorted[mid - 1] + sorted[mid]) / 2.0).rounded())
        }
        return sorted[mid]
    }

    static func medianAbsoluteDeviation(_ values: [Int], around center: Int) -> Int {
        guard !values.isEmpty else { return 0 }
        let deviations = values.map { abs($0 - center) }
        return median(deviations)
    }
}
