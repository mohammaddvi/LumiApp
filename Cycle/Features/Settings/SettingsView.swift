import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var exportURL: URL?
    @State private var showExporter = false
    @State private var showDeleteConfirm = false
    @State private var exportError: String?
    @State private var contactsDraft: [MessageContact] = []
    @State private var iMessageEnabledDraft = false
    @State private var showDeleteModelConfirm = false
    @State private var showPremiumPaywall = false

    var body: some View {
        List {
            premiumSection
            appearanceSection
            if env.isPremium {
                localAISection
            }
            privacySection
            notificationsSection
            iMessageSection
            dataSection
            aboutSection
        }
        .scrollContentBackground(.hidden)
        .background(Color.cycleBackground.ignoresSafeArea())
        .navigationTitle("Settings")
        .onAppear {
            contactsDraft = env.preferences.iMessageContacts
            iMessageEnabledDraft = env.preferences.iMessageRemindersEnabled
            env.modelDownloader.refreshInstalledState()
            env.localAI.refreshModelAvailability()
        }
        .sheet(isPresented: $showExporter) {
            if let exportURL {
                ShareSheet(url: exportURL)
            }
        }
        .alert("Delete all health data?", isPresented: $showDeleteConfirm) {
            Button("Delete everything", role: .destructive) {
                Task { await env.deleteAllData() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes cycles, symptoms, notes, and preferences from this device. It cannot be undone.")
        }
        .alert("Export failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .sheet(isPresented: $showPremiumPaywall) {
            PremiumPaywallView()
        }
    }

    private var premiumSection: some View {
        Section {
            if env.isPremium {
                LabeledContent("Plan") {
                    Text("Lune Premium")
                        .foregroundStyle(Color.cycleSage)
                }
                Button("Manage subscription") {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Free plan")
                        .font(.headline)
                        .foregroundStyle(Color.cycleText)
                    Text("Today, calendar, and settings. Upgrade for Ask Lune + Insights.")
                        .font(.footnote)
                        .foregroundStyle(Color.cycleSecondary)
                }
                .padding(.vertical, 4)

                Button("Upgrade to Lune Premium") {
                    showPremiumPaywall = true
                }

                Button("Restore purchases") {
                    Task {
                        await env.premium.restorePurchases()
                        await env.syncPremiumEntitlement()
                    }
                }
            }

            #if DEBUG
            Toggle("Premium (debug)", isOn: Binding(
                get: { PremiumEntitlementStore.debugOverride },
                set: { enabled in
                    Task { await env.setPremiumForTesting(enabled) }
                }
            ))
            #endif
        } header: {
            Text("Lune Premium")
        } footer: {
            if !env.isPremium {
                Text("Premium unlocks Ask Lune (on-device AI) and Insights. Core tracking stays free.")
            }
        }
    }

    private var appearanceSection: some View {
        Section {
            Picker("Appearance", selection: Binding(
                get: { env.preferences.appearanceMode },
                set: { mode in
                    env.setAppearanceMode(mode)
                }
            )) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Appearance")
        } footer: {
            Text("Light keeps the cream palette. System follows your iPhone setting.")
        }
    }

    private var localAISection: some View {
        Section {
            LabeledContent("Engine") {
                Text(env.localAI.status.statusLabel)
                    .foregroundStyle(Color.cycleSage)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Data used") {
                Text("On-device only")
                    .foregroundStyle(Color.cycleSage)
            }

            modelDownloadBlock

            if case .ready = env.modelDownloader.state {
                Button("Load / reload Gemma") {
                    Task { await env.localAI.prepare() }
                }
                Button("Remove model", role: .destructive) {
                    showDeleteModelConfirm = true
                }
            } else if env.modelDownloader.isModelInstalled {
                Button("Load / reload Gemma") {
                    Task { await env.localAI.prepare() }
                }
            }
        } header: {
            Text("Local AI (Gemma 4)")
        } footer: {
            Text("Downloads ~2.6 GB from Hugging Face (litert-community). After that, chat runs fully offline. Accept the Gemma terms on Hugging Face if the download is blocked. Not medical advice.")
        }
        .alert("Remove on-device model?", isPresented: $showDeleteModelConfirm) {
            Button("Remove", role: .destructive) {
                env.modelDownloader.deleteInstalledModel()
                env.localAI.refreshModelAvailability()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes the Gemma weights from this iPhone. Your cycle data is not affected.")
        }
    }

    @ViewBuilder
    private var modelDownloadBlock: some View {
        switch env.modelDownloader.state {
        case .idle:
            Button {
                Task { await downloadAndPrepare() }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Download Gemma 4")
                        .font(.body.weight(.semibold))
                    Text("\(GemmaModelDownloader.formatBytes(GemmaModelDownloader.approximateByteCount)) · Wi‑Fi recommended")
                        .font(.footnote)
                        .foregroundStyle(Color.cycleSecondary)
                }
            }

        case .downloading(let fraction, let written, let expected):
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Downloading model")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.cycleText)
                    Spacer()
                    Text("\(Int((fraction * 100).rounded()))%")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Color.cycleSage)
                }
                ProgressView(value: fraction)
                    .tint(Color.cycleSage)
                    .accessibilityLabel("Download progress")
                    .accessibilityValue("\(Int((fraction * 100).rounded())) percent")
                Text("\(GemmaModelDownloader.formatBytes(written)) of \(GemmaModelDownloader.formatBytes(expected))")
                    .font(.caption)
                    .foregroundStyle(Color.cycleSecondary)
                Button("Cancel download", role: .destructive) {
                    env.modelDownloader.cancel()
                }
            }
            .padding(.vertical, 4)

        case .finishing:
            HStack(spacing: 10) {
                ProgressView()
                Text("Saving model on this device…")
                    .font(.subheadline)
                    .foregroundStyle(Color.cycleSecondary)
            }

        case .ready(let fileName, let byteCount):
            VStack(alignment: .leading, spacing: 4) {
                LabeledContent("Model file") {
                    Text(fileName)
                        .foregroundStyle(Color.cycleSage)
                        .lineLimit(1)
                }
                LabeledContent("Size") {
                    Text(GemmaModelDownloader.formatBytes(byteCount))
                        .foregroundStyle(Color.cycleSecondary)
                }
            }

        case .failed(let message):
            VStack(alignment: .leading, spacing: 10) {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Color.cycleSecondary)
                Button("Try download again") {
                    Task { await downloadAndPrepare() }
                }
                if let url = URL(string: "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm") {
                    Link("Open model page", destination: url)
                        .font(.footnote.weight(.semibold))
                }
            }
        }
    }

    private func downloadAndPrepare() async {
        await env.modelDownloader.startDownload()
        if case .ready = env.modelDownloader.state {
            await env.localAI.prepare()
        } else {
            env.localAI.refreshModelAvailability()
        }
    }

    private var privacySection: some View {
        Section {
            LabeledContent("Storage") {
                Text("On this device")
                    .foregroundStyle(Color.cycleSage)
            }
            LabeledContent("Tracking") {
                Text("None")
                    .foregroundStyle(Color.cycleSage)
            }
            Toggle("App lock", isOn: Binding(
                get: { env.preferences.biometricLockEnabled },
                set: { enabled in
                    Task {
                        var prefs = env.preferences
                        prefs.biometricLockEnabled = enabled
                        if enabled {
                            let ok = await env.appLock.unlock(reason: "Enable app lock for Lune")
                            guard ok else { return }
                        }
                        await env.updatePreferences(prefs)
                    }
                }
            ))
            NavigationLink {
                PrivacyPolicyView()
            } label: {
                Text("Privacy policy")
            }
            Link(destination: URL(string: "mailto:\(LuneLegal.supportEmail)")!) {
                Label("Contact support", systemImage: "envelope")
            }
            Text(LuneLegal.privacySummary)
                .font(.footnote)
                .foregroundStyle(Color.cycleSecondary)
        } header: {
            Text("Privacy center")
        }
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Enable reminders", isOn: Binding(
                get: { env.preferences.notificationsEnabled },
                set: { enabled in
                    Task {
                        var prefs = env.preferences
                        if enabled {
                            let granted = await env.notifications.requestAuthorization()
                            prefs.notificationsEnabled = granted
                            if granted {
                                prefs.periodReminderEnabled = true
                            }
                        } else {
                            prefs.notificationsEnabled = false
                            prefs.periodReminderEnabled = false
                            prefs.pmsReminderEnabled = false
                            prefs.symptomReminderEnabled = false
                            prefs.checkInReminderEnabled = false
                        }
                        await env.updatePreferences(prefs)
                    }
                }
            ))
            Toggle("Period is close", isOn: Binding(
                get: { env.preferences.periodReminderEnabled },
                set: { value in
                    Task {
                        var prefs = env.preferences
                        prefs.periodReminderEnabled = value
                        if value { prefs.notificationsEnabled = true }
                        await env.updatePreferences(prefs)
                    }
                }
            ))
            .disabled(!env.preferences.notificationsEnabled)

            if env.preferences.experiencesPMS {
                Toggle("PMS is close", isOn: Binding(
                    get: { env.preferences.pmsReminderEnabled },
                    set: { value in
                        Task {
                            var prefs = env.preferences
                            prefs.pmsReminderEnabled = value
                            if value { prefs.notificationsEnabled = true }
                            await env.updatePreferences(prefs)
                        }
                    }
                ))
                .disabled(!env.preferences.notificationsEnabled)
            }

            Toggle("Symptoms you might notice", isOn: Binding(
                get: { env.preferences.symptomReminderEnabled },
                set: { value in
                    Task {
                        var prefs = env.preferences
                        prefs.symptomReminderEnabled = value
                        if value { prefs.notificationsEnabled = true }
                        await env.updatePreferences(prefs)
                    }
                }
            ))
            .disabled(!env.preferences.notificationsEnabled)

            Toggle("Daily check-in reminder", isOn: Binding(
                get: { env.preferences.checkInReminderEnabled },
                set: { value in
                    Task {
                        var prefs = env.preferences
                        prefs.checkInReminderEnabled = value
                        await env.updatePreferences(prefs)
                    }
                }
            ))
            .disabled(!env.preferences.notificationsEnabled)
        }
    }

    private var iMessageSection: some View {
        Section {
            IMessageContactsEditor(
                contacts: $contactsDraft,
                enabled: $iMessageEnabledDraft
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)

            Button("Save iMessage contacts") {
                Task {
                    var prefs = env.preferences
                    prefs.iMessageContacts = contactsDraft.filter(\.isValid)
                    prefs.iMessageRemindersEnabled = iMessageEnabledDraft && !prefs.iMessageContacts.isEmpty
                    await env.updatePreferences(prefs)
                    contactsDraft = prefs.iMessageContacts
                    iMessageEnabledDraft = prefs.iMessageRemindersEnabled
                }
            }
            .disabled(
                contactsDraft == env.preferences.iMessageContacts
                    && iMessageEnabledDraft == env.preferences.iMessageRemindersEnabled
            )

            if !env.preferences.iMessageContacts.isEmpty {
                Button("Send period heads-up now") {
                    env.queueAutomaticIMessage(kind: .periodClose)
                }
                if env.preferences.experiencesPMS {
                    Button("Send PMS heads-up now") {
                        env.queueAutomaticIMessage(kind: .pmsClose)
                    }
                }
            }
        } header: {
            Text("iMessage")
        } footer: {
            Text("With automatic reminders on, Lune opens Messages at reminder time with your saved numbers filled in. iOS still requires one tap on Send — apps can’t send iMessage silently.")
        }
    }

    private var dataSection: some View {
        Section("Your data") {
            Button("Export JSON") {
                Task {
                    do {
                        exportURL = try await env.exportJSON()
                        showExporter = true
                    } catch {
                        exportError = "Couldn’t create JSON export."
                    }
                }
            }
            Button("Export CSV") {
                Task {
                    do {
                        exportURL = try await env.exportCSV()
                        showExporter = true
                    } catch {
                        exportError = "Couldn’t create CSV export."
                    }
                }
            }
            Button("Delete all data", role: .destructive) {
                showDeleteConfirm = true
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: AppInfo.marketingVersion)
            LabeledContent("Build", value: AppInfo.buildNumber)
            Text(LuneLegal.medicalDisclaimer)
                .font(.footnote)
                .foregroundStyle(Color.cycleSecondary)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
