import Foundation

/// Moon-inspired cycle phases — MyLune's secret language.
enum LunePhase: String, CaseIterable, Sendable {
    case reset
    case bloom
    case glow
    case slow

    var name: String {
        switch self {
        case .reset: "Reset"
        case .bloom: "Bloom"
        case .glow: "Glow"
        case .slow: "Slow"
        }
    }

    var sfSymbolName: String {
        switch self {
        case .reset: "moonphase.new.moon"
        case .bloom: "moonphase.waxing.crescent"
        case .glow: "moonphase.full.moon"
        case .slow: "moonphase.waning.crescent"
        }
    }

    /// Plain-text fallback for VoiceOver when icons aren't shown.
    var accessibilityLabel: String { "\(name) phase" }

    var defaultEnergyLabel: String {
        switch self {
        case .reset: "low"
        case .bloom: "rising"
        case .glow: "up"
        case .slow: "fading"
        }
    }

    var defaultMoodLabel: String {
        switch self {
        case .reset: "tender"
        case .bloom: "curious"
        case .glow: "lit"
        case .slow: "soft"
        }
    }

    var defaultBodyLine: String {
        switch self {
        case .reset:
            "rest is the assignment. cancel plans guilt-free."
        case .bloom:
            "energy's loading. lowkey a good time to start things."
        case .glow:
            "main character week? protect your peace."
        case .slow:
            "go gentler than usual. your body's doing a lot rn."
        }
    }
}

/// MyLune vocabulary — warm names for clinical terms.
enum LuneLexicon {
    static let period = "Reset"
    static let ovulation = "Glow"
    static let follicular = "Bloom"
    static let luteal = "Slow"
    static let pms = "Soft days"
    static let symptoms = "Signals"
    static let checkIn = "Vibe check"
    static let tracking = "Tuning in"

    static let tagline = "your body isn't random. it's literally a pattern."
    static let subtitle = "your cycle diary — private, on your phone"
}

extension SymptomGroup {
    var luneDisplayName: String {
        switch self {
        case .body: LuneLexicon.symptoms
        case .mind: "Brain weather"
        }
    }
}

struct TodaysLuneSnapshot: Sendable, Hashable {
    let phase: LunePhase
    let cycleDay: Int
    let isSoftDays: Bool
    let moonIllumination: Double
    let headline: String
    let energyLine: String
    let moodLine: String
    let bodyLine: String
}
