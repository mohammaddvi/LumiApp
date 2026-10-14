import SwiftUI

/// Opened by tapping Lumi on Today: pick a feeling (Lumi previews it), then log it.
/// Starts on Lumi's guess when nothing is logged yet, so a right guess is one tap.
struct FeelingCheckInSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let guess: Feeling?
    let onLogged: () -> Void

    @State private var selection: Feeling?
    @State private var isSaving = false

    private var savedFeeling: Feeling? { env.todayFeeling }

    private var previewFeeling: Feeling? { selection ?? savedFeeling }

    private var hasUnsavedChoice: Bool {
        selection != nil && selection != savedFeeling
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    LumiView(feeling: previewFeeling, phase: env.todaysLune?.phase, size: 150)
                    Text(previewFeeling?.displayName ?? LuneVoice.feelingPrompt)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.cycleText)
                    if let previewFeeling {
                        Text(LuneVoice.lumiMessage(for: previewFeeling, name: env.preferences.userName))
                            .font(.body)
                            .foregroundStyle(Color.cycleSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .animation(.smooth(duration: 0.25), value: previewFeeling)
                .accessibilityElement(children: .combine)

                CycleCard {
                    VStack(spacing: 14) {
                        Text(LuneVoice.feelingPrompt)
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(Color.cycleText)
                            .frame(maxWidth: .infinity)
                            .accessibilityAddTraits(.isHeader)

                        FeelingPicker(selection: previewFeeling) { selection = $0 }
                    }
                }

                NavigationLink {
                    QuickCheckInView()
                } label: {
                    Label("Add symptoms or a note", systemImage: "square.and.pencil")
                }
                .buttonStyle(PrimaryButtonStyle(filled: false))
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                log()
            } label: {
                Label(logButtonTitle, systemImage: hasUnsavedChoice ? "sparkles" : "checkmark.circle.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!hasUnsavedChoice || isSaving)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .fantasySkyBackground()
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
        .onAppear {
            if savedFeeling == nil {
                selection = guess
            }
        }
    }

    private var logButtonTitle: String {
        if hasUnsavedChoice {
            return savedFeeling == nil ? LuneVoice.logFeeling : LuneVoice.updateFeeling
        }
        return savedFeeling == nil ? LuneVoice.pickFeelingFirst : LuneVoice.feelingLogged
    }

    private func log() {
        guard let choice = selection, !isSaving else { return }
        isSaving = true
        Task {
            await env.logFeeling(choice)
            isSaving = false
            if savedFeeling == choice {
                onLogged()
                dismiss()
            }
        }
    }
}
