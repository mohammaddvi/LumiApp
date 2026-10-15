import SwiftUI

/// Lumi's own space, opened by long-pressing her on Today: play with her, dress her up, decorate
/// around her with stickers, or breathe with her for a minute while she grows on each in-breath
/// and shrinks on each out-breath.
struct LumiRoomView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Mode: Equatable {
        case playing
        case breathing
        case done
    }

    /// A shelf in the "Dress me up" card: one per wardrobe slot, plus stickers.
    private enum Shelf: Hashable {
        case wear(LumiWearSlot)
        case stickers

        static let all: [Shelf] = LumiWearSlot.allCases.map(Shelf.wear) + [.stickers]

        var name: String {
            switch self {
            case .wear(let slot): slot.name
            case .stickers: LuneVoice.stickersShelf
            }
        }
    }

    /// A sticker being dragged or pinched, before the change is saved.
    private struct StickerEdit {
        var id: LumiSticker.ID
        var offset: CGSize = .zero
        var scale: Double = 1
    }

    private let pattern = BreathingPattern()
    private let moon = MoonPhase.on(.now)
    private let lumiSize: CGFloat = 200

    @AppStorage(LumiOutfit.storageKey) private var outfit = LumiOutfit()
    @AppStorage(LumiStickerBoard.storageKey) private var stickers = LumiStickerBoard()
    @State private var stickerEdit: StickerEdit?
    @State private var mode = Mode.playing
    /// Bumped when her outfit changes, so she twirls to show it off.
    @State private var twirls = 0
    /// The wardrobe shelf being browsed.
    @State private var shelf = Shelf.wear(.hair)
    @State private var appIcon = LumiIconLook.current
    @State private var step: BreathingStep?
    @State private var completions = 0

    private var feeling: Feeling? {
        switch mode {
        case .playing: env.todayFeeling
        case .breathing: .calm
        case .done: .happy
        }
    }

    private var isInhaling: Bool { step?.isInhale == true }

    /// Stickers can be moved only while their shelf is open, so touching Lumi still pets her.
    private var isEditingStickers: Bool { mode == .playing && shelf == .stickers }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    moonBadge
                    lumi
                    line
                    if mode == .playing {
                        VStack(spacing: 20) {
                            breatheInvite
                            wardrobe
                            if UIApplication.shared.supportsAlternateIcons {
                                appIconPicker
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .animation(.smooth(duration: 0.3), value: mode)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) {
                controls
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            .fantasySkyBackground()
            .navigationTitle(LuneVoice.roomTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: step)
        .sensoryFeedback(.success, trigger: completions)
        .sensoryFeedback(.selection, trigger: outfit)
        .sensoryFeedback(.impact(weight: .light), trigger: stickers.stickers.count)
        .task(id: mode) {
            if mode == .breathing {
                await breathe()
            }
        }
    }

    // MARK: Parts

    private var moonBadge: some View {
        Label(LuneVoice.moonTonight(moon), systemImage: moon.sfSymbolName)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.cycleText)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.cycleSurface.opacity(0.85)))
            .overlay(Capsule().stroke(Color.cycleBorder, lineWidth: 1))
    }

    private var lumi: some View {
        let palette = LumiPalette.resolve(feeling: feeling, phase: env.todaysLune?.phase)
        let stepSeconds = step.map(pattern.seconds(for:)) ?? 0.6
        return ZStack {
            // A soft glow that breathes with her.
            Circle()
                .fill(RadialGradient(
                    colors: [.white.opacity(0.8), palette.bodyLight.opacity(0.5), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: lumiSize * 0.75
                ))
                .frame(width: lumiSize * 1.5, height: lumiSize * 1.5)
                .scaleEffect(isInhaling && !reduceMotion ? 1.15 : 0.9)
                .opacity(mode == .playing ? 0.5 : isInhaling ? 1 : 0.6)
                .animation(.easeInOut(duration: stepSeconds), value: step)
                .accessibilityHidden(true)

            MagicBurst(trigger: completions)
                .frame(width: lumiSize * 1.6, height: lumiSize * 1.6)
                .allowsHitTesting(false)

            if mode == .breathing {
                LumiView(feeling: feeling, phase: env.todaysLune?.phase, size: lumiSize)
                    .scaleEffect(isInhaling && !reduceMotion ? 1.18 : 1)
                    .animation(.easeInOut(duration: stepSeconds), value: step)
                    .accessibilityHidden(true)
            } else {
                PlayfulLumi(feeling: feeling, phase: env.todaysLune?.phase, size: lumiSize)
                    .modifier(LumiTwirl(trigger: twirls, enabled: !reduceMotion))
                    .accessibilityLabel(feeling.map { "Lumi, feeling \($0.displayName.lowercased())" } ?? "Lumi")
                    .accessibilityHint("Tap to make her giggle")
            }
        }
        .frame(height: lumiSize * 1.15)
        .frame(maxWidth: .infinity)
        .overlay { stickerLayer }
        .overlay {
            if isEditingStickers {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.cycleAccentText.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: Stickers

    private var stickerLayer: some View {
        GeometryReader { proxy in
            ForEach(stickers.stickers) { sticker in
                stickerView(sticker, in: proxy.size)
            }
        }
        .allowsHitTesting(isEditingStickers)
    }

    private func stickerView(_ sticker: LumiSticker, in size: CGSize) -> some View {
        let edit = stickerEdit?.id == sticker.id ? stickerEdit : nil
        let scale = min(max(sticker.scale * (edit?.scale ?? 1), LumiStickerBoard.scaleRange.lowerBound), LumiStickerBoard.scaleRange.upperBound)
        return Text(sticker.emoji)
            .font(.system(size: 34 * scale))
            .padding(4)
            .overlay(alignment: .topTrailing) {
                if isEditingStickers {
                    Button {
                        withAnimation(.snappy) {
                            stickers = stickers.removing(sticker.id)
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.cycleAccentText)
                    }
                    .buttonStyle(.plain)
                    .offset(x: 8, y: -8)
                    .accessibilityHidden(true)
                }
            }
            .position(
                x: sticker.x * size.width + (edit?.offset.width ?? 0),
                y: sticker.y * size.height + (edit?.offset.height ?? 0)
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        var change = stickerEdit?.id == sticker.id ? stickerEdit! : StickerEdit(id: sticker.id)
                        change.offset = value.translation
                        stickerEdit = change
                    }
                    .onEnded { value in
                        stickers = stickers.moving(
                            sticker.id,
                            toX: (sticker.x * size.width + value.translation.width) / size.width,
                            y: (sticker.y * size.height + value.translation.height) / size.height
                        )
                        stickerEdit = nil
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        var change = stickerEdit?.id == sticker.id ? stickerEdit! : StickerEdit(id: sticker.id)
                        change.scale = value.magnification
                        stickerEdit = change
                    }
                    .onEnded { value in
                        stickers = stickers.resizing(sticker.id, to: sticker.scale * value.magnification)
                        stickerEdit = nil
                    }
            )
            .accessibilityElement()
            .accessibilityLabel("\(sticker.emoji) sticker")
            .accessibilityActions {
                Button("Remove") { stickers = stickers.removing(sticker.id) }
                Button("Make bigger") { stickers = stickers.resizing(sticker.id, to: sticker.scale + 0.25) }
                Button("Make smaller") { stickers = stickers.resizing(sticker.id, to: sticker.scale - 0.25) }
            }
    }

    private var stickerPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(LumiStickerBoard.choices, id: \.self) { emoji in
                        Button {
                            withAnimation(.snappy) {
                                stickers = stickers.adding(emoji)
                            }
                        } label: {
                            Text(emoji)
                                .font(.system(size: 30))
                                .frame(width: 52, height: 52)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.cycleSurface))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.cycleBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(stickers.isFull)
                        .accessibilityLabel("Add \(emoji) sticker")
                    }
                }
                .padding(2)
            }
            Text(stickers.isFull ? LuneVoice.stickersFull : LuneVoice.stickersHint)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.cycleSecondary)
        }
    }

    private var line: some View {
        VStack(spacing: 6) {
            Text(lineText)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Color.cycleText)
            if let detail = lineDetail {
                Text(detail)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.cycleSecondary)
            }
        }
        .multilineTextAlignment(.center)
        .contentTransition(.opacity)
        .animation(.easeInOut(duration: 0.35), value: lineText)
        .accessibilityElement(children: .combine)
    }

    private var lineText: String {
        switch mode {
        case .playing: LuneVoice.roomWelcome(name: env.preferences.userName)
        case .breathing: isInhaling ? LuneVoice.breatheIn : LuneVoice.breatheOut
        case .done: LuneVoice.breatheDone
        }
    }

    private var lineDetail: String? {
        switch mode {
        case .playing: LuneVoice.roomHint
        case .breathing: step.map { LuneVoice.breatheRound($0.round, of: pattern.rounds) }
        case .done: nil
        }
    }

    /// A small, outlined invitation near Lumi: an activity with her, not the screen's main button.
    private var breatheInvite: some View {
        Button {
            mode = .breathing
        } label: {
            Label(LuneVoice.breatheStart, systemImage: "wind")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.cycleAccentText)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(Capsule().fill(Color.cycleSurface.opacity(0.85)))
                .overlay(Capsule().stroke(Color.cycleAccentText.opacity(0.35), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private var wardrobe: some View {
        CycleCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text(LuneVoice.wardrobeTitle)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Color.cycleText)
                    .accessibilityAddTraits(.isHeader)
                shelfPicker
                switch shelf {
                case .wear(let slot):
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(slot.items) { item in
                                wearButton(item)
                            }
                        }
                        .padding(2)
                    }
                    .id(shelf)
                case .stickers:
                    stickerPicker
                }
            }
        }
    }

    private var shelfPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Shelf.all, id: \.self) { option in
                    let isOpen = option == shelf
                    Button {
                        shelf = option
                    } label: {
                        Text(option.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isOpen ? Color.white : Color.cycleText)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(Capsule().fill(isOpen ? Color.cycleAccentText : Color.cycleAccentSoft.opacity(0.6)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOpen ? .isSelected : [])
                }
            }
            .padding(2)
        }
        .sensoryFeedback(.selection, trigger: shelf)
    }

    private func wearButton(_ item: LumiWear) -> some View {
        let isWorn = outfit.isWearing(item)
        return Button {
            outfit = outfit.toggling(item)
            twirls += 1
        } label: {
            VStack(spacing: 4) {
                LumiView(feeling: feeling, phase: env.todaysLune?.phase, size: 54, animated: false, outfit: LumiOutfit([item]))
                Text(item.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.cycleText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.horizontal, 6)
            .frame(width: 92, height: 88)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isWorn ? Color.cycleAccentSoft : Color.cycleSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isWorn ? Color.cycleAccentText : Color.cycleBorder, lineWidth: isWorn ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.name)
        .accessibilityAddTraits(isWorn ? .isSelected : [])
        .accessibilityHint(isWorn ? "Takes it off Lumi" : "Puts it on Lumi")
    }

    private var appIconPicker: some View {
        CycleCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text(LuneVoice.appIconTitle)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Color.cycleText)
                    .accessibilityAddTraits(.isHeader)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(LumiIconLook.allCases) { look in
                            iconButton(look)
                        }
                    }
                    .padding(2)
                }
            }
        }
    }

    private func iconButton(_ look: LumiIconLook) -> some View {
        let isCurrent = appIcon == look
        return Button {
            Task { await useIcon(look) }
        } label: {
            VStack(spacing: 6) {
                LumiAppIconArt(outfit: look.outfit)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(isCurrent ? Color.cycleAccentText : Color.cycleBorder, lineWidth: isCurrent ? 2.5 : 1)
                    )
                Text(look.name)
                    .font(.caption.weight(isCurrent ? .bold : .semibold))
                    .foregroundStyle(Color.cycleText)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(look.name) app icon")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private func useIcon(_ look: LumiIconLook) async {
        guard look != appIcon else { return }
        do {
            try await UIApplication.shared.setAlternateIconName(look.iconName)
            appIcon = look
        } catch {
            // iOS refused (rare); the picker keeps showing the icon that's really in use.
            appIcon = LumiIconLook.current
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch mode {
        case .playing:
            // Breathing is invited next to Lumi instead, so a big button here doesn't read as
            // "save my outfit".
            EmptyView()
        case .breathing:
            Button("Stop") {
                step = nil
                mode = .playing
            }
            .buttonStyle(PrimaryButtonStyle(filled: false))
        case .done:
            HStack(spacing: 12) {
                Button("Again") {
                    mode = .breathing
                }
                .buttonStyle(PrimaryButtonStyle(filled: false))
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    // MARK: Breathing

    private func breathe() async {
        for next in pattern.steps {
            step = next
            if UIAccessibility.isVoiceOverRunning {
                UIAccessibility.post(notification: .announcement, argument: next.isInhale ? LuneVoice.breatheIn : LuneVoice.breatheOut)
            }
            try? await Task.sleep(for: .seconds(pattern.seconds(for: next)))
            guard !Task.isCancelled else { return }
        }
        step = nil
        completions += 1
        mode = .done
    }
}

/// A quick twirl to show off a new outfit.
private struct LumiTwirl: ViewModifier {
    let trigger: Int
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, angle in
                view.rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
            } keyframes: { _ in
                CubicKeyframe(360, duration: 0.5)
                // A full turn looks the same as none, so jump back for the next twirl.
                MoveKeyframe(0)
            }
        } else {
            content
        }
    }
}
