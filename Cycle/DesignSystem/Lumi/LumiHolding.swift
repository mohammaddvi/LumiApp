import SwiftUI

/// Sizes screens need to leave room for Lumi above the card she holds.
enum LumiHoldingMetrics {
    static let defaultSize: CGFloat = 140

    /// How far Lumi rises above the card's top edge: down to just below her mouth.
    static func rise(size: CGFloat = defaultSize) -> CGFloat { size * 0.68 }
}

extension View {
    /// Lumi peeks over this card's top-trailing corner with her hands on its edge, as if holding it.
    /// The card needs an opaque background so it hides her lower half. Content above the card
    /// should leave about `size + 24` points free on the trailing side.
    /// Tapping her makes her giggle and hop, then runs `action`; stroking her sideways pets her;
    /// a long press runs `longPressAction`.
    func lumiHolding(
        feeling: Feeling?,
        phase: LunePhase?,
        isGuess: Bool,
        size: CGFloat = LumiHoldingMetrics.defaultSize,
        celebration: Int = 0,
        speech: LumiSpeech? = nil,
        accessibilityLabel: String,
        accessibilityHint: String,
        longPressAction: (() -> Void)? = nil,
        action: @escaping () -> Void
    ) -> some View {
        modifier(LumiHoldingModifier(
            feeling: feeling,
            phase: phase,
            isGuess: isGuess,
            size: size,
            celebration: celebration,
            speech: speech,
            accessibilityLabel: accessibilityLabel,
            accessibilityHint: accessibilityHint,
            longPressAction: longPressAction,
            action: action
        ))
    }
}

private struct LumiHoldingModifier: ViewModifier {
    let feeling: Feeling?
    let phase: LunePhase?
    let isGuess: Bool
    let size: CGFloat
    let celebration: Int
    let speech: LumiSpeech?
    let accessibilityLabel: String
    let accessibilityHint: String
    let longPressAction: (() -> Void)?
    let action: () -> Void

    private let trailingInset: CGFloat = 14
    private var rise: CGFloat { LumiHoldingMetrics.rise(size: size) }
    private var palette: LumiPalette { .resolve(feeling: feeling, phase: phase) }

    func body(content: Content) -> some View {
        content
            .background(alignment: .topTrailing) {
                ZStack {
                    MagicBurst(trigger: celebration)
                        .frame(width: size * 1.6, height: size * 1.6)
                        .allowsHitTesting(false)
                    PlayfulLumi(
                        feeling: feeling,
                        phase: phase,
                        size: size,
                        holding: true,
                        talking: speech?.isTalking ?? false,
                        onTap: action,
                        onLongPress: longPressAction
                    )
                    .accessibilityLabel(accessibilityLabel)
                    .accessibilityHint(accessibilityHint)
                }
                .frame(width: size, height: size)
                .offset(x: -trailingInset, y: -rise)
            }
            .overlay(alignment: .topTrailing) {
                hands
                    .frame(width: size, height: size * 0.13)
                    .offset(x: -trailingInset, y: -size * 0.065)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .overlay(alignment: .topTrailing) {
                if let speech, speech.text != nil {
                    // Beside Lumi's head, tail pointing at her.
                    // Uses the room left of Lumi, so longer lines stay at about two lines
                    // instead of growing up into the title.
                    LumiSpeechBubble(speech: speech, onTap: action)
                        .frame(maxWidth: 300, alignment: .trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, trailingInset + size * 0.82)
                        // Starts at the top of Lumi (screens keep that below the title) and grows
                        // downward, so long lines spill over the card instead of up under the
                        // navigation title, which always draws above the page.
                        .frame(height: 0, alignment: .top)
                        .offset(y: -rise + 6)
                } else if isGuess {
                    guessBubble
                        .offset(x: -(trailingInset + size * 0.86), y: -rise + size * 0.08)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
    }

    private var hands: some View {
        let palette = palette
        return Canvas { context, canvasSize in
            let width = canvasSize.width
            let height = canvasSize.height
            for x in [width * 0.33, width * 0.67] {
                let hand = Path(ellipseIn: CGRect(x: x - width * 0.075, y: 0, width: width * 0.15, height: height))
                context.fill(
                    hand,
                    with: .linearGradient(
                        Gradient(colors: [palette.bodyLight, palette.body]),
                        startPoint: CGPoint(x: x, y: 0),
                        endPoint: CGPoint(x: x, y: height)
                    )
                )
                context.stroke(hand, with: .color(palette.bodyDark.opacity(0.35)), lineWidth: 1)

                var fingers = Path()
                for offset in [-0.024, 0.024] {
                    fingers.move(to: CGPoint(x: x + width * offset, y: height * 0.5))
                    fingers.addLine(to: CGPoint(x: x + width * offset, y: height * 0.92))
                }
                context.stroke(fingers, with: .color(palette.bodyDark.opacity(0.55)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            }
        }
    }

    /// A little thought bubble so a guess never looks like a logged feeling.
    private var guessBubble: some View {
        ZStack(alignment: .bottomTrailing) {
            Text("?")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.cycleText)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.cycleSurface))
                .overlay(Circle().stroke(palette.body, lineWidth: 1.5))
            Circle()
                .fill(Color.cycleSurface)
                .overlay(Circle().stroke(palette.body, lineWidth: 1.2))
                .frame(width: 9, height: 9)
                .offset(x: 9, y: 9)
        }
    }
}
