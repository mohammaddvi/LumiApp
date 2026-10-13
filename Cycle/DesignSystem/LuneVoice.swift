import Foundation

/// Warm, Gen-Z-native copy for predictions and insights.
enum LuneVoice {
    static func resetPrediction(daysUntil: Int?) -> (headline: String, subline: String) {
        guard let daysUntil else {
            return ("new cycle incoming", "log a few resets and lumi learns your rhythm.")
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

    // MARK: - Today / Lumi

    static func greeting(hour: Int) -> String {
        switch hour {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        case 17..<22: "Good evening"
        default: "Hi, night owl"
        }
    }

    /// Lumi's reply once a feeling is logged.
    static func lumiMessage(for feeling: Feeling) -> String {
        switch feeling {
        case .happy: "Great! Keep going!"
        case .calm: "Everything feels more balanced."
        case .tired: "Rest is productive too."
        case .anxious: "It's okay to feel this way."
        case .irritable: "You're doing more than you think."
        case .sad: "It's just a phase. You'll feel better soon."
        }
    }


    /// Lumi's first message in Ask Lumi.
    /// - Parameter canPersonalize: false while the AI model isn't installed, so Lumi doesn't promise more.
    static func askOpener(cycleDay: Int?, moment: CycleMoment?, experiencesPMS: Bool, canPersonalize: Bool) -> String {
        guard let cycleDay, let moment else {
            return "Hi! I'm Lumi. Log your period and I'll share ideas for every phase of your cycle."
        }
        let opener = "Hi! It's day \(cycleDay), \(moment.displayName(experiencesPMS: experiencesPMS)). Here are a few ideas for today."
        return canPersonalize ? opener + " Tap one and I'll make it personal." : opener
    }

    static let askAnything = "Or ask me anything"
    static let aiDownloadHint = "Download Lumi's AI in Settings → AI to start chatting."
    static let aiPreparing = "Getting Lumi ready…"
    static let aiFailed = "Lumi's AI couldn't start."
    static let aiInputDisabled = "Download the AI in Settings first"

    // MARK: - Planning ahead

    static func plannedDayTitle(_ kind: PlannedDayKind, experiencesPMS: Bool) -> String {
        switch kind {
        case .period: "Period"
        case .prePeriod: experiencesPMS ? "PMS days" : "Days before period"
        case .ovulation: "Ovulation"
        }
    }

    static func tripTip(_ kind: PlannedDayKind, experiencesPMS: Bool) -> String {
        switch kind {
        case .period: "Pack period products and something cozy, just in case."
        case .prePeriod: experiencesPMS
            ? "PMS days can bring cravings or lower energy. Plan a little downtime."
            : "The days before your period can feel lower energy. Plan a little downtime."
        case .ovulation: "Energy is often higher around ovulation. Great for busy days."
        }
    }

    static let tripAllClearTitle = "All clear!"
    static let tripAllClearBody = "Nothing from your cycle is expected during these dates."
    static let tripHeadsUpTitle = "Heads-up for your trip"

    static func predictionShift(days: Int) -> String {
        "Predictions can shift by about ±\(days) \(days == 1 ? "day" : "days"). Not a form of birth control."
    }

    /// Lumi's daily question when nothing is logged yet (one is picked at random).
    static let lumiAsksFeeling = [
        "Hi! How are you feeling today?",
        "Hey you! How's your heart today?",
        "Tell me, how do you feel today?",
        "I'm here for you. How's today going?",
    ]

    static let lumiIntroTitle = "Hi! I'm Lumi"
    static let lumiIntroMessage = "Tell me how you feel and I'll feel it with you."
    static let feelingPrompt = "How are you feeling today?"
    static let logFeeling = "Log my feeling"
    static let updateFeeling = "Update my feeling"
    static let pickFeelingFirst = "Pick a feeling first"
    static let feelingLogged = "Logged for today"
}
