import SwiftUI

/// Month calendar held by Lumi; tap a day to log it. `header` sits above the card;
/// tapping Lumi calls `onLumiTap`.
struct CalendarView<Header: View>: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    @State private var month = Date.now.startOfDay
    @State private var selectedDate: Date?
    @State private var showPeriodSheet = false
    @State private var showTripPlanner = false

    private let title: String
    private let lumiCelebration: Int
    private let lumiSpeech: LumiSpeech?
    private let onLumiTap: () -> Void
    private let header: Header

    private var calendar: Calendar { .current }
    @ScaledMetric(relativeTo: .body) private var cellHeight: CGFloat = 48

    init(
        title: String,
        lumiCelebration: Int = 0,
        lumiSpeech: LumiSpeech? = nil,
        onLumiTap: @escaping () -> Void,
        @ViewBuilder header: () -> Header
    ) {
        self.title = title
        self.lumiCelebration = lumiCelebration
        self.lumiSpeech = lumiSpeech
        self.onLumiTap = onLumiTap
        self.header = header()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                calendarCard

                footerMeta
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .fantasySkyBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !calendar.isDate(month, equalTo: .now, toGranularity: .month) {
                    Button("Today") {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                            month = Date.now.startOfDay
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.cycleAccentText)
                    .accessibilityHint("Jump to the current month")
                }

                Menu {
                    Button("Log a period", systemImage: "drop.fill") {
                        showPeriodSheet = true
                    }
                    Button("Plan a trip", systemImage: "airplane") {
                        showTripPlanner = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.cycleText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Calendar actions")
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedDate != nil },
            set: { if !$0 { selectedDate = nil } }
        )) {
            if let selectedDate {
                DateDetailView(date: selectedDate)
            }
        }
        .sheet(isPresented: $showTripPlanner) {
            NavigationStack { PlanTripView() }
        }
        .sheet(isPresented: $showPeriodSheet) {
            NavigationStack {
                PeriodLogView(initialDate: month)
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Card

    private var calendarCard: some View {
        let logged = env.todayFeeling
        let forecast = env.feelingForecast
        let shown = logged ?? forecast?.feeling
        return VStack(alignment: .leading, spacing: 16) {
            monthChrome
            VStack(spacing: 4) {
                weekdayHeader
                monthGrid
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: month)
            }
        }
        .padding(.top, 18)
        .padding(.bottom, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.cycleSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.cycleBorder, lineWidth: 1)
        )
        .shadow(color: Color.cycleSage.opacity(0.18), radius: 14, y: 6)
        .lumiHolding(
            feeling: shown,
            phase: env.todaysLune?.phase,
            isGuess: logged == nil && forecast != nil,
            celebration: lumiCelebration,
            speech: lumiSpeech,
            accessibilityLabel: lumiAccessibilityLabel(logged: logged, guess: forecast?.feeling),
            accessibilityHint: logged == nil ? "Log how you feel today" : "Change how you feel today",
            action: onLumiTap
        )
    }

    private func lumiAccessibilityLabel(logged: Feeling?, guess: Feeling?) -> String {
        if let logged {
            return "Lumi. You feel \(logged.displayName.lowercased()) today"
        }
        if let guess {
            return "Lumi's guess: \(guess.displayName.lowercased())"
        }
        return "Lumi"
    }

    // MARK: - Header

    private var monthChrome: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(month.formatted(.dateTime.month(.wide)))
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.cycleText)
                    .contentTransition(.opacity)
                Text(month.formatted(.dateTime.year()))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.cycleSecondary)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                monthStepButton(systemName: "chevron.left", label: "Previous month") {
                    month = calendar.date(byAdding: .month, value: -1, to: month) ?? month
                }
                monthStepButton(systemName: "chevron.right", label: "Next month") {
                    month = calendar.date(byAdding: .month, value: 1, to: month) ?? month
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func monthStepButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                action()
            }
        } label: {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.cycleText)
                .frame(width: 44, height: 44)
                .background(Color.cycleSurface, in: Circle())
                .overlay(Circle().stroke(Color.cycleBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var weekdayHeader: some View {
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        let ordered = Array(symbols[first...] + symbols[..<first])
        return HStack(spacing: 0) {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, symbol in
                Text(symbol.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(Color.cycleSecondary)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
        }
        .padding(.bottom, 4)
        .accessibilityHidden(true)
    }

    // MARK: - Grid

    private var monthGrid: some View {
        let weeks = daysInMonth().chunked(into: 7)
        let outlook = env.cycleOutlook
        return VStack(spacing: 4) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                weekRow(week, outlook: outlook)
            }
        }
    }

    private func weekRow(_ week: [Date?], outlook: CycleOutlook?) -> some View {
        ZStack {
            periodBandLayer(week: week)

            HStack(spacing: 0) {
                ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day, outlook: outlook)
                    } else {
                        Color.clear.frame(maxWidth: .infinity, minHeight: cellHeight)
                    }
                }
            }
        }
        .frame(minHeight: cellHeight)
    }

    /// One continuous capsule per contiguous run of period days in the week (no per-day gaps).
    @ViewBuilder
    private func periodBandLayer(week: [Date?]) -> some View {
        GeometryReader { geo in
            let columnWidth = geo.size.width / 7
            let runs = contiguousPeriodRuns(in: week)
            let fill = Color.cycleCoral.opacity(0.55)

            ForEach(Array(runs.enumerated()), id: \.offset) { _, run in
                let x = CGFloat(run.startIndex) * columnWidth
                let width = CGFloat(run.length) * columnWidth
                Capsule(style: .continuous)
                    .fill(fill)
                    .frame(width: max(0, width - 4), height: cellHeight - 10)
                    .position(
                        x: x + width / 2,
                        y: geo.size.height / 2
                    )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private struct DayRun: Equatable {
        let startIndex: Int
        let length: Int
    }

    private func contiguousPeriodRuns(in week: [Date?]) -> [DayRun] {
        var runs: [DayRun] = []
        var index = 0
        while index < week.count {
            guard let date = week[index], isPeriodDay(date) else {
                index += 1
                continue
            }
            let start = index
            index += 1
            while index < week.count, let next = week[index], isPeriodDay(next) {
                index += 1
            }
            runs.append(DayRun(startIndex: start, length: index - start))
        }
        return runs
    }

    private func isPeriodDay(_ date: Date) -> Bool {
        let status = env.dayStatus(for: date)
        return status == .period || status == .spotting
    }

    private func dayCell(_ date: Date, outlook: CycleOutlook?) -> some View {
        let status = env.dayStatus(for: date)
        let isToday = calendar.isDateInToday(date)
        let isFuture = date.startOfDay > Date().startOfDay
        let planned = isFuture ? outlook?.kind(on: date) : nil
        let isPredicted = (isPredictedDay(date) || planned == .period) && status == .none
        let isOvulation = (env.isEstimatedOvulationDay(date) || planned == .ovulation) && status != .period
        let isPrePeriod = planned == .prePeriod && status == .none

        return Button {
            selectedDate = date
        } label: {
            ZStack {
                if isPrePeriod {
                    Capsule()
                        .fill(Color.cycleCoral.opacity(0.16))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 3)
                }

                if isPredicted && !isOvulation {
                    Capsule()
                        .stroke(
                            Color.cycleCoralStrong,
                            style: StrokeStyle(
                                lineWidth: differentiateWithoutColor ? 2.4 : 1.2,
                                dash: [3, 3]
                            )
                        )
                        .padding(.vertical, 4)
                        .padding(.horizontal, 3)
                }

                if isOvulation {
                    Capsule()
                        .stroke(
                            Color.cycleOvulation.opacity(differentiateWithoutColor ? 1 : 0.85),
                            lineWidth: differentiateWithoutColor ? 2.6 : 1.6
                        )
                        .padding(.vertical, 4)
                        .padding(.horizontal, 3)
                }

                Text("\(calendar.component(.day, from: date))")
                    .font(.body.weight(isToday ? .bold : .medium))
                    .monospacedDigit()
                    .foregroundStyle(dayForeground(
                        status: status,
                        isFuture: isFuture,
                        isToday: isToday,
                        isOvulation: isOvulation
                    ))
                    .frame(maxWidth: .infinity, minHeight: cellHeight)

                VStack {
                    Spacer()
                    markerRow(
                        status: status,
                        isToday: isToday,
                        isOvulation: isOvulation,
                        feeling: env.checkIn(on: date)?.feeling
                    )
                        .padding(.bottom, 5)
                }
                .frame(maxWidth: .infinity, minHeight: cellHeight)
            }
            .frame(maxWidth: .infinity, minHeight: cellHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(
            for: date,
            status: status,
            isPredicted: isPredicted,
            isOvulation: isOvulation,
            isPrePeriod: isPrePeriod,
            isToday: isToday
        ))
        .accessibilityHint(dayAccessibilityHint(isFuture: isFuture))
        .accessibilityAddTraits(isToday ? [.isButton, .isSelected] : .isButton)
    }

    private func dayAccessibilityHint(isFuture: Bool) -> String {
        isFuture ? "Double tap to see predictions" : "Double tap to log this day"
    }

    @ViewBuilder
    private func markerRow(status: CalendarDayStatus, isToday: Bool, isOvulation: Bool, feeling: Feeling?) -> some View {
        HStack(spacing: 3) {
            if isToday {
                Circle()
                    .fill(Color.cycleText)
                    .frame(width: 4, height: 4)
            }
            if isOvulation {
                Diamond()
                    .fill(Color.cycleOvulation)
                    .frame(width: 5, height: 5)
            } else if status == .logged {
                Circle()
                    .fill(feeling.map { LumiPalette.for($0).bodyDark } ?? Color.cycleSage)
                    .frame(width: feeling == nil ? 4 : 6, height: feeling == nil ? 4 : 6)
            } else if status == .spotting {
                Circle()
                    .fill(Color.cycleSecondary.opacity(0.65))
                    .frame(width: 4, height: 4)
            } else {
                Color.clear.frame(width: 4, height: 4)
            }
        }
        .accessibilityHidden(true)
    }

    private func dayForeground(
        status: CalendarDayStatus,
        isFuture: Bool,
        isToday: Bool,
        isOvulation: Bool
    ) -> Color {
        if status == .period || status == .spotting { return Color.cycleText }
        if isOvulation { return Color.cycleSecondary }
        // Full secondary, not faded: future days are tappable, so their numbers need 4.5:1.
        if isFuture { return Color.cycleSecondary }
        if isToday { return Color.cycleText }
        return Color.cycleText
    }

    // MARK: - Footer

    private var footerMeta: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                legendPill(fill: Color.cycleCoral.opacity(0.65), title: "Period")
                legendPill(fill: Color.cycleOvulation, title: "Ovulation")
            }
            HStack(spacing: 16) {
                legendPill(fill: Color.cycleSage, title: "Logged")
                legendOutline(title: "Predicted period")
            }
            legendPill(fill: Color.cycleCoral.opacity(0.3), title: env.preferences.experiencesPMS ? "PMS days" : "Days before period")

            if let prediction = env.prediction {
                if let ovulation = prediction.predictedOvulationDate {
                    Text("Estimated ovulation \(ovulation.formatted(.dateTime.month(.abbreviated).day())) · ~14 days before next period")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.cycleSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Estimated ovulation \(ovulation.formatted(.dateTime.month(.wide).day()))")
                }
                if let date = prediction.predictedDate {
                    Text("Next period likely \(date.formatted(.dateTime.month(.abbreviated).day())) · \(prediction.confidence.displayName.lowercased()) confidence")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.cycleSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Next period likely \(date.formatted(.dateTime.month(.wide).day())), \(prediction.confidence.displayName) confidence")
                }
            }

            Text("Ovulation is an estimate from your cycle length, not a fertility diagnosis.")
                .font(.caption)
                .foregroundStyle(Color.cycleSecondary.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .accessibilityElement(children: .contain)
    }

    private func legendPill(fill: Color, title: String) -> some View {
        HStack(spacing: 7) {
            Capsule().fill(fill).frame(width: 16, height: 8)
                .accessibilityHidden(true)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.cycleSecondary)
        }
        .cycleLegendAccessibility(title)
    }

    private func legendOutline(title: String) -> some View {
        HStack(spacing: 7) {
            Capsule()
                .stroke(Color.cycleCoralStrong, style: StrokeStyle(lineWidth: 1.2, dash: [3, 2]))
                .frame(width: 16, height: 8)
                .accessibilityHidden(true)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.cycleSecondary)
        }
        .cycleLegendAccessibility(title)
    }

    // MARK: - Helpers

    private func isPredictedDay(_ date: Date) -> Bool {
        guard let prediction = env.prediction,
              let lower = prediction.lowerBound,
              let upper = prediction.upperBound else { return false }
        let day = date.startOfDay
        return day >= lower.startOfDay && day <= upper.startOfDay
    }

    private func accessibilityLabel(
        for date: Date,
        status: CalendarDayStatus,
        isPredicted: Bool,
        isOvulation: Bool,
        isPrePeriod: Bool,
        isToday: Bool
    ) -> String {
        var parts = [date.formatted(.dateTime.weekday(.wide).month(.wide).day())]
        if isToday { parts.append("today") }
        switch status {
        case .period: parts.append("period day")
        case .spotting: parts.append("spotting")
        case .logged: parts.append("check-in logged")
        case .none: break
        }
        if isOvulation { parts.append("estimated ovulation") }
        if isPredicted { parts.append("in predicted period window") }
        if isPrePeriod { parts.append(env.preferences.experiencesPMS ? "likely PMS day" : "likely day before your period") }
        return parts.joined(separator: ", ")
    }

    private func daysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else {
            return []
        }

        var days: [Date?] = []
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        for _ in 0..<leading { days.append(nil) }

        var cursor = monthInterval.start
        while cursor < monthInterval.end {
            days.append(cursor)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingDays(1)
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        var result: [[Element]] = []
        var index = startIndex
        while index < endIndex {
            let next = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            result.append(Array(self[index..<next]))
            index = next
        }
        return result
    }
}

/// Small diamond used as the ovulation day marker.
private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

/// One calendar day: how that day sat in your cycle, and (for past days and today) logging
/// a feeling, marking it as a period day, or adding symptoms and a note. Future days show predictions.
struct DateDetailView: View {
    @Environment(AppEnvironment.self) private var env
    let date: Date

    @State private var showPeriodLog = false
    @State private var showCheckIn = false
    @State private var feelingSaves = 0
    @State private var newFlow: FlowIntensity = .medium
    @State private var periodError: String?

    private var isFuture: Bool { date.startOfDay > Date().startOfDay }
    private var checkIn: DailyCheckInRecord? { env.checkIn(on: date) }
    private var savedFeeling: Feeling? { checkIn?.feeling }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(date.formatted(.dateTime.weekday(.wide)))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.cycleSecondary)

                if isFuture {
                    predictionCard
                } else {
                    stateCard
                    periodCard
                    moodCard
                    detailsCard
                }
            }
            .padding(20)
        }
        .fantasySkyBackground()
        .navigationTitle(date.formatted(.dateTime.month(.wide).day()))
        .navigationBarTitleDisplayMode(.large)
        .sensoryFeedback(.success, trigger: feelingSaves)
        .sheet(isPresented: $showPeriodLog) {
            NavigationStack {
                PeriodLogView(initialDate: date)
            }
        }
        .sheet(isPresented: $showCheckIn) {
            NavigationStack {
                QuickCheckInView(initialDate: date)
            }
        }
    }

    // MARK: - State

    private var stateCard: some View {
        let state = env.cycleDayState(on: date)
        return CycleCard {
            HStack(alignment: .center, spacing: 14) {
                LumiView(feeling: savedFeeling, phase: state?.phase, size: 72)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    if let state {
                        Text("Cycle day \(state.cycleDay) · \(state.phase.name)")
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.cycleText)
                    }
                    Text(stateLine(state))
                        .font(.subheadline)
                        .foregroundStyle(Color.cycleSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func stateLine(_ state: CycleDayState?) -> String {
        guard let state else { return "Before your first logged period." }
        if env.flow(on: date) != nil { return "Period day" }
        if state.isPrePeriod {
            return env.preferences.experiencesPMS ? "PMS days" : "A few days before your period"
        }
        switch state.phase {
        case .reset: return "Period days"
        case .bloom: return "Energy building after your period"
        case .glow: return "Around ovulation (an estimate, not a fertility diagnosis)"
        case .slow: return "The slower days before your next period"
        }
    }

    // MARK: - Period

    /// Edit in place: switch a day on or off as a period day and change its flow any time.
    private var periodCard: some View {
        let flow = env.flow(on: date)
        return CycleCard {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { flow != nil },
                    set: { isOn in
                        Task {
                            if isOn {
                                periodError = await env.markPeriodDay(on: date, intensity: newFlow)
                            } else {
                                periodError = nil
                                await env.clearFlow(on: date)
                            }
                        }
                    }
                )) {
                    Label("Period day", systemImage: "drop.fill")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Color.cycleText)
                }
                .tint(Color.cycleCoralStrong)

                Picker("Flow", selection: Binding(
                    get: { flow?.intensity ?? newFlow },
                    set: { intensity in
                        if flow != nil {
                            Task { await env.setFlowIntensity(intensity, on: date) }
                        } else {
                            newFlow = intensity
                        }
                    }
                )) {
                    ForEach(FlowIntensity.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Flow")

                if let periodError {
                    Text(periodError)
                        .font(.footnote)
                        .foregroundStyle(Color.cycleSecondary)
                }

                Button("Log several days at once") { showPeriodLog = true }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.cycleText)
            }
        }
    }

    // MARK: - Mood

    /// Tap a feeling to save it for this day; tap it again to clear it.
    private var moodCard: some View {
        CycleCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Mood")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Color.cycleText)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    if savedFeeling != nil {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.cycleSecondary)
                    }
                }

                FeelingPicker(selection: savedFeeling) { feeling in
                    Task {
                        if feeling == savedFeeling {
                            await env.clearFeeling(on: date)
                        } else {
                            await env.logFeeling(feeling, on: date)
                            feelingSaves += 1
                        }
                    }
                }
            }
        }
    }

    // MARK: - Symptoms & note

    private var detailsCard: some View {
        CycleCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Symptoms & note")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Color.cycleText)
                    .accessibilityAddTraits(.isHeader)

                if let checkIn {
                    if let energy = checkIn.energy {
                        LabeledContent("Energy", value: energy.displayName)
                    }
                    if let sleep = checkIn.sleepQuality {
                        LabeledContent("Sleep", value: sleep.displayName)
                    }
                    if !checkIn.symptoms.isEmpty {
                        Text(checkIn.symptoms.map { "\($0.symptomType.displayName) (\($0.intensity.displayName))" }.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(Color.cycleSecondary)
                    }
                    if let note = checkIn.note, !note.isEmpty {
                        Text(note)
                            .font(.body)
                            .foregroundStyle(Color.cycleText)
                    }
                }

                Button {
                    showCheckIn = true
                } label: {
                    Label(
                        checkIn?.symptoms.isEmpty == false || checkIn?.note?.isEmpty == false
                            ? "Edit symptoms or note" : "Add symptoms or a note",
                        systemImage: "square.and.pencil"
                    )
                }
                .buttonStyle(PrimaryButtonStyle(filled: false))
            }
        }
    }

    /// Future days can't be logged; show what MyLune expects instead.
    private var predictionCard: some View {
        let kind = env.cycleOutlook?.kind(on: date)
        let pms = env.preferences.experiencesPMS
        return CycleCard {
            HStack(alignment: .top, spacing: 12) {
                LumiView(
                    feeling: kind == .ovulation ? .happy : (kind == nil ? .calm : .tired),
                    size: 56,
                    animated: false
                )
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(kind.map { "\(LuneVoice.plannedDayTitle($0, experiencesPMS: pms)) likely" } ?? "Nothing predicted")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.cycleText)
                    Text(kind.map { LuneVoice.tripTip($0, experiencesPMS: pms) } ?? "No period, PMS days or ovulation expected on this day.")
                        .font(.subheadline)
                        .foregroundStyle(Color.cycleSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("This day is still ahead. You can log it when it comes.")
                        .font(.footnote)
                        .foregroundStyle(Color.cycleSecondary)
                        .padding(.top, 2)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
