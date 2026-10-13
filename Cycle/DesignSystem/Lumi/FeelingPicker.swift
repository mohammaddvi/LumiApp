import SwiftUI

/// The six feelings as small Lumis in a grid (2 columns at accessibility text sizes).
struct FeelingPicker: View {
    let selection: Feeling?
    let onSelect: (Feeling) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: 10),
                count: dynamicTypeSize.isAccessibilitySize ? 2 : 3
            ),
            spacing: 10
        ) {
            ForEach(Feeling.allCases) { item in
                FeelingButton(feeling: item, isSelected: item == selection) {
                    onSelect(item)
                }
            }
        }
    }
}

private struct FeelingButton: View {
    let feeling: Feeling
    let isSelected: Bool
    let action: () -> Void

    private var palette: LumiPalette { .for(feeling) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                LumiView(feeling: feeling, size: 56, animated: false)
                    .accessibilityHidden(true)
                Text(feeling.displayName)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(Color.cycleText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? palette.body.opacity(0.28) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? palette.bodyDark : Color.clear, lineWidth: 2)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(FeelingPressStyle())
        .accessibilityLabel(feeling.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Shrinks on press, the moment the finger lands.
private struct FeelingPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 1), value: configuration.isPressed)
    }
}
