import Foundation

/// The real moon in the sky tonight (not the cycle phase; see `LunePhase`).
/// Uses the mean lunar month, so it can be off by up to about half a day: fine for a picture.
enum MoonPhase: Int, CaseIterable, Sendable {
    case new
    case waxingCrescent
    case firstQuarter
    case waxingGibbous
    case full
    case waningGibbous
    case lastQuarter
    case waningCrescent

    /// Average days from one new moon to the next.
    static let synodicMonth = 29.530588853
    /// A known new moon: 6 January 2000, 18:14 UTC.
    static let referenceNewMoon = Date(timeIntervalSince1970: 947_182_440)

    /// Days since the last new moon, 0 ..< `synodicMonth`.
    static func age(on date: Date) -> Double {
        let days = date.timeIntervalSince(referenceNewMoon) / 86_400
        let age = days.truncatingRemainder(dividingBy: synodicMonth)
        return age < 0 ? age + synodicMonth : age
    }

    /// The phase nearest to `date`, each one centered on its exact moment.
    static func on(_ date: Date) -> MoonPhase {
        let eighth = (age(on: date) / synodicMonth * 8).rounded()
        return MoonPhase(rawValue: Int(eighth) % 8) ?? .new
    }

    var name: String {
        switch self {
        case .new: "New moon"
        case .waxingCrescent: "Waxing crescent"
        case .firstQuarter: "First quarter"
        case .waxingGibbous: "Waxing gibbous"
        case .full: "Full moon"
        case .waningGibbous: "Waning gibbous"
        case .lastQuarter: "Last quarter"
        case .waningCrescent: "Waning crescent"
        }
    }

    var sfSymbolName: String {
        switch self {
        case .new: "moonphase.new.moon"
        case .waxingCrescent: "moonphase.waxing.crescent"
        case .firstQuarter: "moonphase.first.quarter"
        case .waxingGibbous: "moonphase.waxing.gibbous"
        case .full: "moonphase.full.moon"
        case .waningGibbous: "moonphase.waning.gibbous"
        case .lastQuarter: "moonphase.last.quarter"
        case .waningCrescent: "moonphase.waning.crescent"
        }
    }
}
