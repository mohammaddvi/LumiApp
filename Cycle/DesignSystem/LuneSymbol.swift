import SwiftUI

/// Shared SF Symbol names — use these instead of emoji for UI chrome.
enum LuneSymbolName {
    static let moon = "moon.stars.fill"
    static let sparkles = "sparkles"
    static let calendar = "calendar"
    static let calendarRange = "calendar.badge.clock"
    static let note = "text.bubble"
    static let vibe = "heart.text.square"
    static let checkmark = "checkmark.circle.fill"
    static let message = "message.fill"
    static let lightbulb = "lightbulb.fill"
    static let book = "book.closed.fill"
    static let medical = "cross.case.fill"
    static let pattern = "waveform.path.ecg"
    static let glow = "sparkle"
}

/// Renders an SF Symbol with Apple's recommended rendering mode for the symbol type.
struct LuneSymbolIcon: View {
    enum Style {
        case hierarchical(Color)
        case accent
        case multicolor
    }

    var name: String
    var style: Style = .hierarchical(.cycleSecondary)
    var font: Font = .body

    var body: some View {
        Group {
            switch style {
            case .hierarchical(let color):
                Image(systemName: name)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(color)
            case .accent:
                Image(systemName: name)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.cycleSage)
            case .multicolor:
                Image(systemName: name)
                    .symbolRenderingMode(.multicolor)
            }
        }
        .font(font)
        .accessibilityHidden(true)
    }
}

/// Caption row: SF Symbol + title, aligned like a `Label`.
struct LuneSymbolCaption: View {
    var symbol: String
    var title: String
    var multicolor = false
    var font: Font = .subheadline.weight(.semibold)
    var color: Color = .cycleSecondary

    var body: some View {
        Label {
            Text(title)
                .foregroundStyle(color)
        } icon: {
            if multicolor, symbol.hasPrefix("moonphase.") {
                LuneMoonIcon(symbolName: symbol, pointSize: 15)
            } else {
                LuneSymbolIcon(
                    name: symbol,
                    style: multicolor ? .multicolor : .hierarchical(color),
                    font: font
                )
            }
        }
        .font(font)
        .labelStyle(.titleAndIcon)
    }
}

/// Body row: SF Symbol + multiline text.
struct LuneSymbolNote: View {
    var symbol: String
    var text: String
    var font: Font = .body
    var color: Color = .cycleSecondary

    var body: some View {
        Label {
            Text(text)
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            LuneSymbolIcon(name: symbol, style: .hierarchical(color), font: font)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .font(font)
        .labelStyle(.titleAndIcon)
        .multilineTextAlignment(.leading)
    }
}
