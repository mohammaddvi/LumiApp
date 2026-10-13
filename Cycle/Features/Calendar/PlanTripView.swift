import SwiftUI

/// Pick trip dates and see which predicted period, PMS and ovulation days fall inside them.
struct PlanTripView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var tripStart = Date.now.startOfDay.addingDays(14)
    @State private var tripEnd = Date.now.startOfDay.addingDays(21)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                datesCard
                if let outlook = env.cycleOutlook {
                    resultCard(outlook)
                } else {
                    CycleCard {
                        Text("Log a few periods and Lumi will predict the months ahead.")
                            .font(.body)
                            .foregroundStyle(Color.cycleSecondary)
                    }
                }
            }
            .padding(20)
        }
        .fantasySkyBackground()
        .navigationTitle("Plan a trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onChange(of: tripStart) { _, start in
            if tripEnd < start { tripEnd = start }
        }
    }

    private var datesCard: some View {
        CycleCard {
            VStack(spacing: 4) {
                DatePicker("Leaving", selection: $tripStart, in: Date.now.startOfDay..., displayedComponents: .date)
                Divider().overlay(Color.cycleBorder)
                DatePicker("Coming back", selection: $tripEnd, in: tripStart..., displayedComponents: .date)
            }
            .tint(Color.cycleAccentText)
            .foregroundStyle(Color.cycleText)
        }
    }

    private func resultCard(_ outlook: CycleOutlook) -> some View {
        let overlaps = outlook.overlaps(tripStart: tripStart, tripEnd: tripEnd)
        let pms = env.preferences.experiencesPMS
        let shift = outlook.cycles.first { $0.periodEnd >= tripStart.startOfDay }?.uncertaintyDays ?? 3

        return CycleCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    LumiView(feeling: overlaps.isEmpty ? .happy : .calm, size: 60, animated: false)
                        .accessibilityHidden(true)
                    Text(overlaps.isEmpty ? LuneVoice.tripAllClearTitle : LuneVoice.tripHeadsUpTitle)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.cycleText)
                        .accessibilityAddTraits(.isHeader)
                }

                if overlaps.isEmpty {
                    Text(LuneVoice.tripAllClearBody)
                        .font(.body)
                        .foregroundStyle(Color.cycleSecondary)
                } else {
                    ForEach(Array(overlaps.enumerated()), id: \.offset) { _, overlap in
                        VStack(alignment: .leading, spacing: 4) {
                            plannedRow(overlap.kind, from: overlap.start, to: overlap.end)
                            Text(LuneVoice.tripTip(overlap.kind, experiencesPMS: pms))
                                .font(.subheadline)
                                .foregroundStyle(Color.cycleSecondary)
                                .padding(.leading, 26)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Text(LuneVoice.predictionShift(days: shift))
                    .font(.footnote)
                    .foregroundStyle(Color.cycleSecondary)
            }
        }
    }

    private func plannedRow(_ kind: PlannedDayKind, from start: Date, to end: Date) -> some View {
        HStack(spacing: 10) {
            marker(kind)
                .frame(width: 16)
                .accessibilityHidden(true)
            Text(LuneVoice.plannedDayTitle(kind, experiencesPMS: env.preferences.experiencesPMS))
                .font(.body.weight(.medium))
                .foregroundStyle(Color.cycleText)
            Spacer(minLength: 8)
            Text(rangeText(start, end))
                .font(.body)
                .foregroundStyle(Color.cycleSecondary)
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder
    private func marker(_ kind: PlannedDayKind) -> some View {
        switch kind {
        case .period:
            Capsule().stroke(Color.cycleCoralStrong, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                .frame(width: 16, height: 9)
        case .prePeriod:
            Capsule().fill(Color.cycleCoral.opacity(0.3))
                .frame(width: 16, height: 9)
        case .ovulation:
            Circle().stroke(Color.cycleOvulation, lineWidth: 2)
                .frame(width: 10, height: 10)
        }
    }

    private func rangeText(_ start: Date, _ end: Date) -> String {
        let style = Date.FormatStyle.dateTime.month(.abbreviated).day()
        if Calendar.current.isDate(start, inSameDayAs: end) {
            return start.formatted(style)
        }
        return "\(start.formatted(style)) – \(end.formatted(style))"
    }
}
