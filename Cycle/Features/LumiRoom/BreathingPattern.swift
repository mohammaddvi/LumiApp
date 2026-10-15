import Foundation

/// One step of breathing with Lumi.
enum BreathingStep: Equatable, Sendable {
    case inhale(round: Int)
    case exhale(round: Int)

    var isInhale: Bool {
        if case .inhale = self { true } else { false }
    }

    var round: Int {
        switch self {
        case .inhale(let round), .exhale(let round): round
        }
    }
}

/// Slow breathing: in for 4 seconds, out for 6, six times — one minute.
/// A longer out-breath than in-breath helps the body settle. Plain data so it can be tested.
struct BreathingPattern: Equatable, Sendable {
    var inhaleSeconds: Double = 4
    var exhaleSeconds: Double = 6
    var rounds = 6

    var steps: [BreathingStep] {
        (1...max(rounds, 1)).flatMap { [BreathingStep.inhale(round: $0), .exhale(round: $0)] }
    }

    func seconds(for step: BreathingStep) -> Double {
        step.isInhale ? inhaleSeconds : exhaleSeconds
    }

    var totalSeconds: Double {
        steps.reduce(0) { $0 + seconds(for: $1) }
    }
}
