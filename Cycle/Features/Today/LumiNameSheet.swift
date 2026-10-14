import SwiftUI

/// Tell Lumi what to call you. Opened by tapping Lumi while she asks for your name.
struct LumiNameSheet: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let onSaved: (String) -> Void

    @State private var name = ""
    @FocusState private var isFocused: Bool

    private var cleaned: String? { UserPreferences.cleanedName(name) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                LumiView(feeling: .happy, size: 110)
                    .accessibilityHidden(true)
                Text(LuneVoice.namePrompt)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.cycleText)
                    .multilineTextAlignment(.center)

                TextField("Your name", text: $name)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($isFocused)
                    .font(.system(.title3, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 14)
                    .background(Color.cycleSurface, in: Capsule())
                    .overlay(Capsule().stroke(Color.cycleBorder, lineWidth: 1))
                    .onSubmit(save)
                    .onChange(of: name) { _, new in
                        if new.count > UserPreferences.maxNameLength {
                            name = String(new.prefix(UserPreferences.maxNameLength))
                        }
                    }

                Text(LuneVoice.nameFooter)
                    .font(.footnote)
                    .foregroundStyle(Color.cycleSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Save", action: save)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(cleaned == nil)
            }
            .padding(24)
            .readableContentWidth(480)
        }
        .scrollBounceBehavior(.basedOnSize)
        .fantasySkyBackground()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Not now") { dismiss() }
            }
        }
        .onAppear {
            name = env.preferences.userName ?? ""
            isFocused = true
        }
    }

    private func save() {
        guard let cleaned else { return }
        Task {
            await env.setUserName(cleaned)
            onSaved(cleaned)
            dismiss()
        }
    }
}
