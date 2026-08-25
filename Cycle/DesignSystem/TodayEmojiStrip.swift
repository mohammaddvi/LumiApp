import SwiftUI

/// Compact text chips previewing vibe-check options.
struct TodayVibePreview: View {
    var feelings: [LuneQuickFeeling] = Array(LuneQuickFeeling.allCases.prefix(4))

    var body: some View {
        HStack(spacing: 6) {
            ForEach(feelings) { feeling in
                Text(feeling.label.lowercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.cycleText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.cycleAccentSoft)
                    .clipShape(Capsule())
            }
            Text("…")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.cycleSecondary)
        }
        .accessibilityLabel("Tap vibe check to log feelings like good vibes, soft, and empty tank")
    }
}

#Preview {
    TodayVibePreview()
        .padding()
        .background(Color.cycleBackground)
}
