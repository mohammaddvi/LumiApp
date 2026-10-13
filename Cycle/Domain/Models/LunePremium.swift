import Foundation

/// Lumi Premium — Ask Lumi, plus patterns and trends in Insights.
enum LunePremium {
    /// App Store Connect subscription product id.
    static let monthlyProductID = "app.lune.tracker.premium.monthly"

    static let freeTabTitles = ["Today", "Insights", "Settings"]
    static let premiumTabTitles = ["Ask"]

    static let benefits = [
        "Ask Lumi — on-device AI chat about your cycle",
        "Insights — patterns and trends from your logs",
        "Gemma model download & local inference",
    ]
}

extension UserPreferences {
    var hasPremiumAccess: Bool { false }
}
