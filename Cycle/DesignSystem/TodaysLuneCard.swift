import SwiftUI

struct TodaysLuneCard: View {
    let snapshot: TodaysLuneSnapshot
    let dateText: String

    var body: some View {
        CycleCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        LuneSymbolCaption(symbol: LuneSymbolName.sparkles, title: "today's mylune")
                            .accessibilityAddTraits(.isHeader)

                        Label {
                            Text(dateText)
                                .foregroundStyle(Color.cycleSecondary)
                        } icon: {
                            LuneSymbolIcon(
                                name: LuneSymbolName.calendar,
                                style: .hierarchical(.cycleSecondary),
                                font: .footnote
                            )
                        }
                        .font(.footnote)
                        .labelStyle(.titleAndIcon)

                        Text(snapshot.headline)
                            .font(.system(.title3, design: .serif).weight(.medium))
                            .foregroundStyle(Color.cycleText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("day \(snapshot.cycleDay) of your arc")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.cycleSecondary)
                    }

                    Spacer(minLength: 0)

                    LuneMoonCompanion(
                        phase: snapshot.phase,
                        isSoftDays: snapshot.isSoftDays,
                        size: 68
                    )
                }

                LuneVitalLines(energyLine: snapshot.energyLine, moodLine: snapshot.moodLine)

                LuneSymbolNote(symbol: LuneSymbolName.note, text: snapshot.bodyLine)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LuneVitalLines: View {
    let energyLine: String
    let moodLine: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LuneVitalLine(symbol: "bolt.fill", text: energyLine)
            LuneVitalLine(symbol: "heart.fill", text: moodLine)
        }
    }
}

private struct LuneVitalLine: View {
    let symbol: String
    let text: String

    var body: some View {
        Label {
            Text(text)
                .foregroundStyle(Color.cycleText)
        } icon: {
            LuneSymbolIcon(
                name: symbol,
                style: .hierarchical(.cycleSecondary),
                font: .subheadline.weight(.medium)
            )
        }
        .font(.subheadline.weight(.medium))
        .labelStyle(.titleAndIcon)
    }
}

#Preview {
    TodaysLuneCard(
        snapshot: TodaysLuneSnapshot(
            phase: .slow,
            cycleDay: 18,
            isSoftDays: true,
            moonIllumination: 0.42,
            headline: "you're in your soft era",
            energyLine: "energy · mid",
            moodLine: "mood · soft",
            bodyLine: "your body might want extra rest rn."
        ),
        dateText: "Tuesday, August 25"
    )
    .padding()
    .background(Color.cycleBackground)
}
