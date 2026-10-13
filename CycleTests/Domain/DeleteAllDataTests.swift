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

@MainActor
@Suite("Removed Messages feature")
struct RemovedMessagesFeatureTests {
    @Test("Saved phone numbers from the removed feature are cleared on launch")
    func clearsLegacyContacts() async {
        let env = AppEnvironment.preview()
        var prefs = env.preferences
        prefs.iMessageContacts = [MessageContact(label: "Sam", phoneNumber: "+31612345678")]
        prefs.iMessageRemindersEnabled = true
        await env.updatePreferences(prefs)

        await env.bootstrap()

        #expect(env.preferences.iMessageContacts.isEmpty)
        #expect(env.preferences.iMessageRemindersEnabled == false)
        #expect(try! await env.store.load().iMessageContacts.isEmpty)
    }
}
