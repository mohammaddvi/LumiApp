import SwiftUI

/// What Lumi is saying right now. Owned by the screen; read by `lumiHolding` to show the bubble.
@MainActor
@Observable
final class LumiSpeech {
    private(set) var text: String?
    /// True while the words are still typing out (Lumi's mouth moves).
    var isTalking = false
    /// Changes on every `say`, so the same line can be said twice.
    private(set) var utterance = 0

    func say(_ text: String) {
        self.text = text
        utterance += 1
    }

    func dismiss() {
        text = nil
        isTalking = false
    }
}

/// A speech bubble whose text types out while Lumi's mouth moves, then fades away on its own.
struct LumiSpeechBubble: View {
    let speech: LumiSpeech
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shownCount = 0

    /// How long the finished line stays before the bubble leaves.
    private static let readingTime: Duration = .seconds(5)

    var body: some View {
        if let text = speech.text {
            Button(action: onTap) {
                ZStack(alignment: .topLeading) {
                    // The full line, invisible, fixes the bubble size so it doesn't grow while typing.
                    Text(text).hidden()
                    Text(String(text.prefix(shownCount)))
                }
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.cycleText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .padding(.trailing, SpeechBubbleShape.tailSize)
                .background(SpeechBubbleShape().fill(Color.cycleSurface))
                .overlay(SpeechBubbleShape().stroke(Color.cycleBorder, lineWidth: 1))
                .shadow(color: Color.cycleSage.opacity(0.25), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Lumi says: \(text)")
            .accessibilityHint("Double tap to answer")
            .transition(.scale(scale: 0.8, anchor: .trailing).combined(with: .opacity))
            .task(id: speech.utterance) {
                await play(text)
            }
        }
    }

    private func play(_ text: String) async {
        shownCount = 0
        if reduceMotion || UIAccessibility.isVoiceOverRunning {
            shownCount = text.count
            UIAccessibility.post(notification: .announcement, argument: "Lumi says: \(text)")
        } else {
            speech.isTalking = true
            for (index, character) in text.enumerated() {
                guard !Task.isCancelled else { return }
                shownCount = index + 1
                let pause: Duration = ".,!?".contains(character) ? .milliseconds(220) : .milliseconds(58)
                try? await Task.sleep(for: pause)
            }
            speech.isTalking = false
        }
        try? await Task.sleep(for: Self.readingTime)
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            speech.dismiss()
        }
    }
}

/// Rounded bubble with a little tail on the trailing side, pointing at Lumi.
struct SpeechBubbleShape: Shape {
    static let tailSize: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        let tail = Self.tailSize
        let body = CGRect(x: rect.minX, y: rect.minY, width: rect.width - tail, height: rect.height)
        var path = Path(roundedRect: body, cornerRadius: 18, style: .continuous)
        let tipY = body.maxY - 18
        path.move(to: CGPoint(x: body.maxX - 1, y: tipY - 9))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: tipY + 6), control: CGPoint(x: body.maxX + 3, y: tipY + 2))
        path.addQuadCurve(to: CGPoint(x: body.maxX - 1, y: tipY + 7), control: CGPoint(x: body.maxX + 2, y: tipY + 8))
        path.closeSubpath()
        return path
    }
}
