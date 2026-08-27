import SwiftUI
import SwiftData

@main
struct CycleApp: App {
    @State private var environment: AppEnvironment?
    @State private var persistenceFailure: PersistenceFailure?
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let launch = Self.initialLaunchState()
        _environment = State(initialValue: launch.environment)
        _persistenceFailure = State(initialValue: launch.failure)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let environment {
                    RootView()
                        .environment(environment)
                        .modelContainer(environment.modelContainer)
                        .preferredColorScheme(environment.preferences.appearanceMode.preferredColorScheme)
                        .transaction { $0.animation = nil }
                        .task {
                            await environment.bootstrap()
                        }
                } else if let persistenceFailure {
                    DataStoreRecoveryView(failure: persistenceFailure, onRetry: retryLaunch)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .background, let environment else { return }
                if environment.preferences.biometricLockEnabled {
                    environment.appLock.lock()
                }
                environment.localAI.dismissVisibleSession()
                try? environment.modelContainer.mainContext.save()
            }
        }
    }

    private func retryLaunch() {
        let launch = Self.initialLaunchState()
        environment = launch.environment
        persistenceFailure = launch.failure
    }

    private static func initialLaunchState() -> (environment: AppEnvironment?, failure: PersistenceFailure?) {
        do {
            return (try AppEnvironment.live(), nil)
        } catch let failure as PersistenceFailure {
            return (nil, failure)
        } catch {
            return (
                nil,
                PersistenceFailure.openFailed(
                    message: "MyLune couldn’t open your local cycle database.",
                    backupAvailable: StoreBackupService.hasAnyBackup()
                )
            )
        }
    }
}

struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var splashVisible = true

    var body: some View {
        ZStack {
            mainContent
                .opacity(splashVisible ? 0 : 1)

            if splashVisible {
                LuneSplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.45), value: splashVisible)
        .task {
            await dismissSplashWhenReady()
        }
        .sheet(item: Binding(
            get: { env.pendingIMessageDraft },
            set: { env.pendingIMessageDraft = $0 }
        )) { draft in
            MessageComposeView(
                recipients: draft.recipients,
                body: draft.body
            ) { _ in
                env.clearPendingIMessage()
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        Group {
            if !env.preferences.hasCompletedOnboarding {
                OnboardingFlowView()
            } else if env.preferences.biometricLockEnabled && !env.appLock.isUnlocked {
                AppLockView()
            } else {
                MainTabView()
            }
        }
    }

    /// Keeps the splash up long enough to read — at least `LuneSplashTiming.minimumDuration`
    /// even when bootstrap finishes instantly.
    private func dismissSplashWhenReady() async {
        #if DEBUG
        if AppStoreScreenshotMode.isEnabled, AppStoreScreenshotMode.screen == .splash {
            // Hold splash indefinitely for the splash screenshot.
            return
        }
        #endif

        let started = ContinuousClock.now

        while env.isLoading {
            try? await Task.sleep(for: .milliseconds(50))
        }

        let elapsed = started.duration(to: .now)
        #if DEBUG
        let minimum: Duration = AppStoreScreenshotMode.isEnabled ? .milliseconds(400) : LuneSplashTiming.minimumDuration
        #else
        let minimum = LuneSplashTiming.minimumDuration
        #endif
        let remaining = minimum - elapsed
        if remaining > .zero {
            try? await Task.sleep(for: remaining)
        }

        splashVisible = false
    }
}

struct AppLockView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        ZStack {
            Color.cycleBackground.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.cycleSage)
                    .accessibilityHidden(true)
                Text("MyLune is locked")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.cycleText)
                Text("Use \(env.appLock.biometryLabel) or your device passcode to open your health data.")
                    .font(.body)
                    .foregroundStyle(Color.cycleSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button("Unlock") {
                    Task { _ = await env.appLock.unlock() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }
        }
        .task {
            _ = await env.appLock.unlock()
        }
    }
}

struct MainTabView: View {
    @Environment(AppEnvironment.self) private var env
    #if DEBUG
    @State private var selectedTab: AppStoreScreenshotMode.Screen = AppStoreScreenshotMode.isEnabled
        ? AppStoreScreenshotMode.screen
        : .today
    #endif

    var body: some View {
        #if DEBUG
        if AppStoreScreenshotMode.isEnabled {
            screenshotTabView
        } else {
            standardTabView
        }
        #else
        standardTabView
        #endif
    }

    private var standardTabView: some View {
        TabView {
            Tab("Today", systemImage: LuneSymbolName.moon) {
                NavigationStack { TodayView() }
            }
            Tab("Calendar", systemImage: "calendar") {
                NavigationStack { CalendarView() }
            }
            if env.isPremium {
                Tab("Ask", systemImage: "sparkles") {
                    NavigationStack { AskLuneView(ai: env.localAI) }
                }
                Tab("Insights", systemImage: "chart.line.uptrend.xyaxis") {
                    NavigationStack { InsightsView() }
                }
            }
            Tab("Settings", systemImage: "gearshape") {
                NavigationStack { SettingsView() }
            }
        }
        .tint(Color.cycleSage)
        .id(env.isPremium)
    }

    #if DEBUG
    private var screenshotTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: LuneSymbolName.moon, value: .today) {
                NavigationStack { TodayView() }
            }
            Tab("Calendar", systemImage: "calendar", value: .calendar) {
                NavigationStack { CalendarView() }
            }
            Tab("Ask", systemImage: "sparkles", value: .ask) {
                NavigationStack { AskLuneView(ai: env.localAI) }
            }
            Tab("Insights", systemImage: "chart.line.uptrend.xyaxis", value: .insights) {
                NavigationStack { InsightsView() }
            }
            Tab("Settings", systemImage: "gearshape", value: .settings) {
                NavigationStack { SettingsView() }
            }
        }
        .tint(Color.cycleSage)
        .onAppear {
            if selectedTab == .splash {
                selectedTab = .today
            }
        }
    }
    #endif
}
