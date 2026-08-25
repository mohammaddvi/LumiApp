import Foundation

/// Warm, Gen-Z-native copy for predictions and insights.
enum LuneVoice {
    static func resetPrediction(daysUntil: Int?) -> (headline: String, subline: String) {
        guard let daysUntil else {
            return ("new cycle incoming", "log a few resets and lune learns your rhythm.")
        }
        switch daysUntil {
        case ..<0:
            return ("reset might be here", "log how you're feeling whenever.")
        case 0:
            return ("reset's pulling up", "could be today or tomorrow.")
        case 1:
            return ("reset's pulling up", "probably tomorrow.")
        case 2...4:
            return ("reset's pulling up", "~\(daysUntil) days out.")
        default:
            return ("reset on the horizon", "about \(daysUntil) days away.")
        }
    }

    static func glowPrediction(date: Date) -> String {
        "\(LuneLexicon.ovulation.lowercased()) around \(date.formatted(.dateTime.month(.abbreviated).day()))"
    }

    static func insightHeader(for insight: InsightResult) -> String {
        "pattern spotted"
    }

    static func insightTitle(_ title: String) -> String {
        title
            .replacingOccurrences(of: "Cycle length shift", with: "your rhythm shifted")
            .replacingOccurrences(of: " timing", with: " pattern")
            .replacingOccurrences(of: " often present", with: " keeps showing up")
    }
}
