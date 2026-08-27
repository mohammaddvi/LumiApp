import Foundation
import SwiftData
import SwiftUI

/// Shared application façade — owns repositories, engines, and derived UI state.
@MainActor
@Observable
final class AppEnvironment {
    let modelContainer: ModelContainer
    let store: CycleDataStore
    let predictionEngine = PredictionEngine()
    let insightEngine = InsightEngine()
    let notifications = NotificationService()
    let appLock = AppLockService()
    let localAI = LocalAIController()
    let modelDownloader = GemmaModelDownloader()
    let premium = PremiumService()

    private(set) var preferences: UserPreferences = .default
    private(set) var cycles: [CycleRecord] = []
    private(set) var recentCheckIns: [DailyCheckInRecord] = []
    private(set) var recentFlows: [FlowEntryRecord] = []
    private(set) var prediction: PredictionResult?
    private(set) var insights: [InsightResult] = []
    private(set) var isLoading = true
    private(set) var lastErrorMessage: String?
    /// When set, UI presents Messages with recipients/body already filled.
    var pendingIMessageDraft: PendingIMessageDraft?

    var isPremium: Bool {
        PremiumEntitlementStore.resolvedEntitlement(storeKitEntitled: premium.hasEntitlement)
    }

    init(container: ModelContainer) {
        self.modelContainer = container
        self.store = CycleDataStore(modelContainer: container)
    }

    static func live() throws -> AppEnvironment {
        let container = try PersistenceController.makeContainer()
        return AppEnvironment(container: container)
    }

    static func preview() -> AppEnvironment {
        let container = try! PersistenceController.makeContainer(inMemory: true)
        return AppEnvironment(container: container)
    }

    // MARK: - Bootstrap

    func bootstrap() async {
        isLoading = true
        defer { isLoading = false }
        do {
            preferences = try await store.load()
            await refresh()
            if preferences.biometricLockEnabled {
                appLock.lock()
            } else {
                appLock.markUnlocked()
            }
            LuneNotificationDelegate.shared.configure(environment: self)
            GemmaModelLocator.ensureDirectories()
            localAI.refreshModelAvailability()
            localAI.dismissVisibleSession()
            modelDownloader.refreshInstalledState()
            await premium.start()
            await syncPremiumEntitlement()
            #if DEBUG
            if AppStoreScreenshotMode.isEnabled {
                await seedAppStoreScreenshotData()
            }
            #endif
        } catch {
            lastErrorMessage = "Couldn’t load local data."
        }
    }

    /// Applies StoreKit entitlement to the local premium cache (not SwiftData).
    func syncPremiumEntitlement() async {
        await premium.refreshEntitlements()
        PremiumEntitlementStore.persist(storeKitEntitled: premium.hasEntitlement)
    }

    #if DEBUG
    func setPremiumForTesting(_ enabled: Bool) async {
        PremiumEntitlementStore.debugOverride = enabled
    }
    #endif

    /// Called from notification delivery / tap to auto-open Messages.
    func handleReminderNotification(id: String, autoPresentMessage: Bool) {
        guard autoPresentMessage else { return }
        guard preferences.iMessageRemindersEnabled else { return }
        guard let kind = LuneNotificationID.messageKind(forNotificationId: id) else { return }
        queueAutomaticIMessage(kind: kind)
    }

    func queueAutomaticIMessage(kind: ReminderMessageKind) {
        let recipients = preferences.iMessageContacts
            .filter(\.isValid)
            .map(\.normalizedNumber)
        guard !recipients.isEmpty else { return }
        guard MessageComposeView.canSend else {
            lastErrorMessage = "Messages isn’t available on this device."
            return
        }

        var resolvedKind = kind
        if kind == .pmsClose, !preferences.experiencesPMS {
            resolvedKind = .periodClose
        }

        pendingIMessageDraft = PendingIMessageDraft(
            kind: resolvedKind,
            recipients: recipients,
            body: resolvedKind.defaultBody
        )
    }

    func clearPendingIMessage() {
        pendingIMessageDraft = nil
    }

    func refresh() async {
        do {
            cycles = try await store.fetchCycles()
            let horizonStart = Date().addingDays(-400)
            let horizonEnd = Date().addingDays(60)
            recentCheckIns = try await store.fetchCheckIns(from: horizonStart, to: horizonEnd)
            recentFlows = try await store.fetchFlowEntries(from: horizonStart, to: horizonEnd)
            recomputeDerivedState()
            await notifications.reschedule(
                preferences: preferences,
                predictedDate: prediction?.predictedDate
            )
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "Couldn’t refresh local data."
        }
    }

    // MARK: - Derived

    var latestCycle: CycleRecord? { cycles.last }

    var currentCycleDay: Int? {
        CycleCalculator.currentCycleDay(latestStart: latestCycle?.startDate)
    }

    var currentPeriodLengthDays: Int {
        guard let cycle = latestCycle else { return LunePhaseEngine.defaultPeriodLength }
        let flows = recentFlows.filter { $0.cycleId == cycle.id }
        if let maxDate = flows.map(\.date).max() {
            return max(1, maxDate.daysSince(cycle.startDate) + 1)
        }
        return cycle.periodDayCount ?? LunePhaseEngine.defaultPeriodLength
    }

    var daysUntilPredictedReset: Int? {
        guard let predicted = prediction?.predictedDate else { return nil }
        return Calendar.current.dateComponents(
            [.day],
            from: Date.now.startOfDay,
            to: predicted.startOfDay
        ).day
    }

    var todaysLune: TodaysLuneSnapshot? {
        LunePhaseEngine.snapshot(
            cycleDay: currentCycleDay,
            periodLengthDays: currentPeriodLengthDays,
            predictedNextReset: prediction?.predictedDate,
            predictedOvulation: prediction?.predictedOvulationDate,
            todayCheckIn: checkIn(on: .now)
        )
    }

    var completedCycles: [CompletedCycle] {
        let starts = cycles.map(\.startDate)
        var periodLengths: [Date: Int] = [:]
        for cycle in cycles {
            let start = cycle.startDate.startOfDay
            let flows = recentFlows.filter { $0.cycleId == cycle.id }
            if let maxDate = flows.map(\.date).max() {
                periodLengths[start] = maxDate.daysSince(start) + 1
            } else if let end = cycle.endDate {
                periodLengths[start] = end.daysSince(start) + 1
            }
        }
        return CycleCalculator.completedCycles(fromStarts: starts, periodLengthsByStart: periodLengths)
    }

    var cycleSummaries: [CycleSummary] {
        let completed = completedCycles
        return cycles.reversed().map { cycle in
            let length = completed.first { $0.startDate.startOfDay == cycle.startDate.startOfDay }?.lengthDays
            let periodLength: Int? = {
                let flows = recentFlows.filter { $0.cycleId == cycle.id }
                if let maxDate = flows.map(\.date).max() {
                    return maxDate.daysSince(cycle.startDate) + 1
                }
                return cycle.periodDayCount
            }()
            let nextStart = cycles.first { $0.startDate > cycle.startDate }?.startDate ?? Date().addingDays(1)
            let checkInCount = recentCheckIns.filter {
                $0.date.startOfDay >= cycle.startDate.startOfDay && $0.date.startOfDay < nextStart.startOfDay
            }.count
            return CycleSummary(
                id: cycle.id,
                startDate: cycle.startDate,
                cycleLength: length,
                periodLength: periodLength,
                checkInCount: checkInCount,
                isComplete: length != nil
            )
        }
    }

    private func recomputeDerivedState() {
        prediction = predictionEngine.predict(
            completedCycles: completedCycles,
            currentCycleStart: latestCycle?.startDate,
            typicalCycleLength: preferences.typicalCycleLength
        )
        insights = insightEngine.generate(
            completedCycles: completedCycles,
            checkIns: recentCheckIns,
            cycleStarts: cycles.map(\.startDate)
        )
    }

    // MARK: - Onboarding

    func completeOnboarding(_ profile: OnboardingProfile) async {
        let now = Date.now
        let cycle = CycleRecord(
            id: UUID(),
            startDate: profile.lastPeriodStart.startOfDay,
            endDate: nil,
            source: .onboarding,
            createdAt: now,
            updatedAt: now
        )
        do {
            try await store.upsertCycle(cycle)
            // Seed a few period days for the starting cycle
            for offset in 0..<5 {
                let day = profile.lastPeriodStart.addingDays(offset)
                guard day.startOfDay <= now.startOfDay else { break }
                try await store.upsertFlowEntry(
                    FlowEntryRecord(
                        id: UUID(),
                        date: day,
                        intensity: offset == 0 ? .medium : .light,
                        spotting: false,
                        cycleId: cycle.id
                    )
                )
            }

            let wantsAnyReminder =
                profile.remindPeriodClose || profile.remindPMSClose || profile.remindSymptoms

            var prefs = preferences
            prefs.hasCompletedOnboarding = true
            prefs.typicalCycleLength = profile.typicalCycleLength
            prefs.experiencesPMS = profile.experiencesPMS
            prefs.typicalPeriodSymptoms = profile.periodSymptoms
            prefs.typicalPMSSymptoms = profile.experiencesPMS ? profile.pmsSymptoms : []
            prefs.notificationsEnabled = wantsAnyReminder
            prefs.periodReminderEnabled = profile.remindPeriodClose
            prefs.pmsReminderEnabled = profile.remindPMSClose && profile.experiencesPMS
            prefs.symptomReminderEnabled = profile.remindSymptoms
            prefs.checkInReminderEnabled = false
            prefs.iMessageContacts = profile.iMessageContacts.filter(\.isValid)
            prefs.iMessageRemindersEnabled = profile.iMessageRemindersEnabled && !prefs.iMessageContacts.isEmpty

            if wantsAnyReminder {
                let granted = await notifications.requestAuthorization()
                prefs.notificationsEnabled = granted
                if !granted {
                    prefs.periodReminderEnabled = false
                    prefs.pmsReminderEnabled = false
                    prefs.symptomReminderEnabled = false
                }
            }

            try await store.save(prefs)
            preferences = prefs
            await refresh()
        } catch {
            lastErrorMessage = "Couldn’t finish onboarding."
        }
    }

    // MARK: - Period logging

    /// Logs a full period span from start through end (inclusive), creating flow days and cycle bounds.
    func logPeriodRange(
        from start: Date,
        to end: Date,
        intensity: FlowIntensity = .medium,
        spotting: Bool = false
    ) async -> String? {
        let startDay = min(start.startOfDay, end.startOfDay)
        let endDay = max(start.startOfDay, end.startOfDay)
        guard endDay <= Date().startOfDay else {
            return "Period days can’t be in the future."
        }

        let existingRanges: [(start: Date, end: Date?)] = cycles.map { cycle in
            let flowEnd = recentFlows
                .filter { $0.cycleId == cycle.id }
                .map(\.date)
                .max()
            return (cycle.startDate, cycle.endDate ?? flowEnd)
        }

        if CycleCalculator.overlapsExistingPeriod(
            proposedStart: startDay,
            proposedEnd: endDay,
            existing: existingRanges
        ) {
            return "That range overlaps an existing period. Edit those days from the calendar instead."
        }

        // Close previous open cycle if this starts a new one after it
        if var previous = cycles.last, previous.endDate == nil, previous.startDate.startOfDay < startDay {
            let dayBefore = startDay.addingDays(-1)
            if dayBefore >= previous.startDate {
                previous.endDate = dayBefore
                previous.updatedAt = .now
                do { try await store.upsertCycle(previous) } catch {
                    return "Couldn’t update previous cycle."
                }
            }
        }

        let cycle = CycleRecord(
            id: UUID(),
            startDate: startDay,
            endDate: endDay,
            source: .user,
            createdAt: .now,
            updatedAt: .now
        )

        do {
            try await store.upsertCycle(cycle)
            var cursor = startDay
            var dayIndex = 0
            while cursor <= endDay {
                let dayIntensity: FlowIntensity = {
                    if spotting { return .light }
                    // Soft taper: first/last lighter when range is long enough
                    let total = endDay.daysSince(startDay) + 1
                    if total >= 4, dayIndex == 0 || dayIndex == total - 1 { return .light }
                    if total >= 5, dayIndex == 1 { return intensity }
                    return intensity
                }()
                try await store.upsertFlowEntry(
                    FlowEntryRecord(
                        id: UUID(),
                        date: cursor,
                        intensity: dayIntensity,
                        spotting: spotting && dayIndex == 0,
                        cycleId: cycle.id
                    )
                )
                cursor = cursor.addingDays(1)
                dayIndex += 1
            }
            await refresh()
            return nil
        } catch {
            return "Couldn’t save period range."
        }
    }

    func startPeriod(on date: Date, intensity: FlowIntensity, spotting: Bool) async -> String? {
        await logPeriodRange(from: date, to: date, intensity: intensity, spotting: spotting)
    }

    func logFlow(on date: Date, intensity: FlowIntensity, spotting: Bool, cycleId: UUID? = nil) async -> String? {
        let day = date.startOfDay
        let resolvedCycleId: UUID
        if let cycleId {
            resolvedCycleId = cycleId
        } else if let containing = cycles.last(where: { $0.startDate.startOfDay <= day }) {
            resolvedCycleId = containing.id
        } else {
            return await startPeriod(on: day, intensity: intensity, spotting: spotting)
        }

        do {
            try await store.upsertFlowEntry(
                FlowEntryRecord(id: UUID(), date: day, intensity: intensity, spotting: spotting, cycleId: resolvedCycleId)
            )
            await refresh()
            return nil
        } catch {
            return "Couldn’t save flow."
        }
    }

    func clearFlow(on date: Date) async {
        do {
            try await store.deleteFlowEntries(on: date)
            await refresh()
        } catch {
            lastErrorMessage = "Couldn’t remove flow entry."
        }
    }

    func endPeriod(on date: Date) async {
        guard var latest = cycles.last else { return }
        latest.endDate = date.startOfDay
        latest.updatedAt = .now
        do {
            try await store.upsertCycle(latest)
            await refresh()
        } catch {
            lastErrorMessage = "Couldn’t end period."
        }
    }

    // MARK: - Check-in

    func saveCheckIn(_ checkIn: DailyCheckInRecord) async {
        do {
            try await store.upsertCheckIn(checkIn)
            await refresh()
        } catch {
            lastErrorMessage = "Couldn’t save check-in."
        }
    }

    func checkIn(on date: Date) -> DailyCheckInRecord? {
        recentCheckIns.first { $0.date.startOfDay == date.startOfDay }
    }

    func flow(on date: Date) -> FlowEntryRecord? {
        recentFlows.first { $0.date.startOfDay == date.startOfDay }
    }

    // MARK: - Preferences / privacy

    func updatePreferences(_ prefs: UserPreferences) async {
        // Apply immediately so toggles/pickers feel instant.
        let previous = preferences
        preferences = prefs
        if !prefs.biometricLockEnabled {
            appLock.markUnlocked()
        }

        do {
            try await store.save(prefs)
            let notificationsChanged =
                previous.notificationsEnabled != prefs.notificationsEnabled
                || previous.periodReminderEnabled != prefs.periodReminderEnabled
                || previous.pmsReminderEnabled != prefs.pmsReminderEnabled
                || previous.symptomReminderEnabled != prefs.symptomReminderEnabled
                || previous.checkInReminderEnabled != prefs.checkInReminderEnabled
                || previous.reminderHour != prefs.reminderHour
                || previous.reminderMinute != prefs.reminderMinute
                || previous.experiencesPMS != prefs.experiencesPMS
                || previous.typicalPeriodSymptoms != prefs.typicalPeriodSymptoms
                || previous.typicalPMSSymptoms != prefs.typicalPMSSymptoms
                || previous.iMessageRemindersEnabled != prefs.iMessageRemindersEnabled
                || previous.iMessageContacts != prefs.iMessageContacts

            if notificationsChanged {
                await notifications.reschedule(preferences: prefs, predictedDate: prediction?.predictedDate)
            }
        } catch {
            preferences = previous
            lastErrorMessage = "Couldn’t save settings."
        }
    }

    func setAppearanceMode(_ mode: AppearanceMode) {
        guard preferences.appearanceMode != mode else { return }
        var prefs = preferences
        prefs.appearanceMode = mode
        preferences = prefs
        Task {
            do {
                try await store.save(prefs)
            } catch {
                lastErrorMessage = "Couldn’t save appearance."
            }
        }
    }

    func exportJSON() async throws -> URL {
        let snapshot = try await store.exportSnapshot()
        return try ExportService.makeJSONURL(from: snapshot)
    }

    func exportCSV() async throws -> URL {
        let snapshot = try await store.exportSnapshot()
        return try ExportService.makeCSVURL(from: snapshot)
    }

    func deleteAllData() async {
        do {
            try await store.deleteAllHealthData()
            preferences = .default
            cycles = []
            recentCheckIns = []
            recentFlows = []
            prediction = nil
            insights = []
            localAI.clearChat()
            await notifications.reschedule(preferences: preferences, predictedDate: nil)
        } catch {
            lastErrorMessage = "Couldn’t delete local data."
        }
    }

    // MARK: - Calendar helpers

    func dayStatus(for date: Date) -> CalendarDayStatus {
        let day = date.startOfDay
        if let flow = flow(on: day) {
            return flow.spotting && flow.intensity == .light ? .spotting : .period
        }
        if checkIn(on: day) != nil {
            return .logged
        }
        return .none
    }

    /// Estimated ovulation dates from completed cycles plus the current-cycle prediction.
    var estimatedOvulationDates: Set<Date> {
        var dates = Set<Date>()
        for cycle in completedCycles {
            if let ovulation = CycleCalculator.estimatedOvulationDate(
                cycleStart: cycle.startDate,
                cycleLengthDays: cycle.lengthDays
            ) {
                dates.insert(ovulation.startOfDay)
            }
        }
        if let ovulation = prediction?.predictedOvulationDate {
            dates.insert(ovulation.startOfDay)
        }
        return dates
    }

    func isEstimatedOvulationDay(_ date: Date) -> Bool {
        estimatedOvulationDates.contains(date.startOfDay)
    }

    #if DEBUG
    /// Demo cycle history + premium for App Store screenshots / preview recording.
    func seedAppStoreScreenshotData() async {
        await deleteAllData()
        PremiumEntitlementStore.debugOverride = true

        var prefs = UserPreferences.default
        prefs.hasCompletedOnboarding = true
        prefs.typicalCycleLength = 28
        prefs.experiencesPMS = true
        prefs.typicalPeriodSymptoms = [.cramps, .fatigue]
        prefs.typicalPMSSymptoms = [.cramps, .bloating, .mood]
        prefs.appearanceMode = .light
        prefs.biometricLockEnabled = false
        do {
            try await store.save(prefs)
            preferences = prefs
        } catch {
            lastErrorMessage = "Couldn’t seed screenshot preferences."
            return
        }

        // Log completed periods via the real logging path (28-day spacing).
        let now = Date().startOfDay
        let startsDaysAgo = [168, 140, 112, 84, 56, 28, 5]
        for (index, daysAgo) in startsDaysAgo.enumerated() {
            let start = now.addingDays(-daysAgo)
            let isCurrent = index == startsDaysAgo.count - 1
            let end = isCurrent ? start.addingDays(2) : start.addingDays(4)
            if let message = await logPeriodRange(from: start, to: end, intensity: .medium) {
                lastErrorMessage = message
                return
            }

            if !isCurrent, index + 1 < startsDaysAgo.count {
                let nextStart = now.addingDays(-startsDaysAgo[index + 1])
                for before in 1...3 {
                    let day = nextStart.addingDays(-before)
                    do {
                        try await store.upsertCheckIn(
                            DailyCheckInRecord(
                                id: UUID(),
                                date: day,
                                mood: before == 1 ? .low : .okay,
                                energy: before == 1 ? .drained : .low,
                                sleepQuality: .fair,
                                symptoms: [
                                    SymptomOccurrence(symptomType: .cramps, intensity: .moderate),
                                    SymptomOccurrence(
                                        symptomType: .bloating,
                                        intensity: before == 1 ? .strong : .mild
                                    ),
                                ],
                                note: before == 1 ? "soft day — need a rest" : nil
                            )
                        )
                    } catch {
                        lastErrorMessage = "Couldn’t seed screenshot check-ins."
                        return
                    }
                }
            }
        }

        do {
            try await store.upsertCheckIn(
                DailyCheckInRecord(
                    id: UUID(),
                    date: now,
                    mood: .good,
                    energy: .steady,
                    sleepQuality: .good,
                    symptoms: [],
                    note: "feeling like me again"
                )
            )
        } catch {
            lastErrorMessage = "Couldn’t seed today’s check-in."
            return
        }

        localAI.seedDemoConversationForScreenshots()
        await refresh()
    }
    #endif
}
