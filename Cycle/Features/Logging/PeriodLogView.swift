import SwiftUI

struct PeriodLogView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    var initialDate: Date = .now
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var intensity: FlowIntensity = .medium
    @State private var spotting = false
    @State private var errorMessage: String?
    @State private var isSaving = false

    private var dayCount: Int {
        max(1, endDate.startOfDay.daysSince(startDate.startOfDay) + 1)
    }

    var body: some View {
        Form {
            Section {
                DatePicker(
                    "Starts",
                    selection: $startDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .onChange(of: startDate) { _, newValue in
                    if endDate < newValue { endDate = newValue }
                }

                DatePicker(
                    "Ends",
                    selection: $endDate,
                    in: startDate...Date(),
                    displayedComponents: .date
                )
            } header: {
                Text("Period range")
            } footer: {
                Text("\(dayCount) day\(dayCount == 1 ? "" : "s") will be marked as period on your calendar.")
            }

            Section("Typical flow") {
                Picker("Intensity", selection: $intensity) {
                    ForEach(FlowIntensity.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("Mostly spotting", isOn: $spotting)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(Color.cycleSage)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.cycleBackground)
        .navigationTitle("Log period")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await save() }
                }
                .fontWeight(.semibold)
                .disabled(isSaving)
            }
        }
        .onAppear {
            startDate = initialDate.startOfDay
            // Default to a 5-day range ending today or start+4, whichever is earlier
            let suggestedEnd = min(initialDate.addingDays(4), Date().startOfDay)
            endDate = max(suggestedEnd, startDate)
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        if let message = await env.logPeriodRange(
            from: startDate,
            to: endDate,
            intensity: intensity,
            spotting: spotting
        ) {
            // Overlap with a single existing day — try updating flow for that day only when range is 1 day
            if message.contains("overlaps"), startDate.startOfDay == endDate.startOfDay {
                if let fallback = await env.logFlow(on: startDate, intensity: intensity, spotting: spotting) {
                    errorMessage = fallback
                } else {
                    dismiss()
                }
            } else {
                errorMessage = message
            }
            return
        }
        dismiss()
    }
}
