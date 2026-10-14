import Foundation
import SwiftData

@Model
final class SDCycle {
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var endDate: Date?
    var sourceRaw: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \SDFlowEntry.cycle)
    var flowEntries: [SDFlowEntry] = []

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date? = nil,
        source: CycleSource = .user,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.startDate = startDate.startOfDay
        self.endDate = endDate.map(\.startOfDay)
        self.sourceRaw = source.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var source: CycleSource {
        get { CycleSource(rawValue: sourceRaw) ?? .user }
        set { sourceRaw = newValue.rawValue }
    }

    func toDomain() -> CycleRecord {
        CycleRecord(
            id: id,
            startDate: startDate,
            endDate: endDate,
            source: source,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

@Model
final class SDFlowEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var intensityRaw: String
    var spotting: Bool
    var cycle: SDCycle?

    init(
        id: UUID = UUID(),
        date: Date,
        intensity: FlowIntensity,
        spotting: Bool = false,
        cycle: SDCycle? = nil
    ) {
        self.id = id
        self.date = date.startOfDay
        self.intensityRaw = intensity.rawValue
        self.spotting = spotting
        self.cycle = cycle
    }

    var intensity: FlowIntensity {
        get { FlowIntensity(rawValue: intensityRaw) ?? .medium }
        set { intensityRaw = newValue.rawValue }
    }

    func toDomain() -> FlowEntryRecord? {
        guard let cycleId = cycle?.id else { return nil }
        return FlowEntryRecord(
            id: id,
            date: date,
            intensity: intensity,
            spotting: spotting,
            cycleId: cycleId
        )
    }
}

@Model
final class SDDailyCheckIn {
    @Attribute(.unique) var id: UUID
    var date: Date
    var moodRaw: Int?
    var energyRaw: Int?
    var sleepQualityRaw: Int?
    var note: String?
    var symptomsData: Data
    /// Added in `LuneSchemaV2`.
    var feelingRaw: String?

    init(
        id: UUID = UUID(),
        date: Date,
        mood: MoodLevel? = nil,
        energy: EnergyLevel? = nil,
        sleepQuality: SleepQuality? = nil,
        symptoms: [SymptomOccurrence] = [],
        note: String? = nil,
        feeling: Feeling? = nil
    ) {
        self.id = id
        self.date = date.startOfDay
        self.moodRaw = mood?.rawValue
        self.energyRaw = energy?.rawValue
        self.sleepQualityRaw = sleepQuality?.rawValue
        self.note = note
        self.symptomsData = (try? JSONEncoder().encode(symptoms.map(CodableSymptom.init))) ?? Data()
        self.feelingRaw = feeling?.rawValue
    }

    var feeling: Feeling? {
        get { feelingRaw.flatMap(Feeling.init(rawValue:)) }
        set { feelingRaw = newValue?.rawValue }
    }

    var mood: MoodLevel? {
        get { moodRaw.flatMap(MoodLevel.init(rawValue:)) }
        set { moodRaw = newValue?.rawValue }
    }

    var energy: EnergyLevel? {
        get { energyRaw.flatMap(EnergyLevel.init(rawValue:)) }
        set { energyRaw = newValue?.rawValue }
    }

    var sleepQuality: SleepQuality? {
        get { sleepQualityRaw.flatMap(SleepQuality.init(rawValue:)) }
        set { sleepQualityRaw = newValue?.rawValue }
    }

    var symptoms: [SymptomOccurrence] {
        get {
            (try? JSONDecoder().decode([CodableSymptom].self, from: symptomsData))?.map(\.asDomain) ?? []
        }
        set {
            symptomsData = (try? JSONEncoder().encode(newValue.map(CodableSymptom.init))) ?? Data()
        }
    }

    func toDomain() -> DailyCheckInRecord {
        DailyCheckInRecord(
            id: id,
            date: date,
            mood: mood,
            energy: energy,
            sleepQuality: sleepQuality,
            symptoms: symptoms,
            note: note,
            feeling: feeling
        )
    }
}

@Model
final class SDPreferences {
    var id: String
    var hasCompletedOnboarding: Bool
    var typicalCycleLength: Int?
    var firstDayOfWeek: Int
    var notificationsEnabled: Bool
    var periodReminderEnabled: Bool
    var pmsReminderEnabled: Bool = false
    var symptomReminderEnabled: Bool = false
    var checkInReminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var biometricLockEnabled: Bool
    var experiencesPMS: Bool = false
    var typicalPeriodSymptomsData: Data = Data()
    var typicalPMSSymptomsData: Data = Data()
    var iMessageContactsData: Data = Data()
    var iMessageRemindersEnabled: Bool = false
    var appearanceModeRaw: String = AppearanceMode.light.rawValue
    /// What Lumi calls you (schema V3); optional.
    var userName: String? = nil

    init(from preferences: UserPreferences = .default) {
        self.id = "default"
        self.hasCompletedOnboarding = preferences.hasCompletedOnboarding
        self.typicalCycleLength = preferences.typicalCycleLength
        self.firstDayOfWeek = preferences.firstDayOfWeek
        self.notificationsEnabled = preferences.notificationsEnabled
        self.periodReminderEnabled = preferences.periodReminderEnabled
        self.pmsReminderEnabled = preferences.pmsReminderEnabled
        self.symptomReminderEnabled = preferences.symptomReminderEnabled
        self.checkInReminderEnabled = preferences.checkInReminderEnabled
        self.reminderHour = preferences.reminderHour
        self.reminderMinute = preferences.reminderMinute
        self.biometricLockEnabled = preferences.biometricLockEnabled
        self.experiencesPMS = preferences.experiencesPMS
        self.typicalPeriodSymptomsData = Self.encodeSymptoms(preferences.typicalPeriodSymptoms)
        self.typicalPMSSymptomsData = Self.encodeSymptoms(preferences.typicalPMSSymptoms)
        self.iMessageContactsData = Self.encodeContacts(preferences.iMessageContacts)
        self.iMessageRemindersEnabled = preferences.iMessageRemindersEnabled
        self.appearanceModeRaw = preferences.appearanceMode.rawValue
        self.userName = preferences.userName
    }

    func apply(_ preferences: UserPreferences) {
        hasCompletedOnboarding = preferences.hasCompletedOnboarding
        typicalCycleLength = preferences.typicalCycleLength
        firstDayOfWeek = preferences.firstDayOfWeek
        notificationsEnabled = preferences.notificationsEnabled
        periodReminderEnabled = preferences.periodReminderEnabled
        pmsReminderEnabled = preferences.pmsReminderEnabled
        symptomReminderEnabled = preferences.symptomReminderEnabled
        checkInReminderEnabled = preferences.checkInReminderEnabled
        reminderHour = preferences.reminderHour
        reminderMinute = preferences.reminderMinute
        biometricLockEnabled = preferences.biometricLockEnabled
        experiencesPMS = preferences.experiencesPMS
        typicalPeriodSymptomsData = Self.encodeSymptoms(preferences.typicalPeriodSymptoms)
        typicalPMSSymptomsData = Self.encodeSymptoms(preferences.typicalPMSSymptoms)
        iMessageContactsData = Self.encodeContacts(preferences.iMessageContacts)
        iMessageRemindersEnabled = preferences.iMessageRemindersEnabled
        appearanceModeRaw = preferences.appearanceMode.rawValue
        userName = preferences.userName
    }

    func toDomain() -> UserPreferences {
        UserPreferences(
            hasCompletedOnboarding: hasCompletedOnboarding,
            typicalCycleLength: typicalCycleLength,
            firstDayOfWeek: firstDayOfWeek,
            notificationsEnabled: notificationsEnabled,
            periodReminderEnabled: periodReminderEnabled,
            pmsReminderEnabled: pmsReminderEnabled,
            symptomReminderEnabled: symptomReminderEnabled,
            checkInReminderEnabled: checkInReminderEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            biometricLockEnabled: biometricLockEnabled,
            experiencesPMS: experiencesPMS,
            typicalPeriodSymptoms: Self.decodeSymptoms(typicalPeriodSymptomsData),
            typicalPMSSymptoms: Self.decodeSymptoms(typicalPMSSymptomsData),
            iMessageContacts: Self.decodeContacts(iMessageContactsData),
            iMessageRemindersEnabled: iMessageRemindersEnabled,
            appearanceMode: AppearanceMode(rawValue: appearanceModeRaw) ?? .light,
            userName: userName
        )
    }

    private static func encodeSymptoms(_ symptoms: [SymptomType]) -> Data {
        (try? JSONEncoder().encode(symptoms.map(\.rawValue))) ?? Data()
    }

    private static func decodeSymptoms(_ data: Data) -> [SymptomType] {
        let raw = (try? JSONDecoder().decode([String].self, from: data)) ?? []
        return raw.compactMap(SymptomType.init(rawValue:))
    }

    private static func encodeContacts(_ contacts: [MessageContact]) -> Data {
        (try? JSONEncoder().encode(contacts)) ?? Data()
    }

    private static func decodeContacts(_ data: Data) -> [MessageContact] {
        (try? JSONDecoder().decode([MessageContact].self, from: data)) ?? []
    }
}

private struct CodableSymptom: Codable {
    var symptomType: String
    var intensity: Int

    init(_ occurrence: SymptomOccurrence) {
        symptomType = occurrence.symptomType.rawValue
        intensity = occurrence.intensity.rawValue
    }

    var asDomain: SymptomOccurrence {
        SymptomOccurrence(
            symptomType: SymptomType(rawValue: symptomType) ?? .cramps,
            intensity: IntensityLevel(rawValue: intensity) ?? .mild
        )
    }
}
