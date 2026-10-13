import SwiftUI

/// Pick the symptoms someone usually notices in a phase, split into Body and Mind.
/// Used in onboarding and in Settings → Period.
struct SymptomBaselineCard: View {
    let title: String
    let subtitle: String
    @Binding var selection: Set<SymptomType>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.cycleText)
                .accessibilityAddTraits(.isHeader)

            Text(subtitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.cycleSecondary)

            SymptomCategoryCard(title: "Body", subtitle: "Physical symptoms", accent: .cycleSage) {
                chipGrid(SymptomType.allCases.filter { $0.group == .body })
            }

            SymptomCategoryCard(title: "Mind & lifestyle", subtitle: "Mood, energy, sleep, and appetite", accent: .cycleSage) {
                chipGrid(SymptomType.allCases.filter { $0.group == .mind })
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cycleAccentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.cycleBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private func chipGrid(_ symptoms: [SymptomType]) -> some View {
        FlowLayout(spacing: 10) {
            ForEach(symptoms) { symptom in
                ChipButton(
                    title: symptom.displayName,
                    isSelected: selection.contains(symptom),
                    accent: .cycleSage
                ) {
                    if selection.contains(symptom) {
                        selection.remove(symptom)
                    } else {
                        selection.insert(symptom)
                    }
                }
                .accessibilityLabel("\(symptom.displayName), \(symptom.group.displayName)")
            }
        }
    }
}
