import SwiftUI

/// Insights, Lumi style: your rhythm at a glance, cycles as bars and what Lumi noticed.
/// Short and visual on purpose: no charts to decode, no walls of text.
struct InsightsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The cycle bar tapped open to show its dates.
    @State private var openCycle: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                rhythmCard
                cyclesCard
                noticedCard
                Text("From your logs only, not a diagnosis.")
                    .font(.caption)
                    .foregroundStyle(Color.cycleSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 2)
            }
            .padding(20)
            .readableContentWidth()
        }
        .fantasySkyBackground()
        .navigationTitle("Insights")
        .sensoryFeedback(.selection, trigger: openCycle)
    }

    // MARK: - Your rhythm

    private var rhythmCard: some View {
        CycleCard {
            HStack(spacing: 16) {
                LumiView(feeling: env.todayFeeling, phase: env.todaysLune?.phase, size: 84)
                    .accessibilityHidden(true)
                if let stats = env.cycleStats {
                    VStack(alignment: .leading, spacing: 10) {
                        cardTitle("Your rhythm")
                        HStack(alignment: .firstTextBaseline, spacing: 18) {
                            bigStat("\(stats.typicalCycleLength)", "day cycle")
                            if let period = stats.typicalPeriodLength {
                                bigStat("\(period)", "day period")
                            }
                        }
                        Text(InsightsDisplay.vibe(for: stats))
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.cycleText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.cycleAccentSoft, in: Capsule())
                    }
                    .accessibilityElement(children: .combine)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        cardTitle("Your rhythm")
                        Text("Log a couple of periods and I'll spot your rhythm 🌙")
                            .font(.subheadline)
                            .foregroundStyle(Color.cycleSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func bigStat(_ value: String, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color.cycleText)
            Text(label)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(Color.cycleSecondary)
        }
    }

    // MARK: - Your cycles

    private var cyclesCard: some View {
        let summaries = Array(env.cycleSummaries.prefix(6))
        let lengths = summaries.map(length(of:))
        let scale = Double(max(35, lengths.max() ?? 0))
        return CycleCard {
            VStack(alignment: .leading, spacing: 12) {
                cardTitle("Your cycles")
                if summaries.isEmpty {
                    Text("Your cycles show up here once you log a period 🌸")
                        .font(.subheadline)
                        .foregroundStyle(Color.cycleSecondary)
                } else {
                    ForEach(Array(zip(summaries, lengths)), id: \.0.id) { summary, length in
                        VStack(alignment: .leading, spacing: 8) {
                            cycleBar(summary, length: length, scale: scale)
                            if openCycle == summary.id {
                                cycleDates(summary)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                    HStack(spacing: 14) {
                        legendDot(Color.cycleCoral, "Period")
                        legendDot(Color.cycleSage.opacity(0.55), "Rest of cycle")
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    /// Completed cycles use their length; the current one counts days so far.
    private func length(of summary: CycleSummary) -> Int {
        summary.cycleLength ?? max(1, Date.now.daysSince(summary.startDate) + 1)
    }

    private func cycleBar(_ summary: CycleSummary, length: Int, scale: Double) -> some View {
        let isCurrent = summary.cycleLength == nil
        let period = min(summary.periodLength ?? 0, length)
        let isOpen = openCycle == summary.id
        return Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
                openCycle = isOpen ? nil : summary.id
            }
        } label: {
            HStack(spacing: 10) {
                Text(summary.startDate.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.cycleSecondary)
                    .frame(width: 52, alignment: .leading)
                GeometryReader { proxy in
                    let width = proxy.size.width * Double(length) / scale
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.cycleSage.opacity(isCurrent ? 0.3 : 0.55))
                            .frame(width: width)
                        Capsule()
                            .fill(Color.cycleCoral)
                            .frame(width: width * Double(period) / Double(length))
                    }
                }
                .frame(height: 14)
                Text(isCurrent ? "now" : "\(length)d")
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .foregroundStyle(isCurrent ? Color.cycleAccentText : Color.cycleText)
                    .frame(width: 40, alignment: .trailing)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cycleLabel(summary, length: length, isCurrent: isCurrent, period: period))
        .accessibilityHint(isOpen ? "Double tap to hide dates" : "Double tap to show dates")
        .accessibilityAddTraits(.isButton)
    }

    /// Period and cycle dates under an opened bar.
    private func cycleDates(_ summary: CycleSummary) -> some View {
        let dates = InsightsDisplay.dates(
            for: summary,
            nextPeriod: summary.cycleLength == nil ? env.prediction?.predictedDate : nil
        )
        return VStack(alignment: .leading, spacing: 6) {
            if let period = dates.period {
                dateRow("🌸", "Period", period)
            }
            dateRow("🌙", "Cycle", dates.cycle)
            if let next = dates.nextPeriod {
                dateRow("🔮", "Next period", next)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cycleAccentSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func dateRow(_ emoji: String, _ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(emoji)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.cycleText)
                .frame(minWidth: 88, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Color.cycleSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func cycleLabel(_ summary: CycleSummary, length: Int, isCurrent: Bool, period: Int) -> String {
        let start = summary.startDate.formatted(.dateTime.month(.wide).day())
        let periodText = period > 0 ? ", period \(period) days" : ""
        return isCurrent
            ? "Current cycle from \(start), day \(length)\(periodText)"
            : "Cycle from \(start), \(length) days\(periodText)"
    }

    private func legendDot(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 6) {
            Capsule().fill(color).frame(width: 14, height: 8)
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.cycleSecondary)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Lumi noticed

    private var noticedCard: some View {
        let notices = InsightsDisplay.notices(from: env.insights)
        return CycleCard {
            VStack(alignment: .leading, spacing: 14) {
                cardTitle("Lumi noticed ✨")
                if notices.isEmpty {
                    Text("Still learning your patterns 🔮 Keep logging and I'll tell you what I spot.")
                        .font(.subheadline)
                        .foregroundStyle(Color.cycleSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(notices) { notice in
                        noticeRow(notice)
                    }
                }
            }
        }
    }

    private func noticeRow(_ notice: LumiNotice) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(notice.emoji)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Color.cycleAccentSoft, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(notice.name)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.cycleText)
                Text(notice.detail)
                    .font(.footnote)
                    .foregroundStyle(Color.cycleSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if let hits = notice.hits, let outOf = notice.outOf {
                // Plain words, not dots: nothing to learn.
                Text("\(hits) of \(outOf) cycles")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.cycleAccentText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.cycleAccentSoft, in: Capsule())
                    .fixedSize()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(for: notice))
    }

    private func accessibilityText(for notice: LumiNotice) -> String {
        var text = "\(notice.name), \(notice.detail)"
        if let hits = notice.hits, let outOf = notice.outOf {
            text += ", in \(hits) of your last \(outOf) cycles"
        }
        return text
    }

    private func cardTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(Color.cycleText)
            .accessibilityAddTraits(.isHeader)
    }
}
