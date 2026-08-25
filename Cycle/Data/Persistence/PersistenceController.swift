import Foundation
import SwiftData

enum PersistenceFailure: Error, Equatable {
    case openFailed(message: String, backupAvailable: Bool)

    var userMessage: String {
        switch self {
        case .openFailed(let message, _):
            message
        }
    }
}

enum PersistenceController {
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        if inMemory {
            let configuration = ModelConfiguration(
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            return try openContainer(configuration: configuration)
        }

        try FileManager.default.createDirectory(
            at: LuneStoreLocation.storeDirectory,
            withIntermediateDirectories: true
        )

        try StoreBackupService.backupExistingStoreIfNeeded()

        let configuration = ModelConfiguration(
            "CycleStore",
            schema: Schema(versionedSchema: LuneSchema.current),
            url: LuneStoreLocation.storeURL,
            cloudKitDatabase: .none
        )

        do {
            let container = try openContainer(configuration: configuration)
            try applyFileProtection(to: LuneStoreLocation.storeURL)
            return container
        } catch {
            if try StoreBackupService.restoreLatestBackup() {
                do {
                    let container = try openContainer(configuration: configuration)
                    try applyFileProtection(to: LuneStoreLocation.storeURL)
                    return container
                } catch {
                    throw PersistenceFailure.openFailed(
                        message: friendlyOpenError(error),
                        backupAvailable: StoreBackupService.hasAnyBackup()
                    )
                }
            }
            throw PersistenceFailure.openFailed(
                message: friendlyOpenError(error),
                backupAvailable: StoreBackupService.hasAnyBackup()
            )
        }
    }

    private static func openContainer(configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: LuneSchema.current),
            migrationPlan: LuneMigrationPlan.self,
            configurations: configuration
        )
    }

    /// Platform data protection — encrypts store at rest; path survives app updates.
    private static func applyFileProtection(to storeURL: URL) throws {
        for fileURL in LuneStoreLocation.relatedStoreFiles(for: storeURL) {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: fileURL.path
            )
        }
    }

    private static func friendlyOpenError(_ error: Error) -> String {
        if let failure = error as? PersistenceFailure {
            return failure.userMessage
        }
        return "Lune couldn’t open your local cycle database. Your last automatic backup is kept on this device."
    }
}
