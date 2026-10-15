import SwiftUI
import UIKit

/// A short face Lumi makes when you touch her. Shows over her feeling for a moment.
enum LumiPlay: Equatable, Sendable {
    /// Tapped: eyes squeezed into happy arcs, big grin, "hehe".
    case giggle
    /// Petted: content closed eyes, rosy cheeks, little hearts.
    case petted

    /// The feeling whose eyes and mouth this face borrows.
    var face: Feeling {
        switch self {
        case .giggle: .happy
        case .petted: .calm
        }
    }
}

/// Counts back-and-forth strokes from a finger's x position. Plain value so it can be tested.
struct LumiPetStrokes: Equatable, Sendable {
    /// How far the finger must travel back the other way to count as a new stroke.
    var threshold: CGFloat

    /// The furthest point of the current stroke.
    private var anchor: CGFloat?
    /// -1 left, 1 right, 0 before the first stroke.
    private var direction: CGFloat = 0

    init(threshold: CGFloat = 18) {
        self.threshold = threshold
    }

    /// Follows the finger; returns true when it starts a new stroke.
    mutating func move(to x: CGFloat) -> Bool {
        guard let anchor else {
            self.anchor = x
            return false
        }
        let delta = x - anchor
        if delta * direction > 0 {
            // Still going the same way: follow the hand to the end of the stroke.
            self.anchor = x
            return false
        }
        guard abs(delta) >= threshold else { return false }
        direction = delta > 0 ? 1 : -1
        self.anchor = x
        return true
    }

    mutating func reset() {
        anchor = nil
        direction = 0
    }
}

/// A sideways pan for petting Lumi. Uses UIKit so vertical drags still scroll the page.
struct LumiPetGesture: UIGestureRecognizerRepresentable {
    /// The finger's x position in Lumi's own space.
    var onMove: (CGFloat) -> Void
    var onEnd: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began, .changed:
            onMove(context.converter.localLocation.x)
        case .ended, .cancelled, .failed:
            onEnd()
        default:
            break
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        /// Only mostly-sideways drags pet Lumi; the rest are left to the scroll view.
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y) * 1.2
        }
    }
}

/// Lumi you can touch: a tap makes her giggle and hop (then runs `onTap`), stroking her sideways
/// pets her, and a long press runs `onLongPress`.
struct PlayfulLumi: View {
    var feeling: Feeling?
    var phase: LunePhase?
    var size: CGFloat
    var holding = false
    var talking = false
    var onTap: (() -> Void)?
    var onLongPress: (() -> Void)?
    /// VoiceOver's name for the long-press action.
    var longPressName = "Open Lumi's room"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Lumi's face while you tap or pet her; nil shows her feeling.
    @State private var play: LumiPlay?
    @State private var giggles = 0
    @State private var wiggles = 0
    @State private var longPresses = 0
    @State private var strokes = LumiPetStrokes()
    /// True while a finger strokes Lumi, and briefly after, so lifting it doesn't count as a tap.
    @State private var isPetting = false
    /// Lifting the finger after a long press isn't a tap either.
    @State private var ignoresNextTap = false
    @State private var playEnd: Task<Void, Never>?
    @State private var pendingTap: Task<Void, Never>?

    var body: some View {
        Button(action: tap) {
            LumiView(
                feeling: feeling,
                phase: phase,
                size: size,
                holding: holding,
                talking: talking,
                play: play,
                hops: giggles,
                wiggles: wiggles
            )
        }
        .buttonStyle(.plain)
        .gesture(LumiPetGesture(onMove: pet(atX:), onEnd: endPetting))
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in longPress() },
            isEnabled: onLongPress != nil
        )
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: giggles)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: wiggles)
        .sensoryFeedback(.impact(weight: .medium), trigger: longPresses)
        .accessibilityActions {
            if let onLongPress {
                Button(longPressName, action: onLongPress)
            }
        }
    }

    /// Lumi giggles and hops; `onTap` runs once the hop has peaked.
    private func tap() {
        if ignoresNextTap {
            ignoresNextTap = false
            return
        }
        guard !isPetting else { return }
        giggles += 1
        showPlay(.giggle, for: .milliseconds(800))
        pendingTap?.cancel()
        guard let onTap else { return }
        guard !reduceMotion else {
            onTap()
            return
        }
        pendingTap = Task {
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            onTap()
        }
    }

    private func longPress() {
        guard let onLongPress, !isPetting else { return }
        longPresses += 1
        ignoresNextTap = true
        onLongPress()
        Task {
            try? await Task.sleep(for: .seconds(1))
            ignoresNextTap = false
        }
    }

    private func pet(atX x: CGFloat) {
        isPetting = true
        playEnd?.cancel()
        play = .petted
        if strokes.move(to: x) {
            wiggles += 1
        }
    }

    private func endPetting() {
        strokes.reset()
        showPlay(.petted, for: .milliseconds(900))
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            isPetting = false
        }
    }

    private func showPlay(_ newPlay: LumiPlay, for duration: Duration) {
        play = newPlay
        playEnd?.cancel()
        playEnd = Task {
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            play = nil
        }
    }
}
