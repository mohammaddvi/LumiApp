import Foundation
import Testing
@testable import Cycle

@MainActor
@Suite("Mark period day")
struct MarkPeriodDayTests {
    @Test("A day two days before a period joins it and becomes its start")
    func joinsNearbyPeriod() async throws {
        let env = AppEnvironment.preview()
        let today = Date().startOfDay
        #expect(await env.logPeriodRange(from: today.addingDays(-5), to: today.addingDays(-3)) == nil)

        let message = await env.markPeriodDay(on: today.addingDays(-7), intensity: .heavy)
        #expect(message == nil)
        #expect(env.flow(on: today.addingDays(-7))?.intensity == .heavy)
        #expect(env.cycles.last?.startDate.startOfDay == today.addingDays(-7))
    }

    @Test("A day far from any period starts a new one, and flow can be edited")
    func startsNewPeriodAndEdits() async throws {
        let env = AppEnvironment.preview()
        let today = Date().startOfDay
        #expect(await env.logPeriodRange(from: today.addingDays(-40), to: today.addingDays(-36)) == nil)

        #expect(await env.markPeriodDay(on: today.addingDays(-10)) == nil)
        #expect(env.cycles.count == 2)
        await env.setFlowIntensity(.light, on: today.addingDays(-10))
        #expect(env.flow(on: today.addingDays(-10))?.intensity == .light)

        await env.clearFlow(on: today.addingDays(-10))
        #expect(env.flow(on: today.addingDays(-10)) == nil)
        #expect(env.cycles.count == 1)
    }
}
