import Foundation

/// Gen-Z emoji vocabulary — one place for consistent vibes across the app.
enum LuneEmoji {
    static let lune = "🌙"
    static let sparkle = "✦"
    static let soft = "🥹"
    static let rest = "🛏️"
    static let vibe = "🫧"
    static let note = "☁️"
    static let pattern = "🔮"
    static let window = "🗓️"
    static let logged = "✅"
    static let message = "💬"
}

extension LunePhase {
    var emoji: String {
        switch self {
        case .reset: "🌑"
        case .bloom: "🌱"
        case .glow: "✨"
        case .slow: "🌙"
        }
    }

    var defaultEnergyEmoji: String {
        switch self {
        case .reset: "🪫"
        case .bloom: "📈"
        case .glow: "⚡"
        case .slow: "🌊"
        }
    }

    var defaultMoodEmoji: String {
        switch self {
        case .reset: "🥺"
        case .bloom: "👀"
        case .glow: "😊"
        case .slow: "🫠"
        }
    }

    var softDaysEmoji: String { LuneEmoji.soft }
}

extension MoodLevel {
    var luneEmoji: String {
        switch self {
        case .low: "🥺"
        case .okay: "😌"
        case .good: "🙂"
        case .great: "✨"
        }
    }
}

extension EnergyLevel {
    var luneEmoji: String {
        switch self {
        case .drained: "🪫"
        case .low: "🔋"
        case .steady: "💫"
        case .high: "⚡"
        }
    }
}

extension SymptomType {
    var luneEmoji: String? {
        switch self {
        case .cramps: "🔥"
        case .bloating: "🫠"
        case .nausea: "🤢"
        case .headache: "🤕"
        case .fatigue: "😵‍💫"
        case .mood: "😤"
        case .acne: "😖"
        case .backPain: "🫨"
        case .breastTenderness: "💗"
        default: nil
        }
    }
}
