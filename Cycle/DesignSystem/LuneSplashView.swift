import SwiftUI

enum LuneSplashTiming {
    /// Minimum time from launch before transitioning to the app (~1s fade-in + ~2s to read).
    static let minimumDuration: Duration = .seconds(3)
    static let reveal: TimeInterval = 0.9
}

struct LuneSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        ZStack {
            Color.cycleBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                MoonPhaseStrip()
                    .padding(.bottom, 28)
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed ? 0 : -8)

                Text("LUNE")
                    .font(.system(.largeTitle, design: .serif).weight(.light))
                    .tracking(14)
                    .foregroundStyle(Color.cycleText)
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed ? 0 : 10)

                Rectangle()
                    .fill(Color.cycleSage.opacity(0.55))
                    .frame(width: 28, height: 1)
                    .padding(.top, 22)
                    .opacity(revealed ? 1 : 0)

                VStack(spacing: 4) {
                    Text("the moon has phases.")
                    Text("so do you.")
                }
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(Color.cycleSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 18)
                .opacity(revealed ? 1 : 0)
                .offset(y: revealed ? 0 : 8)

                Spacer()
            }
            .padding(.horizontal, 36)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Lune. The moon has phases. So do you.")
        .onAppear { animateIn() }
    }

    private func animateIn() {
        guard !reduceMotion else {
            revealed = true
            return
        }
        withAnimation(.easeOut(duration: LuneSplashTiming.reveal)) {
            revealed = true
        }
    }
}

/// Splash moon arc using SF Symbols.
private struct MoonPhaseStrip: View {
    var body: some View {
        HStack(spacing: 14) {
            ForEach(Array(LuneMoonSymbol.splashSequence.enumerated()), id: \.offset) { index, symbol in
                LuneMoonIcon(
                    symbolName: symbol,
                    pointSize: index == 2 ? 22 : 16
                )
                .opacity(index == 2 ? 1 : 0.5)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    LuneSplashView()
}
