import Foundation
import SwiftData

/// Stable on-disk layout for Lune's SwiftData store.
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

/// Initial production schema — cycles, flow, check-ins, preferences.
enum LuneSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

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
        [LuneSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

enum LuneSchema {
    static let current = LuneSchemaV1.self
    static let currentVersion = LuneSchemaV1.versionIdentifier
}
