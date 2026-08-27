import Foundation

#if DEBUG
/// Launch with `-AppStoreScreenshots` (and optional `-ScreenshotScreen today|calendar|ask|insights|settings|splash`)
/// to seed demo data and jump to a specific tab for App Store captures.
enum AppStoreScreenshotMode {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-AppStoreScreenshots")
    }

    static var screen: Screen {
        guard let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-ScreenshotScreen"),
              ProcessInfo.processInfo.arguments.indices.contains(index + 1),
              let screen = Screen(rawValue: ProcessInfo.processInfo.arguments[index + 1].lowercased())
        else {
            return .today
        }
        return screen
    }

    enum Screen: String, CaseIterable, Hashable {
        case splash
        case today
        case calendar
        case ask
        case insights
        case settings
    }
}
#endif
