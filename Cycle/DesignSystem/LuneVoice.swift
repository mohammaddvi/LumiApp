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

    static func greeting(hour: Int, name: String? = nil) -> String {
        let base = switch hour {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        case 17..<22: "Good evening"
        default: "Hi, night owl"
        }
        return base + comma(name)
    }

    /// ", Sara" with a name, "" without, so every line reads naturally either way.
    private static func comma(_ name: String?) -> String {
        name.map { ", \($0)" } ?? ""
    }

    /// Lumi's reply once a feeling is logged.
    static func lumiMessage(for feeling: Feeling, name: String? = nil) -> String {
        let n = comma(name)
        return switch feeling {
        case .happy: "Great\(n)! Keep going!"
        case .calm: "Everything feels more balanced\(n)."
        case .tired: "Rest is productive too\(n)."
        case .anxious: "It's okay to feel this way\(n)."
        case .irritable: "You're doing more than you think\(n)."
        case .sad: "It's just a phase\(n). You'll feel better soon."
        }
    }

    /// Lumi's line for today's situation (once a day on Today).
    static func lumiSays(_ moment: LumiMoment, name: String? = nil, experiencesPMS: Bool) -> String {
        let n = comma(name)
        return switch moment {
        case .welcome: "Hi\(n)! I'm Lumi. I'll be with you through every phase 🌙"
        case .welcomeBack: "I missed you\(n)! How have you been? 💜"
        case .periodStarted: "Day one\(n). Cozy socks, warm tea and extra rest 🍵"
        case .periodDay: "How's your flow today\(n)? Be gentle with yourself 🌸"
        case .periodEnding: "Almost through\(n)! Your energy is on its way back ✨"
        case .periodToday: "Your period may start today\(n). Pack a pad, just in case 🎒"
        case .periodTomorrow: "Heads-up\(n): your period may come tomorrow 🌙"
        case .periodLate: "Your period is a few days late\(n). Cycles shift sometimes, so no stress 💜"
        case .pmsDays: experiencesPMS
            ? "PMS days are here\(n). Extra snacks and extra kindness 🍫"
            : "Your period is getting close\(n). Slow down a little if you can 🍫"
        case .fertileStart: "Your fertile days start today\(n) 🌼 Just an estimate, not birth control."
        case .fertileDays: "You're in your fertile days\(n) 🌼 Just an estimate, not birth control."
        case .ovulation: "It's ovulation day\(n)! Many people feel extra glowy ✨"
        case .bloom: "Fresh energy is blooming\(n)! A good day to try something new 🌱"
        case .slow: "Slower days are okay\(n). Go at your own pace 🐢"
        case .lateNight: "It's late\(n)! Your body loves a good sleep 😴"
        }
    }

    /// Lumi asks once what to call you (people who set up Lumi before names existed).
    static let lumiAsksName = "Hi! What should I call you? Tap me to tell me 💜"
    static func lumiNiceToMeet(_ name: String) -> String { "Nice to meet you, \(name)! 💜" }
    static let namePrompt = "What should Lumi call you?"
    static let nameFooter = "Lumi uses your name in her messages. It stays on this iPhone."


    /// Lumi's first message in Ask Lumi, above the topic chips.
    static func askOpener(cycleDay: Int?, moment: CycleMoment?, experiencesPMS: Bool, name: String? = nil) -> String {
        let hi = "Hi" + comma(name) + "!"
        guard let cycleDay, let moment else {
            return "\(hi) I'm Lumi. Log your period and I'll have ideas for every phase 🌙"
        }
        return "\(hi) It's day \(cycleDay), \(moment.displayName(experiencesPMS: experiencesPMS)). What do you need today? ✨"
    }

    /// Lumi's offline answer to the "Next period" chip.
    static func nextPeriodAnswer(_ date: Date?, today: Date = .now) -> String {
        guard let date else { return "Log your period and I'll predict the next one 🌙" }
        let days = Calendar.current.dateComponents([.day], from: today.startOfDay, to: date.startOfDay).day ?? 0
        let when = date.formatted(.dateTime.month(.wide).day())
        let relative = switch days {
        case ..<0: "it's a little late, and that's okay"
        case 0: "that's today"
        case 1: "that's tomorrow"
        default: "in \(days) days"
        }
        return "Your next period is likely around \(when), \(relative) 🌙 Just an estimate."
    }

    static let aiPreparing = "Getting Lumi ready…"
    static let aiFailed = "Lumi's AI couldn't start."
    static let aiInputDisabled = "Download the AI in Settings first"

    // MARK: - Planning ahead

    static func plannedDayTitle(_ kind: PlannedDayKind, experiencesPMS: Bool) -> String {
        switch kind {
        case .period: "Period"
        case .prePeriod: experiencesPMS ? "PMS days" : "Days before period"
        case .fertile: "Fertile days"
        case .ovulation: "Ovulation"
        }
    }

    static func tripTip(_ kind: PlannedDayKind, experiencesPMS: Bool) -> String {
        switch kind {
        case .period: "Pack period products and something cozy, just in case."
        case .prePeriod: experiencesPMS
            ? "PMS days can bring cravings or lower energy. Plan a little downtime."
            : "The days before your period can feel lower energy. Plan a little downtime."
        case .fertile: "The days before ovulation, when pregnancy is most likely. An estimate, not birth control."
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

    // MARK: - Lumi's room

    static let roomTitle = "Lumi's room"
    static func roomWelcome(name: String? = nil) -> String { "Welcome to my room\(comma(name))!" }
    static let roomHint = "Tap me, or stroke me sideways 💜"
    static let wardrobeTitle = "Dress me up"
    static let appIconTitle = "App icon"
    static let stickersShelf = "Stickers"
    static let stickersHint = "Tap to add · drag to move · pinch to resize"
    static let stickersFull = "That's a lot of stickers! Remove one to add another."
    static func moonTonight(_ moon: MoonPhase) -> String { "\(moon.name) tonight" }
    static let breatheStart = "Breathe with me · 1 minute"
    static let breatheIn = "Breathe in…"
    static let breatheOut = "…and out"
    static func breatheRound(_ round: Int, of rounds: Int) -> String { "\(round) of \(rounds)" }
    static let breatheDone = "That was lovely. I feel calmer too 💜"
}
