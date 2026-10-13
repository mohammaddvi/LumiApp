import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var exportURL: URL?
    @State private var showExporter = false
    @State private var showDeleteConfirm = false
    @State private var exportError: String?
    @State private var showDeleteModelConfirm = false
    @State private var showPremiumPaywall = false
    /// Which sections are open, remembered on this device (comma-separated `SettingsGroup` raw values).
    @AppStorage("settings.expandedSections") private var expandedSections = ""
    @AppStorage(LumiBabble.enabledKey) private var lumiVoiceEnabled = true
    /// iOS permission for notifications; refreshed on appear and when returning from iOS Settings.
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        List {
            premiumSection
            aiSection
            periodSection
            communicationSection
            appearanceSection
            privacySection
            dataSection
            aboutSection
        }
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .fantasySkyBackground()
        .navigationTitle("Settings")
        .task(id: env.preferences.notificationsEnabled) {
            notificationStatus = await env.notifications.authorizationStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { notificationStatus = await env.notifications.authorizationStatus() }
        }
        .onAppear {
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
            Text("This permanently removes your periods, feelings, symptoms, notes, chats with Lumi, automatic backups and preferences from this device. It cannot be undone.")
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

    private func expansion(_ group: SettingsGroup) -> Binding<Bool> {
        Binding(
            get: { expandedSections.split(separator: ",").contains(Substring(group.rawValue)) },
            set: { isOpen in
                var open = Set(expandedSections.split(separator: ",").map(String.init))
                if isOpen { open.insert(group.rawValue) } else { open.remove(group.rawValue) }
                expandedSections = open.sorted().joined(separator: ",")
            }
        )
    }

    private var premiumSection: some View {
        CollapsibleSection(title: "Lumi Premium", systemImage: "crown.fill", isExpanded: expansion(.premium)) {
            if env.isPremium {
                LabeledContent("Plan") {
                    Text("Lumi Premium")
                        .foregroundStyle(Color.cycleAccentText)
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
                    Text("Today, calendar, and settings. Upgrade for Ask Lumi + Insights.")
                        .font(.footnote)
                        .foregroundStyle(Color.cycleSecondary)
                }
                .padding(.vertical, 4)

                Button("Upgrade to Lumi Premium") {
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
            if !AppStoreScreenshotMode.isEnabled {
                Toggle("Premium (debug)", isOn: Binding(
                    get: { env.debugPremiumOverride },
                    set: { enabled in
                        Task { await env.setPremiumForTesting(enabled) }
                    }
                ))
            }
            #endif
        } footer: {
            if !env.isPremium {
                Text("Premium unlocks Ask Lumi (on-device AI) and Insights. Core tracking stays free.")
            }
        }
    }

    private var appearanceSection: some View {
        CollapsibleSection(title: "Appearance", systemImage: "paintpalette.fill", isExpanded: expansion(.appearance)) {
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

            Toggle(isOn: $lumiVoiceEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lumi's voice")
                    Text("Cute babble when Lumi talks. Follows your silent switch.")
                        .font(.footnote)
                        .foregroundStyle(Color.cycleSecondary)
                }
            }
            .tint(Color.cycleAccentText)
        } footer: {
            Text("Light is lavender mist, Dark is a starry night sky. System follows your iPhone setting.")
        }
    }

    // MARK: - AI

    @ViewBuilder
    private var aiSection: some View {
        if env.isPremium {
            localAISection
        } else {
            CollapsibleSection(title: "AI", systemImage: "sparkles", isExpanded: expansion(.ai)) {
                Label {
                    Text("Ask Lumi anything about your cycle. Answers come from an AI that runs only on this iPhone.")
                        .foregroundStyle(Color.cycleText)
                } icon: {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.cycleAccentText)
                }
                Button("Unlock Ask Lumi") {
                    showPremiumPaywall = true
                }
            } footer: {
                Text("Your cycle data never leaves this device. AI answers are not medical advice.")
            }
        }
    }

    private var localAISection: some View {
        CollapsibleSection(title: "AI", systemImage: "sparkles", isExpanded: expansion(.ai)) {
            LabeledContent("Engine") {
                Text(env.localAI.status.statusLabel)
                    .foregroundStyle(Color.cycleAccentText)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Data used") {
                Text("On-device only")
                    .foregroundStyle(Color.cycleAccentText)
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
                        .foregroundStyle(Color.cycleAccentText)
                }
                ProgressView(value: fraction)
                    .tint(Color.cycleAccentText)
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
                        .foregroundStyle(Color.cycleAccentText)
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
        CollapsibleSection(title: "Privacy", systemImage: "lock.shield.fill", isExpanded: expansion(.privacy)) {
            LabeledContent("Storage") {
                Text("On this device")
                    .foregroundStyle(Color.cycleAccentText)
            }
            LabeledContent("Tracking") {
                Text("None")
                    .foregroundStyle(Color.cycleAccentText)
            }
            Toggle("App lock", isOn: Binding(
                get: { env.preferences.biometricLockEnabled },
                set: { enabled in
                    Task {
                        var prefs = env.preferences
                        prefs.biometricLockEnabled = enabled
                        if enabled {
                            let ok = await env.appLock.unlock(reason: "Enable app lock for Lumi")
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
        }
    }

    // MARK: - Period

    private var periodSection: some View {
        CollapsibleSection(title: "Period", systemImage: "drop.fill", isExpanded: expansion(.period)) {
            if let stats = env.cycleStats {
                LabeledContent("Cycle length", value: "\(stats.typicalCycleLength) days")
                LabeledContent("Difference between cycles") {
                    Text(stats.cycleDifference == 0
                        ? "Same every time"
                        : "\(stats.cycleDifference) days (\(stats.shortestCycle)–\(stats.longestCycle))")
                }
                if let periodLength = stats.typicalPeriodLength {
                    LabeledContent("Period length", value: "\(periodLength) days")
                }
            } else {
                Text("Log a few periods and Lumi will learn your cycle length and how much it changes.")
                    .font(.subheadline)
                    .foregroundStyle(Color.cycleSecondary)
            }

            Toggle("I know my usual cycle length", isOn: Binding(
                get: { env.preferences.typicalCycleLength != nil },
                set: { known in
                    var prefs = env.preferences
                    prefs.typicalCycleLength = known ? (env.cycleStats?.typicalCycleLength ?? 28) : nil
                    Task { await env.updatePreferences(prefs) }
                }
            ))
            .tint(Color.cycleAccentText)

            if let length = env.preferences.typicalCycleLength {
                Stepper(value: Binding(
                    get: { length },
                    set: { value in
                        var prefs = env.preferences
                        prefs.typicalCycleLength = value
                        Task { await env.updatePreferences(prefs) }
                    }
                ), in: 21...45) {
                    Text("Usual cycle: \(length) days")
                }
            }

            Toggle("I get PMS", isOn: Binding(
                get: { env.preferences.experiencesPMS },
                set: { value in
                    var prefs = env.preferences
                    prefs.experiencesPMS = value
                    if !value {
                        prefs.pmsReminderEnabled = false
                        prefs.typicalPMSSymptoms = []
                    }
                    Task { await env.updatePreferences(prefs) }
                }
            ))
            .tint(Color.cycleAccentText)

            NavigationLink {
                PeriodSymptomsView()
            } label: {
                LabeledContent("Usual symptoms") {
                    let count = Set(env.preferences.typicalPeriodSymptoms + env.preferences.typicalPMSSymptoms).count
                    Text(count == 0 ? "None" : "\(count)")
                }
            }
        } footer: {
            Text(periodFooter)
        }
    }

    private var periodFooter: String {
        if let stats = env.cycleStats {
            return "Learned from your last \(stats.cycleCount) \(stats.cycleCount == 1 ? "cycle" : "cycles"). Your usual cycle length is used until there's enough history."
        }
        return "Your usual cycle length is used for predictions until Lumi has enough history."
    }

    // MARK: - Communication

    private var communicationSection: some View {
        CollapsibleSection(title: "Communication", systemImage: "bubble.left.and.bubble.right.fill", isExpanded: expansion(.communication)) {
            if notificationStatus == .denied {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Notifications are turned off for Lumi in iOS Settings, so reminders can’t arrive.", systemImage: "bell.slash.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.cycleText)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .padding(.vertical, 4)
            }

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
            DatePicker(
                "Reminder time",
                selection: Binding(
                    get: {
                        Calendar.current.date(
                            bySettingHour: env.preferences.reminderHour,
                            minute: env.preferences.reminderMinute,
                            second: 0,
                            of: .now
                        ) ?? .now
                    },
                    set: { time in
                        var prefs = env.preferences
                        let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
                        prefs.reminderHour = parts.hour ?? 9
                        prefs.reminderMinute = parts.minute ?? 0
                        Task { await env.updatePreferences(prefs) }
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .disabled(!env.preferences.notificationsEnabled)

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

            NavigationLink {
                MessagesSettingsView()
            } label: {
                LabeledContent("Messages to your people") {
                    let count = env.preferences.iMessageContacts.count
                    Text(count == 0 ? "Off" : "\(count) \(count == 1 ? "person" : "people")")
                }
            }
        } footer: {
            Text("Gentle reminders for you, and optional iMessage heads-ups for people you choose.")
        }
    }

    private var dataSection: some View {
        CollapsibleSection(title: "Your data", systemImage: "tray.full.fill", isExpanded: expansion(.data)) {
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
        CollapsibleSection(title: "About", systemImage: "info.circle.fill", isExpanded: expansion(.about)) {
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

/// The collapsible groups on the Settings screen.
private enum SettingsGroup: String {
    case premium, ai, period, communication, appearance, privacy, data, about
}
