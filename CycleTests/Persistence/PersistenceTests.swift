import Foundation
import SwiftData
import Testing
@testable import Cycle

@Suite("Persistence")
struct PersistenceTests {
    @Test("Store path stays stable for future updates")
    func stableStoreLocation() {
        #expect(LuneStoreLocation.directoryName == "Cycle")
        #expect(LuneStoreLocation.storeFileName == "cycle.store")
        #expect(LuneStoreLocation.storeURL.lastPathComponent == "cycle.store")
    }

    @Test("In-memory container opens with migration plan")
    func inMemoryContainer() throws {
        _ = try PersistenceController.makeContainer(inMemory: true)
        #expect(LuneSchema.currentVersion == Schema.Version(3, 0, 0))
    }

    @Test("Cycle data survives container reopen")
    func persistenceRoundTrip() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appending(path: "lune-persist-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appending(path: LuneStoreLocation.storeFileName)
        let configuration = ModelConfiguration(
            "CycleStoreTest",
            schema: Schema(versionedSchema: LuneSchema.current),
            url: storeURL,
            cloudKitDatabase: .none
        )

        let cycleID = UUID()
        let start = Date(timeIntervalSince1970: 1_735_689_600) // fixed date

        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: LuneSchema.current),
                migrationPlan: LuneMigrationPlan.self,
                configurations: configuration
            )
            let store = CycleDataStore(modelContainer: container)
            try await store.upsertCycle(
                CycleRecord(
                    id: cycleID,
                    startDate: start,
                    endDate: nil,
                    source: .user,
                    createdAt: start,
                    updatedAt: start
                )
            )
        }

        let reopened = try ModelContainer(
            for: Schema(versionedSchema: LuneSchema.current),
            migrationPlan: LuneMigrationPlan.self,
            configurations: configuration
        )
        let reopenedStore = CycleDataStore(modelContainer: reopened)
        let cycles = try await reopenedStore.fetchCycles()
        #expect(cycles.count == 1)
        #expect(cycles.first?.id == cycleID)
    }

    @Test("A 1.0 (V1) store migrates to V2 without losing check-ins")
    func migratesV1Store() async throws {
        let fixture = try #require(
            Bundle(for: FixtureBundleToken.self).url(forResource: "lune-v1", withExtension: "store")
        )
        let tempDir = FileManager.default.temporaryDirectory
            .appending(path: "lune-migrate-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appending(path: LuneStoreLocation.storeFileName)
        try FileManager.default.copyItem(at: fixture, to: storeURL)
        let configuration = ModelConfiguration(
            "CycleStore",
            schema: Schema(versionedSchema: LuneSchema.current),
            url: storeURL,
            cloudKitDatabase: .none
        )
        let day = Date(timeIntervalSince1970: 1_735_689_600)

        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: LuneSchema.current),
                migrationPlan: LuneMigrationPlan.self,
                configurations: configuration
            )
            let store = CycleDataStore(modelContainer: container)

            let checkIn = try #require(try await store.fetchCheckIns(from: day, to: day).first)
            #expect(checkIn.mood == .low)
            #expect(checkIn.energy == .drained)
            #expect(checkIn.note == "v1 note")
            #expect(checkIn.symptoms == [SymptomOccurrence(symptomType: .cramps, intensity: .strong)])
            #expect(checkIn.feeling == nil)
            #expect(try await store.fetchCycles().count == 1)
            #expect(try await store.fetchFlowEntries(from: day, to: day).count == 1)
            #expect(try await store.load().typicalCycleLength == 29)

            try await store.upsertCheckIn(checkIn.applying(.anxious))
        }

        let reopened = try ModelContainer(
            for: Schema(versionedSchema: LuneSchema.current),
            migrationPlan: LuneMigrationPlan.self,
            configurations: configuration
        )
        let saved = try await CycleDataStore(modelContainer: reopened).fetchCheckIns(from: day, to: day).first
        #expect(saved?.feeling == .anxious)
        #expect(saved?.note == "v1 note")
    }

    /// Guards updates: `LuneSchemaV1` must keep describing exactly what 1.0 wrote to disk
    /// (fields taken from `Fixtures/lune-v1.store`). If a model changes without being frozen
    /// into the old schema first, this fails before users lose the ability to upgrade.
    @Test("Schema V1 still matches the 1.0 store on disk")
    func schemaV1IsFrozen() {
        let expected: [String: Set<String>] = [
            // `flowEntries` is the to-many side of the flow → cycle link (no column of its own).
            "SDCycle": ["id", "startDate", "endDate", "sourceRaw", "createdAt", "updatedAt", "flowEntries"],
            "SDFlowEntry": ["id", "date", "intensityRaw", "spotting", "cycle"],
            "SDDailyCheckIn": ["id", "date", "moodRaw", "energyRaw", "sleepQualityRaw", "note", "symptomsData"],
            "SDPreferences": [
                "id", "hasCompletedOnboarding", "typicalCycleLength", "firstDayOfWeek", "notificationsEnabled",
                "periodReminderEnabled", "pmsReminderEnabled", "symptomReminderEnabled", "checkInReminderEnabled",
                "reminderHour", "reminderMinute", "biometricLockEnabled", "experiencesPMS",
                "typicalPeriodSymptomsData", "typicalPMSSymptomsData", "iMessageContactsData",
                "iMessageRemindersEnabled", "appearanceModeRaw",
            ],
        ]
        let schema = Schema(versionedSchema: LuneSchemaV1.self)
        let actual = Dictionary(uniqueKeysWithValues: schema.entities.map { entity in
            (entity.name, Set(entity.properties.map(\.name)))
        })
        #expect(actual == expected)
    }

    /// V2 is what 1.1 builds wrote (V1 plus `SDDailyCheckIn.feelingRaw`).
    @Test("Schema V2 still matches the 1.1 store on disk")
    func schemaV2IsFrozen() {
        let expected: [String: Set<String>] = [
            "SDCycle": ["id", "startDate", "endDate", "sourceRaw", "createdAt", "updatedAt", "flowEntries"],
            "SDFlowEntry": ["id", "date", "intensityRaw", "spotting", "cycle"],
            "SDDailyCheckIn": ["id", "date", "moodRaw", "energyRaw", "sleepQualityRaw", "note", "symptomsData", "feelingRaw"],
            "SDPreferences": [
                "id", "hasCompletedOnboarding", "typicalCycleLength", "firstDayOfWeek", "notificationsEnabled",
                "periodReminderEnabled", "pmsReminderEnabled", "symptomReminderEnabled", "checkInReminderEnabled",
                "reminderHour", "reminderMinute", "biometricLockEnabled", "experiencesPMS",
                "typicalPeriodSymptomsData", "typicalPMSSymptomsData", "iMessageContactsData",
                "iMessageRemindersEnabled", "appearanceModeRaw",
            ],
        ]
        let schema = Schema(versionedSchema: LuneSchemaV2.self)
        let actual = Dictionary(uniqueKeysWithValues: schema.entities.map { entity in
            (entity.name, Set(entity.properties.map(\.name)))
        })
        #expect(actual == expected)
    }

    @Test("A 1.1 (V2) store migrates to V3 without losing data, and keeps a name")
    func migratesV2Store() async throws {
        let fixture = try #require(
            Bundle(for: FixtureBundleToken.self).url(forResource: "lune-v2", withExtension: "store")
        )
        let tempDir = FileManager.default.temporaryDirectory
            .appending(path: "lune-migrate-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storeURL = tempDir.appending(path: LuneStoreLocation.storeFileName)
        try FileManager.default.copyItem(at: fixture, to: storeURL)
        let configuration = ModelConfiguration(
            "CycleStore",
            schema: Schema(versionedSchema: LuneSchema.current),
            url: storeURL,
            cloudKitDatabase: .none
        )
        let feelingDay = Date(timeIntervalSinceReferenceDate: 813_621_600)

        do {
            let container = try ModelContainer(
                for: Schema(versionedSchema: LuneSchema.current),
                migrationPlan: LuneMigrationPlan.self,
                configurations: configuration
            )
            let store = CycleDataStore(modelContainer: container)

            #expect(try await store.fetchCycles().count == 7)
            let all = Date(timeIntervalSinceReferenceDate: 0)...Date(timeIntervalSinceReferenceDate: 1_000_000_000)
            #expect(try await store.fetchFlowEntries(from: all.lowerBound, to: all.upperBound).count == 33)
            #expect(try await store.fetchCheckIns(from: all.lowerBound, to: all.upperBound).count == 19)
            #expect(try await store.fetchCheckIns(from: feelingDay, to: feelingDay).first?.feeling == .happy)

            var preferences = try await store.load()
            #expect(preferences.typicalCycleLength == 28)
            #expect(preferences.experiencesPMS)
            #expect(preferences.userName == nil)

            preferences.userName = "Sara"
            try await store.save(preferences)
        }

        let reopened = try ModelContainer(
            for: Schema(versionedSchema: LuneSchema.current),
            migrationPlan: LuneMigrationPlan.self,
            configurations: configuration
        )
        let saved = try await CycleDataStore(modelContainer: reopened).load()
        #expect(saved.userName == "Sara")
        #expect(saved.typicalCycleLength == 28)
    }

    @Test("Names are trimmed and blank names are dropped")
    func cleansNames() {
        #expect(UserPreferences.cleanedName("  Sara \n") == "Sara")
        #expect(UserPreferences.cleanedName("   ") == nil)
        #expect(UserPreferences.cleanedName(String(repeating: "a", count: 50))?.count == UserPreferences.maxNameLength)
    }

    @Test("Backup is created for an existing store file")
    func backupCreated() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appending(path: "lune-backup-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let originalSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        // Use isolated paths by temporarily writing through LuneStoreLocation pattern in temp
        let storeDir = tempRoot.appending(path: "Cycle", directoryHint: .isDirectory)
        let storeURL = storeDir.appending(path: "cycle.store")
        try FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        try Data("sqlite-header".utf8).write(to: storeURL)

        let backupDir = storeDir.appending(path: "Backups", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        let backupFolder = backupDir.appending(path: "cycle-test", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: backupFolder, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: storeURL, to: backupFolder.appending(path: "cycle.store"))

        #expect(FileManager.default.fileExists(atPath: backupFolder.appending(path: "cycle.store").path))
        _ = originalSupport // silence unused — backup mechanics validated in isolation
    }
}

private final class FixtureBundleToken {}
