import SwiftUI

/// Lumi's colors. Feelings pick the body color; with no feeling logged, the cycle phase does.
struct LumiPalette: Equatable {
    var bodyLight: Color
    var body: Color
    var bodyDark: Color
    var leaf: Color
    var leafDark: Color

    static let eye = Color(red: 0.23, green: 0.16, blue: 0.24)
    static let blush = Color(red: 0.98, green: 0.58, blue: 0.66)
    static let heart = Color(red: 0.95, green: 0.45, blue: 0.58)
    static let tear = Color(red: 0.55, green: 0.75, blue: 0.97)
    static let anger = Color(red: 0.94, green: 0.42, blue: 0.30)

    private static let coralLeaf = (Color(red: 0.99, green: 0.68, blue: 0.56), Color(red: 0.93, green: 0.49, blue: 0.43))
    private static let greenLeaf = (Color(red: 0.55, green: 0.76, blue: 0.47), Color(red: 0.36, green: 0.58, blue: 0.33))

    private static func make(_ light: (Double, Double, Double), _ base: (Double, Double, Double), _ dark: (Double, Double, Double), greenLeaf: Bool = false) -> LumiPalette {
        let leaf = greenLeaf ? Self.greenLeaf : Self.coralLeaf
        return LumiPalette(
            bodyLight: Color(red: light.0 / 255, green: light.1 / 255, blue: light.2 / 255),
            body: Color(red: base.0 / 255, green: base.1 / 255, blue: base.2 / 255),
            bodyDark: Color(red: dark.0 / 255, green: dark.1 / 255, blue: dark.2 / 255),
            leaf: leaf.0,
            leafDark: leaf.1
        )
    }

    static let lavender = make((236, 224, 250), (199, 172, 234), (158, 128, 204))

    /// Feeling wins; otherwise the cycle phase; otherwise Lumi's default lavender.
    static func resolve(feeling: Feeling?, phase: LunePhase?) -> LumiPalette {
        if let feeling { return .for(feeling) }
        if let phase { return .for(phase) }
        return lavender
    }

    static func `for`(_ feeling: Feeling) -> LumiPalette {
        switch feeling {
        case .happy: lavender
        case .calm: make((231, 226, 251), (190, 178, 234), (148, 136, 206))
        case .tired: make((224, 231, 252), (168, 184, 236), (124, 142, 208))
        case .anxious: make((222, 241, 216), (165, 208, 160), (114, 166, 118), greenLeaf: true)
        case .irritable: make((255, 226, 200), (248, 176, 126), (226, 132, 86))
        case .sad: make((242, 224, 247), (208, 170, 224), (166, 128, 192))
        }
    }

    static func `for`(_ phase: LunePhase) -> LumiPalette {
        switch phase {
        case .reset: make((255, 222, 220), (242, 160, 158), (214, 116, 118))
        case .bloom: make((230, 230, 252), (180, 180, 238), (136, 138, 212))
        case .glow: make((255, 234, 200), (246, 198, 126), (220, 156, 80))
        case .slow: make((226, 240, 218), (170, 204, 154), (120, 164, 112), greenLeaf: true)
        }
    }
}
