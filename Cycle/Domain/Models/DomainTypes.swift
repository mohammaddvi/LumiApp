import Foundation

// MARK: - Flow & Symptoms

enum FlowIntensity: String, Codable, CaseIterable, Sendable, Identifiable {
    case light
    case medium
    case heavy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: "Light"
        case .medium: "Medium"
        case .heavy: "Heavy"
        }
    }
}

enum SymptomType: String, Codable, CaseIterable, Sendable, Identifiable {
    case cramps
    case headache
    case backPain
    case bloating
    case breastTenderness
    case nausea
    case acne
    case fatigue
    case mood
    case appetite
    case energy
    case sleep

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cramps: "Cramps"
        case .headache: "Headache"
        case .backPain: "Back pain"
        case .bloating: "Bloating"
        case .breastTenderness: "Breast tenderness"
        case .nausea: "Nausea"
        case .acne: "Acne"
        case .fatigue: "Fatigue"
        case .mood: "Mood"
        case .appetite: "Appetite"
        case .energy: "Energy"
        case .sleep: "Sleep"
        }
    }

    var group: SymptomGroup {
        switch self {
        case .cramps, .headache, .backPain, .bloating, .breastTenderness, .nausea, .acne:
            .body
        case .fatigue, .mood, .appetite, .energy, .sleep:
            .mind
        }
    }
}

enum SymptomGroup: String, CaseIterable, Sendable {
    case body
    case mind

    var displayName: String {
        switch self {
        case .body: "Body"
        case .mind: "Mind & lifestyle"
        }
    }
}

enum IntensityLevel: Int, Codable, CaseIterable, Sendable, Identifiable {
    case mild = 1
    case moderate = 2
    case strong = 3

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .mild: "Mild"
        case .moderate: "Moderate"
        case .strong: "Strong"
        }
    }
}

enum MoodLevel: Int, Codable, CaseIterable, Sendable, Identifiable {
    case low = 1
    case okay = 2
    case good = 3
    case great = 4

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .low: "Low"
        case .okay: "Okay"
        case .good: "Good"
        case .great: "Great"
        }
    }

    var luneLabel: String {
        switch self {
        case .low: "soft"
        case .okay: "mid"
        case .good: "good"
        case .great: "glowing"
        }
    }
}

enum EnergyLevel: Int, Codable, CaseIterable, Sendable, Identifiable {
    case drained = 1
    case low = 2
    case steady = 3
    case high = 4

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .drained: "Drained"
        case .low: "Low"
        case .steady: "Steady"
        case .high: "High"
        }
    }

    var luneLabel: String {
        switch self {
        case .drained: "empty tank"
        case .low: "low"
        case .steady: "mid"
        case .high: "up"
        }
    }
}

enum SleepQuality: Int, Codable, CaseIterable, Sendable, Identifiable {
    case poor = 1
    case fair = 2
    case good = 3
    case great = 4

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .poor: "Poor"
        case .fair: "Fair"
        case .good: "Good"
        case .great: "Great"
        }
    }
}

enum CycleSource: String, Codable, Sendable {
    case onboarding
    case user
    case inferred
}

enum PredictionConfidence: String, Codable, Sendable, Identifiable {
    case low
    case medium
    case high
    case insufficient

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .insufficient: "Building history"
        }
    }
}

enum InsightKind: String, Codable, Sendable {
    case symptomTiming
    case cycleChange
    case symptomIntensityChange
    case frequency
}

// MARK: - Domain records (persistence-agnostic)

struct CycleRecord: Identifiable, Hashable, Sendable {
    let id: UUID
    var startDate: Date
    var endDate: Date?
    var source: CycleSource
    var createdAt: Date
    var updatedAt: Date

    var periodDayCount: Int? {
        guard let endDate else { return nil }
        return Calendar.current.dateComponents([.day], from: startDate.startOfDay, to: endDate.startOfDay).day.map { $0 + 1 }
    }
}

struct FlowEntryRecord: Identifiable, Hashable, Sendable {
    let id: UUID
    var date: Date
    var intensity: FlowIntensity
    var spotting: Bool
    var cycleId: UUID
}

struct SymptomOccurrence: Hashable, Sendable {
    var symptomType: SymptomType
    var intensity: IntensityLevel
}

struct DailyCheckInRecord: Identifiable, Hashable, Sendable {
    let id: UUID
    var date: Date
    var mood: MoodLevel?
    var energy: EnergyLevel?
    var sleepQuality: SleepQuality?
    var symptoms: [SymptomOccurrence]
    var note: String?
    var feeling: Feeling? = nil
}

struct CompletedCycle: Hashable, Sendable {
    let startDate: Date
    let lengthDays: Int
    let periodLengthDays: Int
}

struct PredictionResult: Hashable, Sendable {
    let calculatedAt: Date
    let predictedDate: Date?
    let lowerBound: Date?
    let upperBound: Date?
    /// Estimated ovulation for the current cycle (typically ~14 days before next period).
    let predictedOvulationDate: Date?
    let confidence: PredictionConfidence
    let medianCycleLength: Int?
    let explanation: String
    let modelVersion: String
}

struct InsightResult: Identifiable, Hashable, Sendable {
    let id: UUID
    let kind: InsightKind
    let generatedAt: Date
    let title: String
    let body: String
    let evidence: String
    let copyVersion: String
}

enum AppearanceMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case light
    case dark
    case system

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        case .system: "System"
        }
    }
}

struct UserPreferences: Hashable, Sendable {
    var hasCompletedOnboarding: Bool
    var typicalCycleLength: Int?
    var firstDayOfWeek: Int
    var notificationsEnabled: Bool
    var periodReminderEnabled: Bool
    var pmsReminderEnabled: Bool
    var symptomReminderEnabled: Bool
    var checkInReminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var biometricLockEnabled: Bool
    /// User-reported PMS experience from onboarding.
    var experiencesPMS: Bool
    /// Baseline symptoms the user typically has during their period.
    var typicalPeriodSymptoms: [SymptomType]
    /// Baseline symptoms the user typically has during PMS (if any).
    var typicalPMSSymptoms: [SymptomType]
    /// Legacy: the removed "Messages to your people" feature. Kept only because it is part of the
    /// stored schema; cleared on launch and never used.
    var iMessageContacts: [MessageContact]
    var iMessageRemindersEnabled: Bool
    /// Defaults to light (lavender mist) so the look stays consistent.
    var appearanceMode: AppearanceMode
    /// What Lumi calls you; `nil` until you tell her.
    var userName: String? = nil

    /// Longest name Lumi stores; keeps bubbles and greetings tidy.
    static let maxNameLength = 30

    /// Trimmed, length-limited name, or `nil` when blank.
    static func cleanedName(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxNameLength))
    }

    static let `default` = UserPreferences(
        hasCompletedOnboarding: false,
        typicalCycleLength: nil,
        firstDayOfWeek: 1,
        notificationsEnabled: false,
        periodReminderEnabled: false,
        pmsReminderEnabled: false,
        symptomReminderEnabled: false,
        checkInReminderEnabled: false,
        reminderHour: 9,
        reminderMinute: 0,
        biometricLockEnabled: false,
        experiencesPMS: false,
        typicalPeriodSymptoms: [],
        typicalPMSSymptoms: [],
        iMessageContacts: [],
        iMessageRemindersEnabled: false,
        appearanceMode: .light
    )
}

struct MessageContact: Identifiable, Hashable, Codable, Sendable {
    var id: UUID
    var label: String
    var phoneNumber: String

    init(id: UUID = UUID(), label: String = "", phoneNumber: String) {
        self.id = id
        self.label = label
        self.phoneNumber = phoneNumber
    }

    var displayName: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? phoneNumber : trimmed
    }

    var normalizedNumber: String {
        phoneNumber.filter { $0.isNumber || $0 == "+" }
    }

    var isValid: Bool {
        phoneNumber.filter(\.isNumber).count >= 7
    }
}

/// Snapshot of answers collected during first-run onboarding.
struct OnboardingProfile: Sendable {
    var userName: String? = nil
    var lastPeriodStart: Date
    var typicalCycleLength: Int?
    var experiencesPMS: Bool
    var periodSymptoms: [SymptomType]
    var pmsSymptoms: [SymptomType]
    var remindPeriodClose: Bool
    var remindPMSClose: Bool
    var remindSymptoms: Bool
}

struct CycleSummary: Identifiable, Hashable, Sendable {
    let id: UUID
    let startDate: Date
    let cycleLength: Int?
    let periodLength: Int?
    let checkInCount: Int
    let isComplete: Bool
}

// MARK: - Date helpers

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    func addingDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }

    func daysSince(_ other: Date) -> Int {
        Calendar.current.dateComponents([.day], from: other.startOfDay, to: startOfDay).day ?? 0
    }
}

enum CalendarDayStatus: Hashable, Sendable {
    case none
    case period
    case spotting
    case logged
}
