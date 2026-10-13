import SwiftUI

extension AppearanceMode {
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }
}

/// MyLune palette — dreamy moonlit storybook: lavender mist by day, night sky by dark.
/// Token names (`sage`, `cycleCoral`, …) are kept for call-site stability; values are the fantasy palette.
enum CyclePalette {
    // MARK: Light — lavender mist
    static let cream = UIColor(red: 0.965, green: 0.941, blue: 0.984, alpha: 1)       // #F6F0FB mist
    static let white = UIColor.white
    static let ink = UIColor(red: 0.231, green: 0.165, blue: 0.302, alpha: 1)         // #3B2A4D plum
    /// Secondary copy — ~5.5:1 on mist (WCAG AA body text).
    static let moss = UIColor(red: 0.420, green: 0.353, blue: 0.502, alpha: 1)        // #6B5A80 dusk
    static let mossHighContrast = ink
    static let sage = UIColor(red: 0.718, green: 0.608, blue: 0.922, alpha: 1)        // #B79BEB lilac
    static let sageDeep = UIColor(red: 0.898, green: 0.561, blue: 0.690, alpha: 1)    // #E58FB0 rose
    static let sageSoft = UIColor(red: 0.933, green: 0.894, blue: 0.984, alpha: 1)    // #EEE4FB lilac wash
    static let sageMuted = UIColor(red: 0.914, green: 0.659, blue: 0.322, alpha: 1)   // #E9A852 star gold
    static let border = UIColor(red: 0.914, green: 0.867, blue: 0.965, alpha: 1)      // #E9DDF6
    /// Warm lunar yellow for lit `moonphase.*` glyphs.
    static let moonLight = UIColor(red: 0.988, green: 0.878, blue: 0.451, alpha: 1)   // #FCE073
    static let moonShadow = UIColor(red: 0.831, green: 0.800, blue: 0.886, alpha: 1)  // #D4CCE2
    /// Text-safe accents (≥4.5:1 text / ≥3:1 lines on every light surface). The pastel accents above are for fills.
    static let accentText = UIColor(red: 0.388, green: 0.267, blue: 0.678, alpha: 1)  // #6344AD deep lilac
    static let ovulationStrong = UIColor(red: 0.576, green: 0.369, blue: 0.047, alpha: 1) // #935E0C amber
    static let coralStrong = UIColor(red: 0.718, green: 0.278, blue: 0.447, alpha: 1)  // #B74772 deep rose
    /// Text on filled lilac/rose buttons in both modes (~5:1 or better).
    static let onAccent = UIColor(red: 0.180, green: 0.122, blue: 0.271, alpha: 1)    // #2E1F45

    // MARK: Dark — night sky
    static let night = UIColor(red: 0.106, green: 0.090, blue: 0.188, alpha: 1)       // #1B1730
    static let nightElevated = UIColor(red: 0.153, green: 0.129, blue: 0.259, alpha: 1) // #272142
    static let nightInk = UIColor(red: 0.953, green: 0.933, blue: 0.984, alpha: 1)    // #F3EEFB
    static let nightMoss = UIColor(red: 0.741, green: 0.698, blue: 0.831, alpha: 1)   // #BDB2D4
    static let nightSage = UIColor(red: 0.659, green: 0.545, blue: 0.902, alpha: 1)   // #A88BE6
    static let nightSageDeep = UIColor(red: 0.843, green: 0.478, blue: 0.620, alpha: 1) // #D77A9E
    static let nightSageSoft = UIColor(red: 0.204, green: 0.169, blue: 0.333, alpha: 1) // #342B55
    static let nightSageMuted = UIColor(red: 0.902, green: 0.690, blue: 0.384, alpha: 1) // #E6B062
    static let nightBorder = UIColor(red: 0.231, green: 0.200, blue: 0.376, alpha: 1) // #3B3360
    static let nightMoonLight = UIColor(red: 0.961, green: 0.827, blue: 0.392, alpha: 1)
    static let nightMoonShadow = UIColor(red: 0.294, green: 0.267, blue: 0.408, alpha: 1) // #4B4468
}

extension Color {
    /// App canvas — lavender mist / night sky.
    static let cycleBackground = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? CyclePalette.night : CyclePalette.cream
    })

    /// Cards, fields, sheets — white on mist / raised night.
    static let cycleSurface = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? CyclePalette.nightElevated : CyclePalette.white
    })

    static let cycleText = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? CyclePalette.nightInk : CyclePalette.ink
    })

    static let cycleSecondary = Color(uiColor: UIColor { t in
        let normal = t.userInterfaceStyle == .dark ? CyclePalette.nightMoss : CyclePalette.moss
        let high = t.userInterfaceStyle == .dark ? CyclePalette.nightInk : CyclePalette.mossHighContrast
        return t.accessibilityContrast == .high ? high : normal
    })

    /// Primary accent — lilac (tabs, actions, highlights).
    static let cycleSage = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? CyclePalette.nightSage : CyclePalette.sage
    })

    /// Rose — period bands & emphasis.
    static let cycleCoral = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? CyclePalette.nightSageDeep : CyclePalette.sageDeep
    })

    /// Readable accent on light fills (period day numbers, selected labels).
    static let cycleBlushDeep = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? CyclePalette.nightInk : CyclePalette.ink
    })

    static let cycleBorder = Color(uiColor: UIColor { t in
        let normal = t.userInterfaceStyle == .dark ? CyclePalette.nightBorder : CyclePalette.border
        let high = t.userInterfaceStyle == .dark ? CyclePalette.nightMoss : CyclePalette.moss
        return t.accessibilityContrast == .high ? high : normal
    })

    /// Star gold — ovulation & secondary rings.
    static let cycleOvulation = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? CyclePalette.nightSageMuted : CyclePalette.ovulationStrong
    })

    /// Selection washes, draft ranges, subtle chips.
    static let cycleAccentSoft = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? CyclePalette.nightSageSoft : CyclePalette.sageSoft
    })

    /// Lilac for text, links, tints and icons: 4.5:1+ in both modes (pastel `cycleSage` is for fills only).
    static let cycleAccentText = Color(uiColor: UIColor { t in
        if t.accessibilityContrast == .high {
            return t.userInterfaceStyle == .dark ? CyclePalette.nightInk : CyclePalette.ink
        }
        return t.userInterfaceStyle == .dark ? CyclePalette.nightSage : CyclePalette.accentText
    })

    /// Rose for lines and outlines (predicted period): 3:1+ in both modes.
    static let cycleCoralStrong = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? CyclePalette.nightSageDeep : CyclePalette.coralStrong
    })

    /// Text and icons on filled accent buttons.
    static let cycleOnAccent = Color(uiColor: CyclePalette.onAccent)

    /// Lilac → rose, for primary buttons and magic accents.
    static let cycleMagic = LinearGradient(
        colors: [.cycleSage, .cycleCoral],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Lit portion of `moonphase.*` SF Symbols.
    static let cycleMoonLight = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? CyclePalette.nightMoonLight : CyclePalette.moonLight
    })

    /// Shadow/disc portion of `moonphase.*` SF Symbols.
    static let cycleMoonShadow = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? CyclePalette.nightMoonShadow : CyclePalette.moonShadow
    })
}

struct CycleCard<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cycleSurface)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.cycleBorder, lineWidth: 1)
            )
            .shadow(color: Color.cycleSage.opacity(0.18), radius: 14, y: 6)
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.medium))
                .foregroundStyle(Color.cycleText)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.cycleSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var filled = true
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let highContrast = contrast == .increased
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.horizontal, 18)
            .foregroundStyle(foreground(highContrast: highContrast))
            .background {
                if filled {
                    if highContrast {
                        Capsule().fill(Color.cycleText)
                    } else {
                        Capsule().fill(Color.cycleMagic)
                    }
                } else {
                    Capsule().fill(Color.cycleSurface)
                }
            }
            .overlay(
                Capsule().stroke(
                    filled ? Color.clear : (highContrast ? Color.cycleText : Color.cycleBorder),
                    lineWidth: filled ? 0 : (highContrast ? 2 : 1.5)
                )
            )
            .shadow(color: filled && isEnabled ? Color.cycleCoral.opacity(0.3) : .clear, radius: 12, y: 5)
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 1), value: configuration.isPressed)
    }

    private func foreground(highContrast: Bool) -> Color {
        guard filled else { return .cycleText }
        return highContrast ? .cycleSurface : .cycleOnAccent
    }
}

struct ChipButton: View {
    let title: String
    var isSelected: Bool
    var accent: Color = .cycleSage
    var categoryContext: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .foregroundStyle(Color.cycleText)
            .background(isSelected ? Color.cycleAccentSoft : Color.cycleSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? accent.opacity(0.85) : Color.cycleBorder,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(isSelected ? "Double tap to deselect" : "Double tap to select")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityInputLabels([title])
    }
}

struct SymptomCategoryCard<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var accent: Color = .cycleSage
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accent)
                    .frame(width: 4)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.cycleText)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.cycleSecondary)
                    }
                }
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cycleSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.cycleBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Accessibility helpers

extension View {
    /// Minimum 44×44 pt tap target for custom icon-only controls.
    func cycleAccessibleTapTarget() -> some View {
        frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }

    /// Legend swatches: name only (color is decorative).
    func cycleLegendAccessibility(_ title: String) -> some View {
        accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
    }
}
