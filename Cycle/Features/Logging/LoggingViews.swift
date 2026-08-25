import SwiftUI

struct QuickCheckInView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    var initialDate: Date = .now
    @State private var date = Date()
    @State private var mood: MoodLevel?
    @State private var energy: EnergyLevel?
    @State private var sleep: SleepQuality?
    @State private var selected: [SymptomType: IntensityLevel] = [:]
    @State private var note = ""
    @State private var activeFeelings: Set<LuneQuickFeeling> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                    .tint(Color.cycleSage)

                VStack(alignment: .leading, spacing: 12) {
                    Text("how are we feeling?")
                        .font(.headline)
                        .foregroundStyle(Color.cycleText)
                        .accessibilityAddTraits(.isHeader)

                    FlowLayout(spacing: 10) {
                        ForEach(LuneQuickFeeling.allCases) { feeling in
                            LuneFeelingChip(
                                feeling: feeling,
                                isSelected: activeFeelings.contains(feeling)
                            ) {
                                toggleFeeling(feeling)
                            }
                        }
                    }
                }

                levelSection(title: "Mood", values: MoodLevel.allCases, selection: $mood) {
                    "\($0.luneEmoji) \($0.displayName)"
                }
                levelSection(title: "Energy", values: EnergyLevel.allCases, selection: $energy) { $0.displayName }
                levelSection(title: "Sleep", values: SleepQuality.allCases, selection: $sleep) { $0.displayName }

                ForEach(SymptomGroup.allCases, id: \.self) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(group.luneDisplayName)
                            .font(.headline)
                            .foregroundStyle(Color.cycleText)
                            .accessibilityAddTraits(.isHeader)
                        FlowLayout(spacing: 8) {
                            ForEach(SymptomType.allCases.filter { $0.group == group }) { symptom in
                                ChipButton(
                                    title: symptom.displayName,
                                    isSelected: selected[symptom] != nil,
                                    accent: .cycleSage
                                ) {
                                    if selected[symptom] == nil {
                                        selected[symptom] = .moderate
                                    } else {
                                        selected.removeValue(forKey: symptom)
                                    }
                                }
                            }
                        }
                        if let active = selected.first(where: { $0.key.group == group }) {
                            Picker("Intensity for \(active.key.displayName)", selection: binding(for: active.key)) {
                                ForEach(IntensityLevel.allCases) { level in
                                    Text(level.displayName).tag(level)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("lune notes ☁️")
                        .font(.headline)
                        .foregroundStyle(Color.cycleText)
                        .accessibilityAddTraits(.isHeader)

                    FlowLayout(spacing: 8) {
                        ForEach(LuneNotePrompt.allCases) { prompt in
                            Button {
                                note = prompt.text
                            } label: {
                                Text(prompt.text)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.cycleText)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .frame(minHeight: 44)
                                    .background(note == prompt.text ? Color.cycleAccentSoft : Color.cycleSurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(note == prompt.text ? Color.cycleSage : Color.cycleBorder, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Note prompt, \(prompt.text)")
                        }
                    }

                    TextField("hey lune, today i feel…", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(12)
                        .background(Color.cycleSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.cycleBorder, lineWidth: 1)
                        )
                }
            }
            .padding(20)
        }
        .background(Color.cycleBackground.ignoresSafeArea())
        .navigationTitle(LuneLexicon.checkIn)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        let existing = env.checkIn(on: date)
                        let record = DailyCheckInRecord(
                            id: existing?.id ?? UUID(),
                            date: date,
                            mood: mood,
                            energy: energy,
                            sleepQuality: sleep,
                            symptoms: selected.map { SymptomOccurrence(symptomType: $0.key, intensity: $0.value) },
                            note: note.isEmpty ? nil : note
                        )
                        await env.saveCheckIn(record)
                        dismiss()
                    }
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            date = initialDate
            if let existing = env.checkIn(on: date) {
                mood = existing.mood
                energy = existing.energy
                sleep = existing.sleepQuality
                note = existing.note ?? ""
                selected = Dictionary(uniqueKeysWithValues: existing.symptoms.map { ($0.symptomType, $0.intensity) })
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button("Save \(LuneLexicon.checkIn.lowercased())") {
                Task {
                    let existing = env.checkIn(on: date)
                    let record = DailyCheckInRecord(
                        id: existing?.id ?? UUID(),
                        date: date,
                        mood: mood,
                        energy: energy,
                        sleepQuality: sleep,
                        symptoms: selected.map { SymptomOccurrence(symptomType: $0.key, intensity: $0.value) },
                        note: note.isEmpty ? nil : note
                    )
                    await env.saveCheckIn(record)
                    dismiss()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(20)
            .background(Color.cycleBackground)
        }
    }

    private func toggleFeeling(_ feeling: LuneQuickFeeling) {
        if activeFeelings.contains(feeling) {
            activeFeelings.remove(feeling)
        } else {
            activeFeelings.insert(feeling)
            feeling.apply(mood: &mood, energy: &energy, symptoms: &selected)
        }
    }

    private func binding(for symptom: SymptomType) -> Binding<IntensityLevel> {
        Binding(
            get: { selected[symptom] ?? .moderate },
            set: { selected[symptom] = $0 }
        )
    }

    private func levelSection<T: Hashable & Identifiable & Equatable>(
        title: String,
        values: [T],
        selection: Binding<T?>,
        label: @escaping (T) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.cycleText)
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(values) { value in
                        ChipButton(
                            title: label(value),
                            isSelected: selection.wrappedValue == value
                        ) {
                            selection.wrappedValue = selection.wrappedValue == value ? nil : value
                        }
                    }
                }
            }
        }
    }
}

/// Simple wrapping layout for symptom chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth.isFinite ? maxWidth : x, height: y + rowHeight), frames)
    }
}

struct LuneFeelingChip: View {
    let feeling: LuneQuickFeeling
    var isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(feeling.emoji)
                    .font(.title2)
                    .accessibilityHidden(true)
                Text(feeling.label)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.cycleText)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(minWidth: 76, minHeight: 76)
            .background(isSelected ? Color.cycleAccentSoft : Color.cycleSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.cycleSage : Color.cycleBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(feeling.label), \(isSelected ? "selected" : "not selected")")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
