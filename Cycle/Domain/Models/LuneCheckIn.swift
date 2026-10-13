import Foundation

/// One-tap feelings for the vibe check row.
enum LuneQuickFeeling: String, CaseIterable, Identifiable, Sendable {
    case good
    case sensitive
    case lowEnergy
    case nauseous
    case irritable
    case bloated
    case cramps

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .good: "🙂"
        case .sensitive: "🥺"
        case .lowEnergy: "😵‍💫"
        case .nauseous: "🤢"
        case .irritable: "😤"
        case .bloated: "🫠"
        case .cramps: "🔥"
        }
    }

    var label: String {
        switch self {
        case .good: "Good vibes"
        case .sensitive: "Soft"
        case .lowEnergy: "Empty tank"
        case .nauseous: "Icky"
        case .irritable: "Touchy"
        case .bloated: "Puffy"
        case .cramps: "Ouch"
        }
    }

    func apply(
        mood: inout MoodLevel?,
        energy: inout EnergyLevel?,
        symptoms: inout [SymptomType: IntensityLevel]
    ) {
        switch self {
        case .good:
            mood = .good
            energy = energy ?? .steady
        case .sensitive:
            mood = .low
        case .lowEnergy:
            energy = .drained
            mood = mood ?? .okay
        case .nauseous:
            symptoms[.nausea] = .moderate
        case .irritable:
            mood = .low
            symptoms[.mood] = .moderate
        case .bloated:
            symptoms[.bloating] = .moderate
        case .cramps:
            symptoms[.cramps] = .moderate
        }
    }
}

enum LuneNotePrompt: String, CaseIterable, Identifiable, Sendable {
    case feelsDifferent
    case needRest
    case feelMyself
    case dontTalk

    var id: String { rawValue }

    var text: String {
        switch self {
        case .feelsDifferent: "something feels off today"
        case .needRest: "need a rest day"
        case .feelMyself: "feeling like me again"
        case .dontTalk: "do not disturb pls 😭"
        }
    }
}
