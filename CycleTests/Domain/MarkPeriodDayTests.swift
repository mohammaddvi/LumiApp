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

    @Test("Editing a real period moves the next period, ovulation and fertile days")
    func editsMovePredictions() async throws {
        let env = AppEnvironment.preview()
        let today = Date().startOfDay
        #expect(await env.logPeriodRange(from: today.addingDays(-5), to: today.addingDays(-3)) == nil)
        let next = try #require(env.prediction?.predictedDate).startOfDay
        let ovulation = try #require(env.prediction?.predictedOvulationDate).startOfDay
        #expect(env.cycleOutlook?.cycles.first?.periodStart == next)

        // Period actually started two days earlier.
        #expect(await env.markPeriodDay(on: today.addingDays(-7)) == nil)
        #expect(env.prediction?.predictedDate?.startOfDay == next.addingDays(-2))
        #expect(env.prediction?.predictedOvulationDate?.startOfDay == ovulation.addingDays(-2))
        #expect(env.cycleOutlook?.cycles.first?.periodStart == next.addingDays(-2))
        #expect(env.predictedFertileWindow?.lowerBound == ovulation.addingDays(-7))

        // Removing that day again puts the start, and everything predicted from it, back.
        await env.clearFlow(on: today.addingDays(-7))
        #expect(env.prediction?.predictedDate?.startOfDay == next)
        #expect(env.prediction?.predictedOvulationDate?.startOfDay == ovulation)

        // A newer period resets the prediction from its start.
        #expect(await env.logPeriodRange(from: today.addingDays(-1), to: today) == nil)
        #expect(env.prediction?.predictedDate?.startOfDay == today.addingDays(-1 + 28))
        #expect(env.isEstimatedOvulationDay(today.addingDays(-1 + 14)))
        #expect(env.isEstimatedFertileDay(today.addingDays(-1 + 10)))
    }
}
