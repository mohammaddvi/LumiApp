import Foundation
import SwiftUI
import Testing
@testable import Cycle

@Suite("App icon looks")
@MainActor
struct AppIconRenderTests {
    @Test("Each look has its own outfit and icon name; only Classic uses the main icon")
    func distinctLooks() {
        let looks = LumiIconLook.allCases
        #expect(Set(looks.map(\.outfit.rawValue)).count == looks.count)
        #expect(Set(looks.compactMap(\.iconName)).count == looks.count - 1)
        #expect(LumiIconLook.classic.iconName == nil)
        #expect(LumiIconLook.flowerCrown.iconName == "AppIcon-FlowerCrown")
    }

    @Test("Every alternate icon is built into the app")
    func iconsBundled() throws {
        let icons = try #require(Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any])
        let alternates = try #require(icons["CFBundleAlternateIcons"] as? [String: Any])
        for case let name? in LumiIconLook.allCases.map(\.iconName) {
            #expect(alternates[name] != nil, "Missing \(name)")
        }
    }

    /// Writes `AppIcon-….appiconset` folders. Run with
    /// `TEST_RUNNER_LUMI_ICON_DIR=<dir> xcodebuild test … -only-testing:CycleTests/AppIconRenderTests`,
    /// then copy them into `Cycle/Resources/Assets.xcassets`.
    @Test("Render alternate icon images", .enabled(if: ProcessInfo.processInfo.environment["LUMI_ICON_DIR"] != nil))
    func render() throws {
        let directory = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["LUMI_ICON_DIR"]))
        for look in LumiIconLook.allCases {
            // Classic is the main icon; it's rendered too, only to compare against the real one.
            let name = look.iconName ?? "Preview-Classic"
            let renderer = ImageRenderer(content: LumiAppIconArt(outfit: look.outfit).frame(width: 1024, height: 1024))
            renderer.scale = 1
            // App icons must not have transparency.
            renderer.isOpaque = true
            let png = try #require(renderer.uiImage?.pngData())

            let set = directory.appendingPathComponent("\(name).appiconset")
            try FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
            try png.write(to: set.appendingPathComponent("\(name).png"))
            let contents = """
            {
              "images" : [
                {
                  "filename" : "\(name).png",
                  "idiom" : "universal",
                  "platform" : "ios",
                  "size" : "1024x1024"
                }
              ],
              "info" : {
                "author" : "xcode",
                "version" : 1
              }
            }

            """
            try Data(contents.utf8).write(to: set.appendingPathComponent("Contents.json"))
        }
    }
}
