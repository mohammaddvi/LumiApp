import SwiftUI
import Charts

struct InsightsView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                cyclesSection
                patternsSection
                trendsSection
                disclaimer
            }
            .padding(20)
            .readableContentWidth()
        }
        .fantasySkyBackground()
        .navigationTitle("Insights")
    }

    private var cyclesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Your cycles", subtitle: "Recent history from this device only.")
            if env.cycleSummaries.isEmpty {
                CycleCard {
                    Text("Log a few periods to see cycle history here.")
                        .foregroundStyle(Color.cycleSecondary)
                }
            } else {
                ForEach(env.cycleSummaries.prefix(8)) { summary in
                    CycleCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(summary.startDate.formatted(.dateTime.month(.wide).day().year()))
                                .font(.headline)
                                .foregroundStyle(Color.cycleText)
                            HStack(spacing: 16) {
                                metric("Cycle", summary.cycleLength.map { "\($0)d" } ?? "Open")
                                metric("Period", summary.periodLength.map { "\($0)d" } ?? "—")
                                metric("Logs", "\(summary.checkInCount)")
                            }
                        }
                    }
                }
            }
        }
    }

    private var patternsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Patterns", subtitle: "Shown only when evidence thresholds are met.")
            if env.insights.isEmpty {
                CycleCard {
                    Text("Keep logging — personal patterns appear after enough comparable cycles.")
                        .foregroundStyle(Color.cycleSecondary)
                }
            } else {
                ForEach(env.insights) { insight in
                    CycleCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(insight.title)
                                .font(.headline)
                                .foregroundStyle(Color.cycleText)
                            Text(insight.body)
                                .font(.subheadline)
                                .foregroundStyle(Color.cycleSecondary)
                            Text(insight.evidence)
                                .font(.footnote)
                                .foregroundStyle(Color.cycleSecondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Trends", subtitle: "Cycle length across recent completed cycles.")
            let data = env.completedCycles.suffix(8)
            if data.count < 2 {
                CycleCard {
                    Text("Trends unlock after a couple of completed cycles.")
                        .foregroundStyle(Color.cycleSecondary)
                }
            } else {
                CycleCard {
                    Chart(Array(data.enumerated()), id: \.offset) { index, cycle in
                        LineMark(
                            x: .value("Cycle", index + 1),
                            y: .value("Days", cycle.lengthDays)
                        )
                        .foregroundStyle(Color.cycleAccentText)
                        PointMark(
                            x: .value("Cycle", index + 1),
                            y: .value("Days", cycle.lengthDays)
                        )
                        .foregroundStyle(Color.cycleAccentText)
                    }
                    .chartYAxisLabel("Days")
                    .frame(height: 180)
                    .accessibilityLabel("Cycle length trend chart")
                }
            }
        }
    }

    private var disclaimer: some View {
        Text("Not a diagnosis. Insights describe patterns in your logged data only.")
            .font(.caption)
            .foregroundStyle(Color.cycleSecondary)
            .padding(.top, 4)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(Color.cycleSecondary)
            Text(value).font(.body.weight(.semibold)).foregroundStyle(Color.cycleText)
        }
    }
}
