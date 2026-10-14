import Foundation

/// A situation Lumi greets you about on Today (at most once a day). Her lines live in `LuneVoice.lumiSays`.
enum LumiMoment: String, CaseIterable, Sendable {
    /// First visit ever.
    case welcome
    /// Back after a few days away.
    case welcomeBack
    /// A logged period starts today.
    case periodStarted
    /// Day 2–4 of a logged period.
    case periodDay
    /// Day 5+ of a logged period: nearly done.
    case periodEnding
    /// The predicted period start is today, nothing logged yet.
    case periodToday
    case periodTomorrow
    /// A few days past the predicted start with no new period logged.
    case periodLate
    /// The few days before a period (PMS days for people who get PMS).
    case pmsDays
    case fertileStart
    case fertileDays
    case ovulation
    /// Energy building after a period (and the glow days after ovulation).
    case bloom
    /// The slower days in the second half of the cycle.
    case slow
    case lateNight
}

/// What Lumi knows about today when picking a greeting.
struct LumiMomentInput: Equatable, Sendable {
    var hour: Int
    /// Whole days since the last visit; `nil` on the very first visit.
    var daysSinceLastVisit: Int?
    /// 1-based day of a logged period that includes today; `nil` when today isn't a period day.
    var periodDay: Int?
    /// Days until the predicted period start; negative when it's late. `nil` without a prediction.
    var daysUntilPredictedPeriod: Int?
    var dayState: CycleDayState?
    var fertileStartsToday: Bool = false
}

enum LumiMomentEngine {
    static let welcomeBackAfterDays = 4
    static let lateAfterDays = 3

    /// Picks the most relevant moment: period news first, then visits, then where you are in the cycle.
    static func moment(for input: LumiMomentInput) -> LumiMoment? {
        if input.daysSinceLastVisit == nil { return .welcome }
        if input.periodDay == 1 { return .periodStarted }
        if input.periodDay == nil {
            switch input.daysUntilPredictedPeriod {
            case 0: return .periodToday
            case 1: return .periodTomorrow
            case .some(let days) where days <= -lateAfterDays: return .periodLate
            default: break
            }
        }
        if let away = input.daysSinceLastVisit, away >= welcomeBackAfterDays { return .welcomeBack }
        if let day = input.periodDay { return day >= 5 ? .periodEnding : .periodDay }
        if let state = input.dayState {
            if state.isOvulationDay { return .ovulation }
            if input.fertileStartsToday { return .fertileStart }
            if state.isFertile { return .fertileDays }
            if state.isPrePeriod { return .pmsDays }
        }
        if input.hour >= 23 || input.hour < 5 { return .lateNight }
        switch input.dayState?.phase {
        case .bloom, .glow: return .bloom
        case .slow: return .slow
        case .reset, nil: return nil
        }
    }
}
