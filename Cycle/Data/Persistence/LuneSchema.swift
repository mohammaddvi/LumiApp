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

/// Initial production schema (1.0) — cycles, flow, check-ins, preferences.
/// Models that changed later are frozen here as nested copies; never edit them.
enum LuneSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            SDCycle.self,
            SDFlowEntry.self,
            LuneSchemaV1.SDDailyCheckIn.self,
            SDPreferences.self,
        ]
    }

    /// `SDDailyCheckIn` exactly as shipped in 1.0 (before `feelingRaw`).
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
}

/// Adds the optional `SDDailyCheckIn.feelingRaw` (Lumi's feeling check-in).
enum LuneSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            SDCycle.self,
            SDFlowEntry.self,
            SDDailyCheckIn.self,
            SDPreferences.self,
        ]
    }
}

/// Register every shipped schema version here. Add lightweight/custom stages when bumping version.
enum LuneMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [LuneSchemaV1.self, LuneSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: LuneSchemaV1.self, toVersion: LuneSchemaV2.self),
        ]
    }
}

enum LuneSchema {
    static let current = LuneSchemaV2.self
    static let currentVersion = LuneSchemaV2.versionIdentifier
}
