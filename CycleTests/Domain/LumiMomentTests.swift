import Foundation
import Testing
@testable import Cycle

@Suite("Lumi moments")
struct LumiMomentTests {
    private func input(
        hour: Int = 12,
        away: Int? = 1,
        periodDay: Int? = nil,
        untilPeriod: Int? = 14,
        state: CycleDayState? = CycleDayState(cycleDay: 10, phase: .bloom, isPrePeriod: false),
        fertileStart: Bool = false
    ) -> LumiMomentInput {
        LumiMomentInput(
            hour: hour,
            daysSinceLastVisit: away,
            periodDay: periodDay,
            daysUntilPredictedPeriod: untilPeriod,
            dayState: state,
            fertileStartsToday: fertileStart
        )
    }

    @Test("First visit is a welcome; period day one beats coming back")
    func priorities() {
        #expect(LumiMomentEngine.moment(for: input(away: nil, periodDay: 1)) == .welcome)
        #expect(LumiMomentEngine.moment(for: input(away: 10, periodDay: 1)) == .periodStarted)
        #expect(LumiMomentEngine.moment(for: input(away: 10, periodDay: 3)) == .welcomeBack)
        #expect(LumiMomentEngine.moment(for: input(periodDay: 3)) == .periodDay)
        #expect(LumiMomentEngine.moment(for: input(periodDay: 5)) == .periodEnding)
    }

    @Test("Predicted period: today, tomorrow and late")
    func predictedPeriod() {
        #expect(LumiMomentEngine.moment(for: input(untilPeriod: 0)) == .periodToday)
        #expect(LumiMomentEngine.moment(for: input(untilPeriod: 1)) == .periodTomorrow)
        #expect(LumiMomentEngine.moment(for: input(untilPeriod: -2)) == .bloom)
        #expect(LumiMomentEngine.moment(for: input(untilPeriod: -3)) == .periodLate)
        // Once the period is logged it's no longer late.
        #expect(LumiMomentEngine.moment(for: input(periodDay: 2, untilPeriod: -3)) == .periodDay)
    }

    @Test("Cycle phases: ovulation, fertile days, PMS, bloom, slow")
    func phases() {
        let ovulation = CycleDayState(cycleDay: 14, phase: .glow, isPrePeriod: false, isFertile: true, isOvulationDay: true)
        let fertile = CycleDayState(cycleDay: 11, phase: .glow, isPrePeriod: false, isFertile: true)
        let pms = CycleDayState(cycleDay: 25, phase: .slow, isPrePeriod: true)
        let slow = CycleDayState(cycleDay: 20, phase: .slow, isPrePeriod: false)

        #expect(LumiMomentEngine.moment(for: input(state: ovulation)) == .ovulation)
        #expect(LumiMomentEngine.moment(for: input(state: fertile, fertileStart: true)) == .fertileStart)
        #expect(LumiMomentEngine.moment(for: input(state: fertile)) == .fertileDays)
        #expect(LumiMomentEngine.moment(for: input(state: pms)) == .pmsDays)
        #expect(LumiMomentEngine.moment(for: input(state: slow)) == .slow)
        #expect(LumiMomentEngine.moment(for: input()) == .bloom)
        #expect(LumiMomentEngine.moment(for: input(hour: 23, state: slow)) == .lateNight)
        #expect(LumiMomentEngine.moment(for: input(state: nil)) == nil)
    }

    @Test("Every line reads well with and without a name")
    func lines() {
        for moment in LumiMoment.allCases {
            let plain = LuneVoice.lumiSays(moment, experiencesPMS: true)
            let named = LuneVoice.lumiSays(moment, name: "Sara", experiencesPMS: true)
            #expect(!plain.contains("Sara") && !plain.contains(" ,") && !plain.contains(",,"))
            #expect(named.contains(", Sara"))
        }
        #expect(LuneVoice.lumiSays(.periodStarted, name: "Sara", experiencesPMS: false) == "Day one, Sara. Cozy socks, warm tea and extra rest 🍵")
        #expect(LuneVoice.greeting(hour: 9, name: "Sara") == "Good morning, Sara")
        #expect(LuneVoice.greeting(hour: 9) == "Good morning")
    }
}
