import Foundation

/// MyLune Premium — Ask MyLune + Insights.
enum LunePremium {
    /// App Store Connect subscription product id.
    static let monthlyProductID = "app.lune.tracker.premium.monthly"

    static let freeTabTitles = ["Today", "Calendar", "Settings"]
    static let premiumTabTitles = ["Ask", "Insights"]

    static let benefits = [
        "Ask Lumi — on-device AI chat about your cycle",
        "Insights — pattern spotting from your logs",
        "Gemma model download & local inference",
    ]
}

extension UserPreferences {
    var hasPremiumAccess: Bool { false }
}
