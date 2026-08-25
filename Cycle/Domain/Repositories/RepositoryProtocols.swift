import Foundation

protocol CycleRepositoryProtocol: Sendable {
    func fetchCycles() async throws -> [CycleRecord]
    func fetchCycle(id: UUID) async throws -> CycleRecord?
    func upsertCycle(_ cycle: CycleRecord) async throws
    func deleteCycle(id: UUID) async throws
}

protocol FlowRepositoryProtocol: Sendable {
    func fetchFlowEntries(from start: Date, to end: Date) async throws -> [FlowEntryRecord]
    func fetchFlowEntries(for cycleId: UUID) async throws -> [FlowEntryRecord]
    func upsertFlowEntry(_ entry: FlowEntryRecord) async throws
    func deleteFlowEntry(id: UUID) async throws
    func deleteFlowEntries(on date: Date) async throws
}

protocol CheckInRepositoryProtocol: Sendable {
    func fetchCheckIns(from start: Date, to end: Date) async throws -> [DailyCheckInRecord]
    func fetchCheckIn(on date: Date) async throws -> DailyCheckInRecord?
    func upsertCheckIn(_ checkIn: DailyCheckInRecord) async throws
    func deleteCheckIn(id: UUID) async throws
}

protocol PreferencesRepositoryProtocol: Sendable {
    func load() async throws -> UserPreferences
    func save(_ preferences: UserPreferences) async throws
}

protocol DataMaintenanceProtocol: Sendable {
    func deleteAllHealthData() async throws
    func exportSnapshot() async throws -> HealthExportSnapshot
}

struct HealthExportSnapshot: Codable, Sendable {
    var exportedAt: Date
    var appVersion: String
    var cycles: [ExportCycle]
    var flowEntries: [ExportFlow]
    var checkIns: [ExportCheckIn]
    var preferences: ExportPreferences
}

struct ExportCycle: Codable, Sendable {
    var id: UUID
    var startDate: Date
    var endDate: Date?
    var source: String
}

struct ExportFlow: Codable, Sendable {
    var id: UUID
    var date: Date
    var intensity: String
    var spotting: Bool
    var cycleId: UUID
}

struct ExportCheckIn: Codable, Sendable {
    var id: UUID
    var date: Date
    var mood: Int?
    var energy: Int?
    var sleepQuality: Int?
    var symptoms: [ExportSymptom]
    var note: String?
}

struct ExportSymptom: Codable, Sendable {
    var type: String
    var intensity: Int
}

struct ExportPreferences: Codable, Sendable {
    var typicalCycleLength: Int?
    var notificationsEnabled: Bool
}
