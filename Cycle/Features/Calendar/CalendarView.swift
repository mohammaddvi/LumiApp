import SwiftUI

struct CalendarView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    @State private var month = Date.now.startOfDay
    @State private var selectedDate: Date?
    @State private var showPeriodSheet = false
    @State private var isSelectingRange = false
    @State private var rangeStart: Date?
    @State private var rangeEnd: Date?
    @State private var rangeError: String?
    @State private var rangeIntensity: FlowIntensity = .medium

    private var calendar: Calendar { .current }
    @ScaledMetric(relativeTo: .body) private var cellHeight: CGFloat = 48

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                monthChrome
                weekdayHeader
                monthGrid
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: month)

                if isSelectingRange {
                    rangeSelectionBar
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    footerMeta
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color.cycleBackground.ignoresSafeArea())
        .navigationTitle("Calendar")
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
                    .foregroundStyle(Color.cycleSage)
                    .accessibilityHint("Jump to the current month")
                }

                Menu {
                    Button("Add period range", systemImage: "calendar") {
                        showPeriodSheet = true
                    }
                    Button(
                        isSelectingRange ? "Cancel selection" : "Select days on calendar",
                        systemImage: isSelectingRange ? "xmark.circle" : "hand.draw"
                    ) {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                            toggleRangeMode()
                        }
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
        .sheet(isPresented: $showPeriodSheet) {
            NavigationStack {
                PeriodLogView(initialDate: month)
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Couldn’t save period", isPresented: Binding(
            get: { rangeError != nil },
            set: { if !$0 { rangeError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(rangeError ?? "")
        }
    }

    // MARK: - Header

    private var monthChrome: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(month.formatted(.dateTime.month(.wide)))
                    .font(.system(.largeTitle, design: .serif).weight(.medium))
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
        return VStack(spacing: 4) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                weekRow(week)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.cycleSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.cycleBorder, lineWidth: 1)
        )
    }

    private func weekRow(_ week: [Date?]) -> some View {
        ZStack {
            weekBandLayer(week: week, kind: .period)
            weekBandLayer(week: week, kind: .draft)

            HStack(spacing: 0) {
                ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(maxWidth: .infinity, minHeight: cellHeight)
                    }
                }
            }
        }
        .frame(minHeight: cellHeight)
    }

    private enum WeekBandKind {
        case period
        case draft
    }

    /// One continuous capsule per contiguous run in the week (no per-day gaps).
    @ViewBuilder
    private func weekBandLayer(week: [Date?], kind: WeekBandKind) -> some View {
        GeometryReader { geo in
            let columnWidth = geo.size.width / 7
            let runs = contiguousRuns(in: week, kind: kind)
            let fill: Color = {
                switch kind {
                case .period: Color.cycleCoral.opacity(0.55)
                case .draft: Color.cycleAccentSoft
                }
            }()

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

    private func contiguousRuns(in week: [Date?], kind: WeekBandKind) -> [DayRun] {
        var runs: [DayRun] = []
        var index = 0
        while index < week.count {
            guard let date = week[index], dayMatchesBand(date, kind: kind) else {
                index += 1
                continue
            }
            let start = index
            index += 1
            while index < week.count, let next = week[index], dayMatchesBand(next, kind: kind) {
                index += 1
            }
            runs.append(DayRun(startIndex: start, length: index - start))
        }
        return runs
    }

    private func dayMatchesBand(_ date: Date, kind: WeekBandKind) -> Bool {
        switch kind {
        case .draft:
            return isDateInDraftRange(date)
        case .period:
            // Draft overlay replaces period styling while selecting.
            if isSelectingRange, isDateInDraftRange(date) { return false }
            let status = env.dayStatus(for: date)
            return status == .period || status == .spotting
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let status = env.dayStatus(for: date)
        let isToday = calendar.isDateInToday(date)
        let inDraftRange = isDateInDraftRange(date)
        let isFuture = date.startOfDay > Date().startOfDay
        let isPredicted = isPredictedDay(date) && status == .none && !inDraftRange
        let isOvulation = env.isEstimatedOvulationDay(date) && status != .period && !inDraftRange

        return Button {
            handleDayTap(date)
        } label: {
            ZStack {
                if isPredicted && !isOvulation {
                    Capsule()
                        .stroke(
                            Color.cycleOvulation.opacity(differentiateWithoutColor ? 1 : 0.9),
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
                        inDraft: inDraftRange,
                        isFuture: isFuture,
                        isToday: isToday,
                        isOvulation: isOvulation
                    ))
                    .frame(maxWidth: .infinity, minHeight: cellHeight)

                VStack {
                    Spacer()
                    markerRow(status: status, isToday: isToday, isOvulation: isOvulation)
                        .padding(.bottom, 5)
                }
                .frame(maxWidth: .infinity, minHeight: cellHeight)
            }
            .frame(maxWidth: .infinity, minHeight: cellHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSelectingRange && isFuture)
        .opacity(futureDayOpacity(isFuture: isFuture))
        .accessibilityLabel(accessibilityLabel(
            for: date,
            status: status,
            inDraft: inDraftRange,
            isPredicted: isPredicted,
            isOvulation: isOvulation,
            isToday: isToday
        ))
        .accessibilityHint(dayAccessibilityHint(isFuture: isFuture))
        .accessibilityAddTraits(isToday ? [.isButton, .isSelected] : .isButton)
    }

    private func futureDayOpacity(isFuture: Bool) -> Double {
        guard isSelectingRange, isFuture else { return 1 }
        return reduceTransparency ? 1 : 0.32
    }

    private func dayAccessibilityHint(isFuture: Bool) -> String {
        if isSelectingRange {
            return isFuture
                ? "Future dates cannot be selected for a period range"
                : "Double tap to set the start or end of a period range"
        }
        return "Double tap for day details"
    }

    @ViewBuilder
    private func markerRow(status: CalendarDayStatus, isToday: Bool, isOvulation: Bool) -> some View {
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
                    .fill(Color.cycleSage)
                    .frame(width: 4, height: 4)
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
        inDraft: Bool,
        isFuture: Bool,
        isToday: Bool,
        isOvulation: Bool
    ) -> Color {
        if inDraft { return Color.cycleText }
        if status == .period || status == .spotting { return Color.cycleText }
        if isOvulation { return Color.cycleSecondary }
        if isFuture { return Color.cycleSecondary.opacity(reduceTransparency ? 0.72 : 0.5) }
        if isToday { return Color.cycleText }
        return Color.cycleText
    }

    // MARK: - Footer / range

    private var footerMeta: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                legendPill(fill: Color.cycleCoral.opacity(0.65), title: "Period")
                legendPill(fill: Color.cycleOvulation, title: "Ovulation")
            }
            HStack(spacing: 16) {
                legendPill(fill: Color.cycleSage, title: "Logged")
                legendOutline(title: "Predicted")
            }

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

            Text("Ovulation is an estimate from your cycle length, not a fertility diagnosis. Tip: use ··· to mark a period range by tapping start and end days.")
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
                .stroke(Color.cycleOvulation.opacity(0.85), style: StrokeStyle(lineWidth: 1.2, dash: [3, 2]))
                .frame(width: 16, height: 8)
                .accessibilityHidden(true)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.cycleSecondary)
        }
        .cycleLegendAccessibility(title)
    }

    private var rangeSelectionBar: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(rangePrompt)
                .font(.system(.body, design: .serif).weight(.medium))
                .foregroundStyle(Color.cycleText)
                .accessibilityAddTraits(.isHeader)

            if let start = rangeStart {
                let end = rangeEnd ?? start
                let days = end.daysSince(start) + 1
                Text("\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day())) · \(days) day\(days == 1 ? "" : "s")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.cycleSage)
            }

            Picker("Typical flow", selection: $rangeIntensity) {
                ForEach(FlowIntensity.allCases) { level in
                    Text(level.displayName).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Typical flow intensity")

            HStack(spacing: 10) {
                Button("Cancel") {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        toggleRangeMode(forceOff: true)
                    }
                }
                .buttonStyle(PrimaryButtonStyle(filled: false))

                Button("Save period") {
                    Task { await saveDraftRange() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(rangeStart == nil)
                .opacity(rangeStart == nil ? 0.5 : 1)
            }
        }
        .padding(18)
        .background(Color.cycleSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.cycleSage.opacity(0.45), lineWidth: 1.5)
        )
    }

    private var rangePrompt: String {
        if rangeStart == nil {
            return "Tap the first day of your period"
        }
        if rangeEnd == nil {
            return "Tap the last day — or save a single day"
        }
        return "Save this period range?"
    }

    // MARK: - Interactions

    private func toggleRangeMode(forceOff: Bool = false) {
        if forceOff || isSelectingRange {
            isSelectingRange = false
            rangeStart = nil
            rangeEnd = nil
        } else {
            isSelectingRange = true
            rangeStart = nil
            rangeEnd = nil
            selectedDate = nil
        }
    }

    private func handleDayTap(_ date: Date) {
        if isSelectingRange {
            let day = date.startOfDay
            guard day <= Date().startOfDay else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                if rangeStart == nil {
                    rangeStart = day
                    rangeEnd = nil
                } else if let start = rangeStart, rangeEnd == nil {
                    if day < start {
                        rangeEnd = start
                        rangeStart = day
                    } else {
                        rangeEnd = day
                    }
                } else {
                    rangeStart = day
                    rangeEnd = nil
                }
            }
        } else {
            selectedDate = date
        }
    }

    private func saveDraftRange() async {
        guard let start = rangeStart else { return }
        let end = rangeEnd ?? start
        if let message = await env.logPeriodRange(from: start, to: end, intensity: rangeIntensity) {
            rangeError = message
            return
        }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            toggleRangeMode(forceOff: true)
        }
    }

    // MARK: - Helpers

    private func isDateInDraftRange(_ date: Date) -> Bool {
        guard let start = rangeStart else { return false }
        let end = rangeEnd ?? start
        let day = date.startOfDay
        return day >= min(start, end) && day <= max(start, end)
    }

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
        inDraft: Bool,
        isPredicted: Bool,
        isOvulation: Bool,
        isToday: Bool
    ) -> String {
        var parts = [date.formatted(.dateTime.weekday(.wide).month(.wide).day())]
        if isToday { parts.append("today") }
        if inDraft { parts.append("selected for period range") }
        switch status {
        case .period: parts.append("period day")
        case .spotting: parts.append("spotting")
        case .logged: parts.append("check-in logged")
        case .none: break
        }
        if isOvulation { parts.append("estimated ovulation") }
        if isPredicted { parts.append("in predicted period window") }
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

struct DateDetailView: View {
    @Environment(AppEnvironment.self) private var env
    let date: Date

    @State private var showPeriodLog = false
    @State private var showCheckIn = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(date.formatted(.dateTime.weekday(.wide)))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.cycleSecondary)

                if env.isEstimatedOvulationDay(date) {
                    ovulationCard
                }
                periodCard
                checkInCard
            }
            .padding(20)
        }
        .background(Color.cycleBackground.ignoresSafeArea())
        .navigationTitle(date.formatted(.dateTime.month(.wide).day()))
        .navigationBarTitleDisplayMode(.large)
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

    private var ovulationCard: some View {
        CycleCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Estimated ovulation")
                    .font(.system(.title3, design: .serif).weight(.medium))
                    .foregroundStyle(Color.cycleOvulation)
                    .accessibilityAddTraits(.isHeader)
                Text("Based on a typical ~14-day luteal phase before your next period. This is an estimate for awareness only — not a fertility or medical diagnosis.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.cycleSecondary)
            }
        }
    }

    private var periodCard: some View {
        CycleCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Period")
                    .font(.system(.title3, design: .serif).weight(.medium))
                    .foregroundStyle(Color.cycleText)
                    .accessibilityAddTraits(.isHeader)

                if let flow = env.flow(on: date) {
                    LabeledContent("Flow", value: flow.intensity.displayName)
                    LabeledContent("Spotting", value: flow.spotting ? "Yes" : "No")
                    Button("Remove this day", role: .destructive) {
                        Task { await env.clearFlow(on: date) }
                    }
                    .font(.body.weight(.medium))
                } else {
                    Text("Nothing logged for this day.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.cycleSecondary)
                    Button("Log period range") { showPeriodLog = true }
                        .buttonStyle(PrimaryButtonStyle(filled: false))
                }
            }
        }
    }

    private var checkInCard: some View {
        CycleCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Check-in")
                    .font(.system(.title3, design: .serif).weight(.medium))
                    .foregroundStyle(Color.cycleText)
                    .accessibilityAddTraits(.isHeader)

                if let checkIn = env.checkIn(on: date) {
                    if let mood = checkIn.mood {
                        LabeledContent("Mood", value: mood.displayName)
                    }
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
                    Button("Edit check-in") { showCheckIn = true }
                        .buttonStyle(PrimaryButtonStyle(filled: false))
                } else {
                    Text("No check-in yet.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.cycleSecondary)
                    Button("Add check-in") { showCheckIn = true }
                        .buttonStyle(PrimaryButtonStyle(filled: false))
                }
            }
        }
    }
}
