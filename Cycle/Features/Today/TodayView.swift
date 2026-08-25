import SwiftUI

struct TodayView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var showPeriodLog = false
    @State private var showCheckIn = false
    @State private var showPremiumPaywall = false

    private var dateText: String {
        Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var todayCheckIn: DailyCheckInRecord? {
        env.checkIn(on: .now)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let lune = env.todaysLune {
                    TodaysLuneCard(
                        snapshot: lune,
                        dateText: dateText
                    )
                } else {
                    welcomeCard
                }
                resetPredictionCard
                quickCheckInCard
                if env.isPremium {
                    insightCard
                } else {
                    premiumInsightTeaser
                }
            }
            .padding(20)
            .padding(.bottom, 72)
        }
        .background(Color.cycleBackground.ignoresSafeArea())
        .navigationTitle("Today")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showPeriodLog = true
                } label: {
                    Label("Log reset", systemImage: "plus.circle.fill")
                }
                .accessibilityLabel("Log reset")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                showPeriodLog = true
            } label: {
                LuneMoonButtonLabel(title: "Log reset")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .background(Color.cycleSurface)
        }
        .sheet(isPresented: $showPeriodLog) {
            NavigationStack { PeriodLogView() }
        }
        .sheet(isPresented: $showCheckIn) {
            NavigationStack { QuickCheckInView() }
        }
        .sheet(isPresented: $showPremiumPaywall) {
            PremiumPaywallView()
        }
    }

    private var welcomeCard: some View {
        CycleCard {
            VStack(alignment: .leading, spacing: 10) {
                Label {
                    Text("hey. your cycle diary.")
                        .font(.system(.title2, design: .serif).weight(.medium))
                        .foregroundStyle(Color.cycleText)
                } icon: {
                    LuneSymbolIcon(
                        name: LuneSymbolName.moon,
                        style: .hierarchical(.cycleText),
                        font: .title2
                    )
                }
                .labelStyle(.titleAndIcon)
                Text(LuneLexicon.tagline)
                    .font(.body)
                    .foregroundStyle(Color.cycleSecondary)
                Text(LuneLexicon.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.cycleSecondary)
            }
        }
    }

    private var resetPredictionCard: some View {
        CycleCard {
            VStack(alignment: .leading, spacing: 12) {
                LuneSymbolCaption(
                    symbol: LunePhase.reset.sfSymbolName,
                    title: "next reset",
                    multicolor: true
                )

                if let prediction = env.prediction {
                    let copy = LuneVoice.resetPrediction(daysUntil: env.daysUntilPredictedReset)

                    Text(copy.headline)
                        .font(.system(.title3, design: .serif).weight(.medium))
                        .foregroundStyle(Color.cycleText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(copy.subline)
                        .font(.body)
                        .foregroundStyle(Color.cycleSecondary)

                    if let date = prediction.predictedDate {
                        Label {
                            Text(date.formatted(.dateTime.month(.abbreviated).day()))
                                .foregroundStyle(Color.cycleSecondary)
                        } icon: {
                            LuneSymbolIcon(
                                name: LuneSymbolName.calendar,
                                style: .hierarchical(.cycleSecondary),
                                font: .footnote.weight(.medium)
                            )
                        }
                        .font(.footnote.weight(.medium))
                        .labelStyle(.titleAndIcon)
                    }

                    if let ovulation = prediction.predictedOvulationDate {
                        Label {
                            Text(LuneVoice.glowPrediction(date: ovulation))
                                .foregroundStyle(Color.cycleOvulation)
                        } icon: {
                            LuneSymbolIcon(
                                name: LuneSymbolName.sparkles,
                                style: .hierarchical(.cycleOvulation),
                                font: .body.weight(.medium)
                            )
                        }
                        .font(.body.weight(.medium))
                        .labelStyle(.titleAndIcon)
                    }

                    if let lower = prediction.lowerBound, let upper = prediction.upperBound {
                        Label {
                            Text("\(lower.formatted(.dateTime.month(.abbreviated).day())) – \(upper.formatted(.dateTime.month(.abbreviated).day()))")
                                .foregroundStyle(Color.cycleSecondary)
                        } icon: {
                            LuneSymbolIcon(
                                name: LuneSymbolName.calendarRange,
                                style: .hierarchical(.cycleSecondary),
                                font: .footnote
                            )
                        }
                        .font(.footnote)
                        .labelStyle(.titleAndIcon)
                    }
                } else {
                    Label {
                        Text("log a few cycles — lune learns your rhythm.")
                            .foregroundStyle(Color.cycleSecondary)
                    } icon: {
                        LuneSymbolIcon(
                            name: LuneSymbolName.book,
                            style: .hierarchical(.cycleSecondary),
                            font: .body
                        )
                    }
                    .labelStyle(.titleAndIcon)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var quickCheckInCard: some View {
        CycleCard {
            VStack(alignment: .leading, spacing: 12) {
                LuneSymbolCaption(
                    symbol: LuneSymbolName.vibe,
                    title: "how are we feeling?",
                    font: .headline,
                    color: .cycleText
                )
                .accessibilityAddTraits(.isHeader)

                Label {
                    Text("quick vibe check — mood, signals, lune note.")
                        .foregroundStyle(Color.cycleSecondary)
                } icon: {
                    LuneSymbolIcon(
                        name: LuneSymbolName.sparkles,
                        style: .hierarchical(.cycleSecondary),
                        font: .subheadline
                    )
                }
                .font(.subheadline)
                .labelStyle(.titleAndIcon)

                TodayVibePreview()

                Button {
                    showCheckIn = true
                } label: {
                    Label(LuneLexicon.checkIn, systemImage: LuneSymbolName.vibe)
                }
                    .buttonStyle(PrimaryButtonStyle(filled: false))

                if let checkIn = todayCheckIn {
                    let summary = checkIn.todaySummary
                    if !summary.isEmpty {
                        Label {
                            Text(summary)
                                .foregroundStyle(Color.cycleSage)
                        } icon: {
                            LuneSymbolIcon(
                                name: LuneSymbolName.checkmark,
                                style: .accent,
                                font: .footnote.weight(.medium)
                            )
                        }
                        .font(.footnote.weight(.medium))
                        .labelStyle(.titleAndIcon)
                    }
                }

                if env.preferences.iMessageRemindersEnabled,
                   !env.preferences.iMessageContacts.isEmpty {
                    Button {
                        env.queueAutomaticIMessage(kind: .periodClose)
                    } label: {
                        Label("Message someone", systemImage: LuneSymbolName.message)
                    }
                    .buttonStyle(PrimaryButtonStyle(filled: false))
                }
            }
        }
    }

    @ViewBuilder
    private var insightCard: some View {
        if let insight = env.insights.first {
            CycleCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(LuneVoice.insightHeader(for: insight))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.cycleSecondary)
                    LuneSymbolCaption(
                        symbol: LuneSymbolName.lightbulb,
                        title: LuneVoice.insightTitle(insight.title),
                        font: .headline,
                        color: .cycleText
                    )
                    Text(insight.body)
                        .font(.subheadline)
                        .foregroundStyle(Color.cycleSecondary)
                    Text(insight.evidence)
                        .font(.footnote)
                        .foregroundStyle(Color.cycleSecondary)
                    LuneSymbolCaption(
                        symbol: LuneSymbolName.medical,
                        title: "your patterns — not a diagnosis.",
                        font: .caption,
                        color: .cycleSecondary
                    )
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var premiumInsightTeaser: some View {
        CycleCard {
            VStack(alignment: .leading, spacing: 12) {
                LuneSymbolCaption(symbol: LuneSymbolName.pattern, title: "pattern insights")
                Text("spot trends in your cycle with Lune Premium.")
                    .font(.subheadline)
                    .foregroundStyle(Color.cycleSecondary)
                Button("Unlock Insights") {
                    showPremiumPaywall = true
                }
                .buttonStyle(PrimaryButtonStyle(filled: false))
            }
        }
    }
}
