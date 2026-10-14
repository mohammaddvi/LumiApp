import Foundation
import SwiftData

/// Stable on-disk layout for Lumi's SwiftData store.
/// Do not rename `directoryName` or `storeFileName` after release — updates rely on this path.
enum LuneStoreLocation {
    static let directoryName = "Cycle"
    static let storeFileName = "cycle.store"
    static let backupsFolderName = "Backups"

    static var storeDirectory: URL {
        URL.applicationSupportDirectory
            .appending(path: directoryName, directoryHint: .isDirectory)
    }

    static var storeURL: URL {
        storeDirectory.appending(path: storeFileName)
    }

    static var backupsDirectory: URL {
        storeDirectory.appending(path: backupsFolderName, directoryHint: .isDirectory)
    }

    /// Sidecar files SQLite may create alongside the store.
    static func relatedStoreFiles(for storeURL: URL) -> [URL] {
        [
            storeURL,
            storeURL.appendingPathExtension("wal"),
            storeURL.appendingPathExtension("shm"),
        ]
    }
}

// MARK: - Schema versioning

/// First schema, written by pre-release builds (MyLune 1.0) — cycles, flow, check-ins, preferences.
/// Models that changed later are frozen here as nested copies; never edit them. Pre-release stores
/// still exist on test devices, so every version keeps migrating forward.
enum LuneSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            SDCycle.self,
            SDFlowEntry.self,
            LuneSchemaV1.SDDailyCheckIn.self,
            LuneSchemaV1.SDPreferences.self,
        ]
    }

    /// `SDDailyCheckIn` exactly as MyLune 1.0 builds wrote it (before `feelingRaw`).
    @Model
    final class SDDailyCheckIn {
        @Attribute(.unique) var id: UUID
        var date: Date
        var moodRaw: Int?
        var energyRaw: Int?
        var sleepQualityRaw: Int?
        var note: String?
        var symptomsData: Data

        init(id: UUID, date: Date, symptomsData: Data) {
            self.id = id
            self.date = date
            self.symptomsData = symptomsData
        }
    }

    /// `SDPreferences` exactly as pre-release builds wrote it (before `userName`). Also used by V2.
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
        var appearanceModeRaw: String = "light"

        init() {
            id = "default"
            hasCompletedOnboarding = false
            firstDayOfWeek = 1
            notificationsEnabled = false
            periodReminderEnabled = false
            checkInReminderEnabled = false
            reminderHour = 9
            reminderMinute = 0
            biometricLockEnabled = false
        }
    }
}

/// Adds the optional `SDDailyCheckIn.feelingRaw` (Lumi's feeling check-in).
enum LuneSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            SDCycle.self,
            SDFlowEntry.self,
            SDDailyCheckIn.self,
            LuneSchemaV1.SDPreferences.self,
        ]
    }
}

/// Adds the optional `SDPreferences.userName` (what Lumi calls you).
enum LuneSchemaV3: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(3, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            SDCycle.self,
            SDFlowEntry.self,
            SDDailyCheckIn.self,
            SDPreferences.self,
        ]
    }
}

/// Register every schema version that ever reached a device here. Add lightweight/custom stages when bumping version.
enum LuneMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [LuneSchemaV1.self, LuneSchemaV2.self, LuneSchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: LuneSchemaV1.self, toVersion: LuneSchemaV2.self),
            .lightweight(fromVersion: LuneSchemaV2.self, toVersion: LuneSchemaV3.self),
        ]
    }
}

enum LuneSchema {
    static let current = LuneSchemaV3.self
    static let currentVersion = LuneSchemaV3.versionIdentifier
}
