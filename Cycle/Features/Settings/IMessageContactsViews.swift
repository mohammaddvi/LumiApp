import SwiftUI

/// Shared editor for the iMessage recipient list (onboarding + settings).
struct IMessageContactsEditor: View {
    @Binding var contacts: [MessageContact]
    @Binding var enabled: Bool
    var showsEnableToggle: Bool = true

    @State private var draftLabel = ""
    @State private var draftNumber = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsEnableToggle {
                Toggle(isOn: $enabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Automatic iMessage reminders")
                            .foregroundStyle(Color.cycleText)
                        Text("When a period or PMS reminder is due, Lumi opens Messages with your numbers and text filled in.")
                            .font(.footnote)
                            .foregroundStyle(Color.cycleSecondary)
                    }
                }
                .tint(Color.cycleAccentText)
            }

            if enabled || !showsEnableToggle {
                if !contacts.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(contacts) { contact in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(contact.displayName)
                                        .foregroundStyle(Color.cycleText)
                                    if !contact.label.trimmingCharacters(in: .whitespaces).isEmpty {
                                        Text(contact.phoneNumber)
                                            .font(.footnote)
                                            .foregroundStyle(Color.cycleSecondary)
                                    }
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    contacts.removeAll { $0.id == contact.id }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(Color.cycleSecondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove \(contact.displayName)")
                            }
                            .padding(.vertical, 10)

                            if contact.id != contacts.last?.id {
                                Divider().overlay(Color.cycleBorder)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    TextField("Name (optional)", text: $draftLabel)
                        .textContentType(.name)
                        .padding(12)
                        .background(Color.cycleBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    TextField("Phone number", text: $draftNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .padding(12)
                        .background(Color.cycleBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Button {
                        addContact()
                    } label: {
                        Text("Add number")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle(filled: false))
                    .disabled(!canAdd)
                    .opacity(canAdd ? 1 : 0.45)
                }

                Text("Apple doesn’t allow apps to send iMessage completely by themselves. Lumi opens Messages automatically with everything ready — you only tap Send.")
                    .font(.caption)
                    .foregroundStyle(Color.cycleSecondary)
            }
        }
        .padding(16)
        .background(Color.cycleSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.cycleBorder, lineWidth: 1)
        )
        .onChange(of: contacts) { _, newValue in
            if newValue.isEmpty { enabled = false }
        }
        .onChange(of: enabled) { _, isOn in
            if isOn, contacts.isEmpty {
                // keep editor open for adding
            }
        }
    }

    private var canAdd: Bool {
        MessageContact(label: draftLabel, phoneNumber: draftNumber).isValid
    }

    private func addContact() {
        let contact = MessageContact(
            label: draftLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: draftNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        guard contact.isValid else { return }
        contacts.append(contact)
        draftLabel = ""
        draftNumber = ""
        enabled = true
    }
}

struct SendIMessageReminderView: View {
    @Environment(\.dismiss) private var dismiss
    let contacts: [MessageContact]
    var experiencesPMS: Bool

    @State private var selectedIDs: Set<UUID> = []
    @State private var kind: ReminderMessageKind = .periodClose
    @State private var bodyText = ReminderMessageKind.periodClose.defaultBody
    @State private var showComposer = false
    @State private var composerUnavailable = false

    private var availableKinds: [ReminderMessageKind] {
        experiencesPMS ? ReminderMessageKind.allCases : ReminderMessageKind.allCases.filter { $0 != .pmsClose }
    }

    var body: some View {
        Form {
            Section("Recipients") {
                ForEach(contacts.filter(\.isValid)) { contact in
                    Toggle(isOn: Binding(
                        get: { selectedIDs.contains(contact.id) },
                        set: { on in
                            if on { selectedIDs.insert(contact.id) }
                            else { selectedIDs.remove(contact.id) }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.displayName)
                            Text(contact.phoneNumber)
                                .font(.footnote)
                                .foregroundStyle(Color.cycleSecondary)
                        }
                    }
                    .tint(Color.cycleAccentText)
                }
            }

            Section("Message") {
                Picker("Type", selection: $kind) {
                    ForEach(availableKinds) { item in
                        Text(item.title).tag(item)
                    }
                }
                .onChange(of: kind) { _, newValue in
                    bodyText = newValue.defaultBody
                }

                TextField("Message", text: $bodyText, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section {
                Button("Open Messages") {
                    guard MessageComposeView.canSend else {
                        composerUnavailable = true
                        return
                    }
                    showComposer = true
                }
                .disabled(selectedRecipients.isEmpty || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } footer: {
                Text("Messages opens with your recipients and text ready. Nothing is sent until you tap Send.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.cycleBackground)
        .navigationTitle("iMessage reminder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .onAppear {
            selectedIDs = Set(contacts.filter(\.isValid).map(\.id))
            bodyText = kind.defaultBody
        }
        .sheet(isPresented: $showComposer) {
            MessageComposeView(
                recipients: selectedRecipients,
                body: bodyText
            ) { _ in
                showComposer = false
                dismiss()
            }
            .ignoresSafeArea()
        }
        .alert("Messages unavailable", isPresented: $composerUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device can’t send messages right now. Check that iMessage or SMS is set up.")
        }
    }

    private var selectedRecipients: [String] {
        contacts
            .filter { selectedIDs.contains($0.id) && $0.isValid }
            .map(\.normalizedNumber)
    }
}
