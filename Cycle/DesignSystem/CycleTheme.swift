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

/// MyLune palette — cream · white · light sage green.
/// Semantic tokens (`cycleCoral`, etc.) stay for call-site stability but map into this family.
enum CyclePalette {
    // MARK: Light
    static let cream = UIColor(red: 0.965, green: 0.949, blue: 0.922, alpha: 1)       // #F6F2EB
    static let white = UIColor.white
    static let ink = UIColor(red: 0.235, green: 0.282, blue: 0.235, alpha: 1)         // #3C483C
    /// Secondary copy — dark enough for ~4.5:1 on cream (WCAG AA body text).
    static let moss = UIColor(red: 0.353, green: 0.427, blue: 0.353, alpha: 1)        // #5A6D5A
    static let mossHighContrast = ink
    static let sage = UIColor(red: 0.722, green: 0.831, blue: 0.698, alpha: 1)         // #B8D4B2
    static let sageDeep = UIColor(red: 0.561, green: 0.690, blue: 0.541, alpha: 1)    // #8FB08A
    static let sageSoft = UIColor(red: 0.878, green: 0.933, blue: 0.867, alpha: 1)    // #E0EEE0
    static let sageMuted = UIColor(red: 0.631, green: 0.749, blue: 0.608, alpha: 1)   // #A1BF9B
    static let border = UIColor(red: 0.898, green: 0.914, blue: 0.886, alpha: 1)        // #E5E9E2
    /// Warm lunar yellow for lit `moonphase.*` glyphs.
    static let moonLight = UIColor(red: 0.988, green: 0.878, blue: 0.451, alpha: 1)     // #FCE073
    static let moonShadow = UIColor(red: 0.788, green: 0.804, blue: 0.776, alpha: 1)  // #C9CDC6

    // MARK: Dark (warm green-gray, same character)
    static let night = UIColor(red: 0.133, green: 0.157, blue: 0.133, alpha: 1)
    static let nightElevated = UIColor(red: 0.188, green: 0.216, blue: 0.188, alpha: 1)
    static let nightInk = UIColor(red: 0.949, green: 0.961, blue: 0.945, alpha: 1)
    static let nightMoss = UIColor(red: 0.659, green: 0.722, blue: 0.659, alpha: 1)
    static let nightSage = UIColor(red: 0.561, green: 0.690, blue: 0.541, alpha: 1)
    static let nightSageDeep = UIColor(red: 0.478, green: 0.584, blue: 0.463, alpha: 1)
    static let nightSageSoft = UIColor(red: 0.247, green: 0.294, blue: 0.247, alpha: 1)
    static let nightSageMuted = UIColor(red: 0.502, green: 0.608, blue: 0.494, alpha: 1)
    static let nightBorder = UIColor(red: 0.278, green: 0.318, blue: 0.278, alpha: 1)
    static let nightMoonLight = UIColor(red: 0.961, green: 0.827, blue: 0.392, alpha: 1)
    static let nightMoonShadow = UIColor(red: 0.420, green: 0.447, blue: 0.420, alpha: 1)
}

extension Color {
    /// App canvas — warm cream.
    static let cycleBackground = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? CyclePalette.night : CyclePalette.cream
    })

    /// Cards, fields, sheets — clean white (elevated on cream).
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

    /// Primary accent — light sage green (tabs, actions, highlights).
    static let cycleSage = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? CyclePalette.nightSage : CyclePalette.sage
    })

    /// Stronger green for period bands & emphasis.
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

    /// Ovulation & secondary rings — mid sage.
    static let cycleOvulation = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? CyclePalette.nightSageMuted : CyclePalette.sageMuted
    })

    /// Selection washes, draft ranges, subtle chips.
    static let cycleAccentSoft = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark ? CyclePalette.nightSageSoft : CyclePalette.sageSoft
    })

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
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.cycleBorder, lineWidth: 1)
            )
            .shadow(color: Color.cycleText.opacity(0.04), radius: 8, y: 2)
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.title3, design: .serif).weight(.medium))
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

    func makeBody(configuration: Configuration) -> some View {
        let highContrast = contrast == .increased
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .padding(.horizontal, 16)
            .foregroundStyle(filled && highContrast ? Color.white : Color.cycleText)
            .background(filled ? (highContrast ? Color.cycleCoral : Color.cycleSage) : Color.cycleSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        filled ? (highContrast ? Color.cycleText : Color.clear) : Color.cycleBorder,
                        lineWidth: filled && highContrast ? 2 : (filled ? 0 : 1)
                    )
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
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
