import Foundation

/// How the person feels today, picked on Today and drawn by Lumi.
/// Stored on the day's check-in; `moodLevel`/`energyLevel` keep insights and AI context working.
enum Feeling: String, Codable, CaseIterable, Sendable, Identifiable {
    case happy
    case calm
    case tired
    case anxious
    case irritable
    case sad

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .happy: "Happy"
        case .calm: "Calm"
        case .tired: "Tired"
        case .anxious: "Anxious"
        case .irritable: "Irritable"
        case .sad: "Sad"
        }
    }

    var moodLevel: MoodLevel {
        switch self {
        case .happy: .great
        case .calm: .good
        case .tired: .okay
        case .anxious, .irritable, .sad: .low
        }
    }

    /// Only feelings that say something about energy set it; the rest leave it as logged.
    var energyLevel: EnergyLevel? {
        switch self {
        case .tired: .drained
        default: nil
        }
    }
}

extension DailyCheckInRecord {
    /// Today's check-in with `feeling` applied, keeping symptoms, sleep and note.
    func applying(_ feeling: Feeling) -> DailyCheckInRecord {
        var updated = self
        updated.feeling = feeling
        updated.mood = feeling.moodLevel
        if let energy = feeling.energyLevel {
            updated.energy = energy
        }
        return updated
    }
}
