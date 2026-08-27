import SwiftUI

// MARK: - Resource
// Apple SF Symbols `moonphase.*` (iOS 16+).
// Palette rendering: warm yellow lit surface + soft gray shadow (reads well on cream, especially full moon).

enum LuneMoonSymbol {
    /// Splash arc: new → waxing → full → waning → new
    static let splashSequence = [
        LunePhase.reset.sfSymbolName,
        LunePhase.bloom.sfSymbolName,
        LunePhase.glow.sfSymbolName,
        LunePhase.slow.sfSymbolName,
        LunePhase.reset.sfSymbolName,
    ]

    static func name(for phase: LunePhase, isSoftDays: Bool = false) -> String {
        isSoftDays ? LunePhase.slow.sfSymbolName : phase.sfSymbolName
    }
}

/// Moon phase glyph — yellow lit surface, gray shadow (SF Symbol palette mode).
struct LuneMoonIcon: View {
    var symbolName: String
    var pointSize: CGFloat = 24

    var body: some View {
        Image(systemName: symbolName)
            .symbolRenderingMode(.palette)
            .foregroundStyle(Color.cycleMoonLight, Color.cycleMoonShadow)
            .font(.system(size: pointSize, weight: .regular))
            .frame(width: pointSize * 1.12, height: pointSize * 1.12)
            .accessibilityHidden(true)
    }
}

/// Hero moon for Today's MyLune.
struct LuneMoonCompanion: View {
    var phase: LunePhase
    var isSoftDays = false
    var size: CGFloat = 72

    private var symbolName: String {
        LuneMoonSymbol.name(for: phase, isSoftDays: isSoftDays)
    }

    var body: some View {
        LuneMoonIcon(symbolName: symbolName, pointSize: size * 0.58)
            .frame(width: size, height: size)
            .accessibilityLabel("\(phase.name) moon phase")
    }
}

/// Button label that keeps moon colors distinct from button tint.
struct LuneMoonButtonLabel: View {
    var title: String
    var symbolName: String = LunePhase.reset.sfSymbolName
    var moonSize: CGFloat = 18

    var body: some View {
        HStack(spacing: 8) {
            LuneMoonIcon(symbolName: symbolName, pointSize: moonSize)
            Text(title)
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        HStack(spacing: 16) {
            ForEach(LuneMoonSymbol.splashSequence, id: \.self) { symbol in
                LuneMoonIcon(symbolName: symbol, pointSize: 20)
            }
        }
        HStack(spacing: 20) {
            LuneMoonCompanion(phase: .reset, size: 68)
            LuneMoonCompanion(phase: .bloom, size: 68)
            LuneMoonCompanion(phase: .glow, size: 68)
            LuneMoonCompanion(phase: .slow, isSoftDays: true, size: 68)
        }
    }
    .padding()
    .background(Color.cycleBackground)
}
