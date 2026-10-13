import SwiftUI

/// Settings → Period → Usual symptoms. Changes save as you tap.
struct PeriodSymptomsView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SymptomBaselineCard(
                    title: "During your period",
                    subtitle: "Symptoms you notice while bleeding",
                    selection: binding(\.typicalPeriodSymptoms)
                )

                if env.preferences.experiencesPMS {
                    SymptomBaselineCard(
                        title: "During PMS",
                        subtitle: "Symptoms in the days before your period",
                        selection: binding(\.typicalPMSSymptoms)
                    )
                }

                Text("Not a diagnosis — just a baseline for your own patterns and reminders.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.cycleSecondary)
            }
            .padding(20)
        }
        .fantasySkyBackground()
        .navigationTitle("Usual symptoms")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func binding(_ keyPath: WritableKeyPath<UserPreferences, [SymptomType]>) -> Binding<Set<SymptomType>> {
        Binding(
            get: { Set(env.preferences[keyPath: keyPath]) },
            set: { newValue in
                var prefs = env.preferences
                prefs[keyPath: keyPath] = SymptomType.allCases.filter(newValue.contains)
                Task { await env.updatePreferences(prefs) }
            }
        )
    }
}
