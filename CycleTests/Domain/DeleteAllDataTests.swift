import Foundation
import Testing
@testable import Cycle

@MainActor
@Suite("Delete all data")
struct DeleteAllDataTests {
    @Test("Delete all data really removes periods, check-ins and feelings")
    func deletesEverything() async throws {
        let env = AppEnvironment.preview()
        let today = Date().startOfDay
        #expect(await env.logPeriodRange(from: today.addingDays(-30), to: today.addingDays(-26)) == nil)
        #expect(await env.logPeriodRange(from: today.addingDays(-3), to: today.addingDays(-1)) == nil)
        await env.logFeeling(.calm)
        #expect(env.cycles.count == 2)

        await env.deleteAllData()
        await env.refresh()

        #expect(env.lastErrorMessage == nil)
        #expect(env.cycles.isEmpty)
        #expect(env.recentFlows.isEmpty)
        #expect(env.recentCheckIns.isEmpty)
        #expect(env.todayFeeling == nil)
        #expect(!StoreBackupService.hasAnyBackup())
    }
}
