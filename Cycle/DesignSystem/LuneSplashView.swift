import SwiftUI

enum LuneSplashTiming {
    /// Minimum time from launch before transitioning to the app (~1s reveal + ~2s to enjoy it).
    static let minimumDuration: Duration = .seconds(3)
}

/// Launch splash: Lumi pops in on the fantasy sky with a little sparkle burst and introduces herself.
struct LuneSplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lumiVisible = false
    @State private var textVisible = false
    @State private var burst = 0

    var body: some View {
        ZStack {
            FantasySkyBackground()

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.45))
                        .frame(width: 230, height: 230)
                        .blur(radius: 40)
                    LumiView(feeling: nil, phase: nil, size: 190)
                        .scaleEffect(lumiVisible ? 1 : 0.6, anchor: .bottom)
                        .opacity(lumiVisible ? 1 : 0)
                }
                .overlay {
                    MagicBurst(trigger: burst)
                        .frame(width: 300, height: 300)
                        .allowsHitTesting(false)
                }

                Text("Lumi")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.cycleText)
                    .padding(.top, 10)
                    .opacity(textVisible ? 1 : 0)
                    .offset(y: textVisible ? 0 : 10)

                VStack(spacing: 4) {
                    Text("Hi, I'm Lumi!")
                    Text("I'll be with you through every phase.")
                }
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color.cycleSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .opacity(textVisible ? 1 : 0)
                .offset(y: textVisible ? 0 : 8)

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 36)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Lumi. Hi, I'm Lumi! I'll be with you through every phase.")
        .task { await reveal() }
    }

    private func reveal() async {
        guard !reduceMotion else {
            lumiVisible = true
            textVisible = true
            return
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
            lumiVisible = true
        }
        try? await Task.sleep(for: .milliseconds(350))
        burst += 1
        withAnimation(.easeOut(duration: 0.6)) {
            textVisible = true
        }
    }
}

#Preview {
    LuneSplashView()
}
