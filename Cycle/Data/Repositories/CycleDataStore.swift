import Foundation
import SwiftData

@ModelActor
actor CycleDataStore: CycleRepositoryProtocol, FlowRepositoryProtocol, CheckInRepositoryProtocol, PreferencesRepositoryProtocol, DataMaintenanceProtocol {

    // MARK: - Cycles

    func fetchCycles() async throws -> [CycleRecord] {
        let descriptor = FetchDescriptor<SDCycle>(sortBy: [SortDescriptor(\.startDate, order: .forward)])
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    func fetchCycle(id: UUID) async throws -> CycleRecord? {
        let target = id
        let descriptor = FetchDescriptor<SDCycle>(predicate: #Predicate { $0.id == target })
        return try modelContext.fetch(descriptor).first?.toDomain()
    }

    func upsertCycle(_ cycle: CycleRecord) async throws {
        let target = cycle.id
        let descriptor = FetchDescriptor<SDCycle>(predicate: #Predicate { $0.id == target })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.startDate = cycle.startDate.startOfDay
            existing.endDate = cycle.endDate.map(\.startOfDay)
            existing.source = cycle.source
            existing.updatedAt = .now
        } else {
            modelContext.insert(
                SDCycle(
                    id: cycle.id,
                    startDate: cycle.startDate,
                    endDate: cycle.endDate,
                    source: cycle.source,
                    createdAt: cycle.createdAt,
                    updatedAt: cycle.updatedAt
                )
            )
        }
        try modelContext.save()
    }

    func deleteCycle(id: UUID) async throws {
        let target = id
        let descriptor = FetchDescriptor<SDCycle>(predicate: #Predicate { $0.id == target })
        if let existing = try modelContext.fetch(descriptor).first {
            modelContext.delete(existing)
            try modelContext.save()
        }
    }

    // MARK: - Flow

    func fetchFlowEntries(from start: Date, to end: Date) async throws -> [FlowEntryRecord] {
        let startDay = start.startOfDay
        let endDay = end.startOfDay
        let descriptor = FetchDescriptor<SDFlowEntry>(
            predicate: #Predicate { $0.date >= startDay && $0.date <= endDay },
            sortBy: [SortDescriptor(\.date)]
        )
        return try modelContext.fetch(descriptor).compactMap { $0.toDomain() }
    }

    func fetchFlowEntries(for cycleId: UUID) async throws -> [FlowEntryRecord] {
        let all = try modelContext.fetch(FetchDescriptor<SDFlowEntry>(sortBy: [SortDescriptor(\.date)]))
        return all.compactMap { entry -> FlowEntryRecord? in
            guard entry.cycle?.id == cycleId else { return nil }
            return entry.toDomain()
        }
    }

    func upsertFlowEntry(_ entry: FlowEntryRecord) async throws {
        let cycleTarget = entry.cycleId
        let cycleDescriptor = FetchDescriptor<SDCycle>(predicate: #Predicate { $0.id == cycleTarget })
        guard let cycle = try modelContext.fetch(cycleDescriptor).first else {
            throw StoreError.cycleNotFound
        }

        let entryTarget = entry.id
        let descriptor = FetchDescriptor<SDFlowEntry>(predicate: #Predicate { $0.id == entryTarget })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.date = entry.date.startOfDay
            existing.intensity = entry.intensity
            existing.spotting = entry.spotting
            existing.cycle = cycle
        } else {
            let day = entry.date.startOfDay
            let dayDescriptor = FetchDescriptor<SDFlowEntry>(predicate: #Predicate { $0.date == day })
            for old in try modelContext.fetch(dayDescriptor) {
                modelContext.delete(old)
            }
            modelContext.insert(
                SDFlowEntry(
                    id: entry.id,
                    date: entry.date,
                    intensity: entry.intensity,
                    spotting: entry.spotting,
                    cycle: cycle
                )
            )
        }
        try modelContext.save()
    }

    func deleteFlowEntry(id: UUID) async throws {
        let target = id
        let descriptor = FetchDescriptor<SDFlowEntry>(predicate: #Predicate { $0.id == target })
        if let existing = try modelContext.fetch(descriptor).first {
            modelContext.delete(existing)
            try modelContext.save()
        }
    }

    func deleteFlowEntries(on date: Date) async throws {
        let day = date.startOfDay
        let descriptor = FetchDescriptor<SDFlowEntry>(predicate: #Predicate { $0.date == day })
        for entry in try modelContext.fetch(descriptor) {
            modelContext.delete(entry)
        }
        try modelContext.save()
    }

    // MARK: - Check-ins

    func fetchCheckIns(from start: Date, to end: Date) async throws -> [DailyCheckInRecord] {
        let startDay = start.startOfDay
        let endDay = end.startOfDay
        let descriptor = FetchDescriptor<SDDailyCheckIn>(
            predicate: #Predicate { $0.date >= startDay && $0.date <= endDay },
            sortBy: [SortDescriptor(\.date)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDomain() }
    }

    func fetchCheckIn(on date: Date) async throws -> DailyCheckInRecord? {
        let day = date.startOfDay
        let descriptor = FetchDescriptor<SDDailyCheckIn>(predicate: #Predicate { $0.date == day })
        return try modelContext.fetch(descriptor).first?.toDomain()
    }

    func upsertCheckIn(_ checkIn: DailyCheckInRecord) async throws {
        let day = checkIn.date.startOfDay
        let descriptor = FetchDescriptor<SDDailyCheckIn>(predicate: #Predicate { $0.date == day })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.mood = checkIn.mood
            existing.energy = checkIn.energy
            existing.sleepQuality = checkIn.sleepQuality
            existing.symptoms = checkIn.symptoms
            existing.note = checkIn.note
            existing.feeling = checkIn.feeling
        } else {
            modelContext.insert(
                SDDailyCheckIn(
                    id: checkIn.id,
                    date: checkIn.date,
                    mood: checkIn.mood,
                    energy: checkIn.energy,
                    sleepQuality: checkIn.sleepQuality,
                    symptoms: checkIn.symptoms,
                    note: checkIn.note,
                    feeling: checkIn.feeling
                )
            )
        }
        try modelContext.save()
    }

    func deleteCheckIn(id: UUID) async throws {
        let target = id
        let descriptor = FetchDescriptor<SDDailyCheckIn>(predicate: #Predicate { $0.id == target })
        if let existing = try modelContext.fetch(descriptor).first {
            modelContext.delete(existing)
            try modelContext.save()
        }
    }

    // MARK: - Preferences

    func load() async throws -> UserPreferences {
        let descriptor = FetchDescriptor<SDPreferences>(predicate: #Predicate { $0.id == "default" })
        if let existing = try modelContext.fetch(descriptor).first {
            return existing.toDomain()
        }
        let prefs = SDPreferences()
        modelContext.insert(prefs)
        try modelContext.save()
        return prefs.toDomain()
    }

    func save(_ preferences: UserPreferences) async throws {
        let descriptor = FetchDescriptor<SDPreferences>(predicate: #Predicate { $0.id == "default" })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(preferences)
        } else {
            modelContext.insert(SDPreferences(from: preferences))
        }
        try modelContext.save()
    }

    // MARK: - Maintenance

    /// Deletes every record one by one. (SwiftData's batch delete fails on the required
    /// flow → cycle link and left periods behind, so it isn't used here.) Flow days go first.
    func deleteAllHealthData() async throws {
        for entry in try modelContext.fetch(FetchDescriptor<SDFlowEntry>()) {
            modelContext.delete(entry)
        }
        for checkIn in try modelContext.fetch(FetchDescriptor<SDDailyCheckIn>()) {
            modelContext.delete(checkIn)
        }
        for cycle in try modelContext.fetch(FetchDescriptor<SDCycle>()) {
            modelContext.delete(cycle)
        }
        for preferences in try modelContext.fetch(FetchDescriptor<SDPreferences>()) {
            modelContext.delete(preferences)
        }
        modelContext.insert(SDPreferences())
        try modelContext.save()
    }

    func exportSnapshot() async throws -> HealthExportSnapshot {
        let cycles = try await fetchCycles()
        let flows = try modelContext.fetch(FetchDescriptor<SDFlowEntry>()).compactMap { $0.toDomain() }
        let checkIns = try modelContext.fetch(FetchDescriptor<SDDailyCheckIn>()).map { $0.toDomain() }
        let prefs = try await load()

        return HealthExportSnapshot(
            exportedAt: .now,
            appVersion: AppInfo.marketingVersion,
            cycles: cycles.map {
                ExportCycle(id: $0.id, startDate: $0.startDate, endDate: $0.endDate, source: $0.source.rawValue)
            },
            flowEntries: flows.map {
                ExportFlow(id: $0.id, date: $0.date, intensity: $0.intensity.rawValue, spotting: $0.spotting, cycleId: $0.cycleId)
            },
            checkIns: checkIns.map {
                ExportCheckIn(
                    id: $0.id,
                    date: $0.date,
                    mood: $0.mood?.rawValue,
                    energy: $0.energy?.rawValue,
                    sleepQuality: $0.sleepQuality?.rawValue,
                    symptoms: $0.symptoms.map { ExportSymptom(type: $0.symptomType.rawValue, intensity: $0.intensity.rawValue) },
                    note: $0.note,
                    feeling: $0.feeling?.rawValue
                )
            },
            preferences: ExportPreferences(
                typicalCycleLength: prefs.typicalCycleLength,
                notificationsEnabled: prefs.notificationsEnabled
            )
        )
    }
}

enum StoreError: LocalizedError {
    case cycleNotFound

    var errorDescription: String? {
        switch self {
        case .cycleNotFound: "Cycle not found for this flow entry."
        }
    }
}
