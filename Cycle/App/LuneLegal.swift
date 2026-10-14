import Foundation

/// Legal copy and App Store URLs. Privacy/Support pages on GitHub Pages (`docs/` → `main`); marketing URL is the public repo.
enum LuneLegal {
    static let appName = "Lumi"
    static let supportEmail = "support@mylune.app"
    /// Public URL for App Store Connect “Privacy Policy URL”.
    static let privacyPolicyURL = URL(string: "https://mohammaddvi.github.io/LumiApp/privacy.html")!
    /// Public URL for App Store Connect “Support URL”.
    static let supportURL = URL(string: "https://mohammaddvi.github.io/LumiApp/support.html")!
    /// Marketing URL (App Store Connect) — public GitHub repository.
    static let marketingURL = URL(string: "https://github.com/mohammaddvi/LumiApp")!
    static let lastUpdated = "October 14, 2026"

    static let medicalDisclaimer = """
    Lumi helps you notice patterns in your own cycle. It is not a medical device and does not diagnose, treat, or prevent any condition. Talk to a clinician for medical decisions.
    """

    static let privacySummary = """
    Lumi is local-first. Period logs, symptoms, notes, and predictions stay on your iPhone in an encrypted on-device database. We do not run ads, sell data, or operate a health cloud for this app.
    """

    struct Section: Identifiable, Sendable {
        let id: String
        let title: String
        let body: String
    }

    static let privacyPolicySections: [Section] = [
        Section(
            id: "overview",
            title: "Overview",
            body: """
            Lumi (“we”, “the app”) is a period and cycle tracker. This policy explains what the app stores, what leaves your device, and your choices. By using Lumi you agree to this policy.
            """
        ),
        Section(
            id: "collect",
            title: "What Lumi stores on your device",
            body: """
            • Period and cycle dates you log
            • Flow intensity, symptoms, mood, energy, sleep, and notes
            • Predictions and insights generated on your phone
            • App preferences (reminders, appearance, optional app lock) and, if you give one, the name Lumi calls you
            • Optional on-device AI chat history and downloaded Gemma model files

            This data stays on your iPhone unless you export or delete it.
            """
        ),
        Section(
            id: "not-collect",
            title: "What we do not collect",
            body: """
            We do not operate a Lumi account or server that receives your health logs. We do not use third-party analytics or advertising SDKs. We do not track you across apps or websites.
            """
        ),
        Section(
            id: "network",
            title: "Network use",
            body: """
            Lumi works offline for tracking. The only optional network feature is downloading the Gemma AI model from Hugging Face (litert-community) when you tap Download in Settings. That request goes directly to Hugging Face; we do not proxy it. Hugging Face may log standard connection metadata under their own policy.
            """
        ),
        Section(
            id: "security",
            title: "Security",
            body: """
            Cycle data is stored with SwiftData in your app sandbox. iOS Data Protection and file protection apply at rest. Optional Face ID / Touch ID app lock uses Apple’s LocalAuthentication framework on device only.
            """
        ),
        Section(
            id: "rights",
            title: "Your choices",
            body: """
            • Export your data as JSON or CSV in Settings
            • Delete all data on device in Settings
            • Remove the downloaded AI model without deleting cycle data
            • Turn off reminders at any time
            """
        ),
        Section(
            id: "children",
            title: "Age",
            body: """
            Lumi is intended for users old enough to track menstruation. Parents or guardians should supervise use by minors.
            """
        ),
        Section(
            id: "changes",
            title: "Changes & contact",
            body: """
            We may update this policy when the app changes. Continued use after an update means you accept the revised policy.

            Questions: \(supportEmail)
            Last updated: \(lastUpdated)
            """
        ),
    ]
}
