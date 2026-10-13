import SwiftUI

/// A list section whose first row is a tappable title that opens and closes it.
/// Collapsed, it shows only that row (one compact card); the footer shows only when open.
struct CollapsibleSection<Content: View, Footer: View>: View {
    let title: String
    let systemImage: String
    @Binding var isExpanded: Bool
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        title: String,
        systemImage: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.title = title
        self.systemImage = systemImage
        self._isExpanded = isExpanded
        self.content = content
        self.footer = footer
    }

    var body: some View {
        Section {
            Button {
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.cycleAccentText)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.cycleAccentSoft))
                        .accessibilityHidden(true)
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Color.cycleText)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.cycleSecondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")
            .accessibilityAddTraits(.isHeader)

            if isExpanded {
                content()
            }
        } footer: {
            if isExpanded {
                footer()
            }
        }
    }
}

extension CollapsibleSection where Footer == EmptyView {
    init(
        title: String,
        systemImage: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(title: title, systemImage: systemImage, isExpanded: isExpanded, content: content) {
            EmptyView()
        }
    }
}
