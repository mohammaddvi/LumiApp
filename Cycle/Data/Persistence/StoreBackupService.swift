import Foundation

/// Copies the SwiftData store before risky operations so updates can recover from a bad migration.
enum StoreBackupService {
    static let maxBackups = 5

    /// Creates a timestamped backup when a store already exists.
    static func backupExistingStoreIfNeeded() throws {
        let storeURL = LuneStoreLocation.storeURL
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }

        let attributes = try FileManager.default.attributesOfItem(atPath: storeURL.path)
        let byteCount = attributes[.size] as? Int64 ?? 0
        guard byteCount > 0 else { return }

        try FileManager.default.createDirectory(
            at: LuneStoreLocation.backupsDirectory,
            withIntermediateDirectories: true
        )

        let stamp = backupTimestamp()
        let backupBase = LuneStoreLocation.backupsDirectory
            .appending(path: "cycle-\(stamp)", directoryHint: .isDirectory)

        try FileManager.default.createDirectory(at: backupBase, withIntermediateDirectories: true)

        for source in LuneStoreLocation.relatedStoreFiles(for: storeURL) {
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            let destination = backupBase.appending(path: source.lastPathComponent)
            try FileManager.default.copyItem(at: source, to: destination)
        }

        try pruneOldBackups()
    }

    static var latestBackupDirectory: URL? {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: LuneStoreLocation.backupsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        return entries
            .filter { $0.hasDirectoryPath && $0.lastPathComponent.hasPrefix("cycle-") }
            .sorted {
                let lhs = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhs = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhs > rhs
            }
            .first
    }

    /// Removes every automatic backup (used by "Delete all data", so no copy of the old logs remains).
    static func deleteAllBackups() throws {
        let directory = LuneStoreLocation.backupsDirectory
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.removeItem(at: directory)
    }

    static func hasAnyBackup() -> Bool {
        latestBackupDirectory != nil
    }

    /// Restores the most recent backup over the live store (e.g. after a failed migration).
    @discardableResult
    static func restoreLatestBackup() throws -> Bool {
        guard let backupDir = latestBackupDirectory else { return false }
        let storeURL = LuneStoreLocation.storeURL

        for live in LuneStoreLocation.relatedStoreFiles(for: storeURL) {
            if FileManager.default.fileExists(atPath: live.path) {
                try FileManager.default.removeItem(at: live)
            }
        }

        for name in ["cycle.store", "cycle.store-wal", "cycle.store-shm", "cycle.store.wal", "cycle.store.shm"] {
            let source = backupDir.appending(path: name)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            let destination = storeURL.deletingLastPathComponent().appending(path: name)
            try FileManager.default.copyItem(at: source, to: destination)
        }

        return FileManager.default.fileExists(atPath: storeURL.path)
    }

    private static func pruneOldBackups() throws {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: LuneStoreLocation.backupsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let sorted = entries
            .filter { $0.hasDirectoryPath && $0.lastPathComponent.hasPrefix("cycle-") }
            .sorted {
                let lhs = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhs = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhs > rhs
            }

        if sorted.count <= maxBackups { return }

        for url in sorted.dropFirst(maxBackups) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func backupTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: .now)
    }
}
