import SwiftUI
import UIKit

/// Ready-made Lumi looks the app icon can switch to. iOS only allows icons built into the app,
/// so the icon can't follow every outfit; each look here has an `AppIcon-…` set in the asset catalog,
/// rendered from `LumiAppIconArt` (see `AppIconRenderTests`).
enum LumiIconLook: String, CaseIterable, Identifiable, Sendable {
    case classic
    case flowerCrown
    case cozyBeanie
    case music
    case royal
    case party
    case sleepy
    case sweetheart
    case fairy
    case unicorn

    var id: String { rawValue }

    var name: String {
        switch self {
        case .classic: "Classic"
        case .flowerCrown: "Flowers"
        case .cozyBeanie: "Cozy"
        case .music: "Music"
        case .royal: "Royal"
        case .party: "Party"
        case .sleepy: "Sleepy"
        case .sweetheart: "Sweetheart"
        case .fairy: "Fairy"
        case .unicorn: "Unicorn"
        }
    }

    var outfit: LumiOutfit {
        switch self {
        case .classic: LumiOutfit()
        case .flowerCrown: LumiOutfit([.flowerCrown])
        case .cozyBeanie: LumiOutfit([.beanie, .sweater])
        case .music: LumiOutfit([.bangs, .headphones, .roundGlasses])
        case .royal: LumiOutfit([.curls, .crown])
        case .party: LumiOutfit([.partyHat, .heartGlasses])
        case .sleepy: LumiOutfit([.bun, .pajamas, .bunnySlippers])
        case .sweetheart: LumiOutfit([.pigtails, .bow, .dress])
        case .fairy: LumiOutfit([.flowerCrown, .glitter, .fairyWings])
        case .unicorn: LumiOutfit([.bob, .starCheeks, .unicornHorn])
        }
    }

    /// The alternate icon's asset name; nil is the main icon.
    var iconName: String? {
        switch self {
        case .classic: nil
        default: "AppIcon-" + rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }

    @MainActor
    static var current: LumiIconLook {
        let name = UIApplication.shared.alternateIconName
        return allCases.first { $0.iconName == name } ?? .classic
    }
}

/// Lumi on the app icon's sky, matching the main icon's layout. Used for the picker previews
/// and to render the alternate icon images.
struct LumiAppIconArt: View {
    let outfit: LumiOutfit

    private static let sparkles: [(x: CGFloat, y: CGFloat, radius: CGFloat, gold: Bool)] = [
        (0.16, 0.18, 0.034, true),
        (0.84, 0.14, 0.026, false),
        (0.88, 0.62, 0.030, true),
        (0.12, 0.70, 0.022, false),
        (0.70, 0.86, 0.016, false),
    ]

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.87, green: 0.79, blue: 0.96),
                        Color(red: 0.96, green: 0.93, blue: 0.98),
                        Color(red: 0.98, green: 0.86, blue: 0.91),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                RadialGradient(
                    colors: [.white.opacity(0.55), .clear],
                    center: UnitPoint(x: 0.42, y: 0.45),
                    startRadius: 0,
                    endRadius: side * 0.5
                )
                Canvas { context, size in
                    for sparkle in Self.sparkles {
                        let color = sparkle.gold ? Color(red: 0.98, green: 0.80, blue: 0.40) : Color.white
                        context.fill(
                            FantasySparkle.path(
                                center: CGPoint(x: sparkle.x * size.width, y: sparkle.y * size.height),
                                radius: sparkle.radius * size.width
                            ),
                            with: .color(color)
                        )
                    }
                }
                LumiView(feeling: nil, phase: nil, size: side * 0.84, animated: false, outfit: outfit)
                    .position(x: side / 2, y: side * 0.526)
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
