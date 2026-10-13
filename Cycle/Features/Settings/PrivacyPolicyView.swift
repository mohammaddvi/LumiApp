import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy policy")
                    .font(.system(.title2, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.cycleText)
                    .accessibilityAddTraits(.isHeader)

                Text("Last updated \(LuneLegal.lastUpdated)")
                    .font(.footnote)
                    .foregroundStyle(Color.cycleSecondary)

                Text(LuneLegal.privacySummary)
                    .font(.body)
                    .foregroundStyle(Color.cycleSecondary)

                ForEach(LuneLegal.privacyPolicySections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.headline)
                            .foregroundStyle(Color.cycleText)
                            .accessibilityAddTraits(.isHeader)
                        Text(section.body)
                            .font(.subheadline)
                            .foregroundStyle(Color.cycleSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Link(destination: LuneLegal.privacyPolicyURL) {
                    Label("View web version", systemImage: "safari")
                }
                .font(.subheadline.weight(.semibold))
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .background(Color.cycleBackground.ignoresSafeArea())
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { PrivacyPolicyView() }
}
