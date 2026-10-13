import SwiftUI

/// Settings → Communication → Messages: people who get period / PMS heads-ups via iMessage.
struct MessagesSettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var contactsDraft: [MessageContact] = []
    @State private var enabledDraft = false

    var body: some View {
        List {
            Section {
                IMessageContactsEditor(contacts: $contactsDraft, enabled: $enabledDraft)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)

                Button("Save contacts") {
                    Task {
                        var prefs = env.preferences
                        prefs.iMessageContacts = contactsDraft.filter(\.isValid)
                        prefs.iMessageRemindersEnabled = enabledDraft && !prefs.iMessageContacts.isEmpty
                        await env.updatePreferences(prefs)
                        contactsDraft = prefs.iMessageContacts
                        enabledDraft = prefs.iMessageRemindersEnabled
                    }
                }
                .disabled(
                    contactsDraft == env.preferences.iMessageContacts
                        && enabledDraft == env.preferences.iMessageRemindersEnabled
                )
            } footer: {
                Text("With automatic heads-ups on, Lumi opens Messages at reminder time with your saved numbers filled in. iOS still needs one tap on Send — apps can’t send iMessage silently.")
            }

            if !env.preferences.iMessageContacts.isEmpty {
                Section("Send now") {
                    Button("Period heads-up") {
                        env.queueAutomaticIMessage(kind: .periodClose)
                    }
                    if env.preferences.experiencesPMS {
                        Button("PMS heads-up") {
                            env.queueAutomaticIMessage(kind: .pmsClose)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .fantasySkyBackground()
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            contactsDraft = env.preferences.iMessageContacts
            enabledDraft = env.preferences.iMessageRemindersEnabled
        }
    }
}
