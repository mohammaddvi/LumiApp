import AVFoundation
import UIKit

/// Lumi's wordless "voice": one tiny synthesized chirp per letter, pitched by the letter and her mood
/// (Animal Crossing style). No audio files and no network. Uses the ambient audio session, so it
/// respects the silent switch and never interrupts music.
@MainActor
final class LumiBabble {
    static let shared = LumiBabble()

    /// `@AppStorage` key for the Settings switch (on by default).
    static let enabledKey = "lumi.voiceEnabled"

    // Internal (not private) so tests can tap the output.
    let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var isConfigured = false
    private var idleStop: Task<Void, Never>?

    /// Seconds per chirp; the speech bubble types a little slower so chirps don't pile up.
    static let chirpDuration: Double = 0.05

    private init() {}

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    /// Plays one chirp for a typed character. Spaces and punctuation stay silent.
    func chirp(for character: Character, mood: Feeling?) {
        guard isEnabled, character.isLetter, !UIAccessibility.isVoiceOverRunning else { return }
        guard start() else { return }
        idleStop?.cancel()
        player.scheduleBuffer(makeChirp(for: character, mood: mood))
        if !player.isPlaying { player.play() }
        // Let the engine sleep shortly after Lumi stops talking.
        idleStop = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.engine.pause()
        }
    }

    private func start() -> Bool {
        if !isConfigured {
            do {
                try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            } catch {
                return false
            }
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            isConfigured = true
        }
        if !engine.isRunning {
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                try engine.start()
            } catch {
                return false
            }
        }
        return true
    }

    private func makeChirp(for character: Character, mood: Feeling?) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * Self.chirpDuration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let samples = buffer.floatChannelData![0]

        let base = Self.basePitch(for: mood) * Self.letterFactor(for: character) * Double.random(in: 0.97...1.03)
        let wobble = mood == .anxious ? 0.06 : 0.0
        var phase = 0.0
        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let progress = t / Self.chirpDuration
            // A quick upward blip that settles, plus a nervous wobble when anxious.
            let glide = 1.0 + 0.10 * (1 - progress) - 0.04
            let vibrato = 1.0 + wobble * sin(2 * .pi * 28 * t)
            phase += 2 * .pi * base * glide * vibrato / sampleRate
            let tone = sin(phase) + 0.35 * sin(2 * phase) + 0.12 * sin(3 * phase)
            let attack = min(1, t / 0.006)
            let release = pow(1 - progress, 1.6)
            samples[frame] = Float(0.18 * tone * attack * release)
        }
        return buffer
    }

    /// Higher and bouncier when happy, lower when tired or sad.
    private static func basePitch(for mood: Feeling?) -> Double {
        switch mood {
        case .happy: 560
        case .calm: 440
        case .tired: 330
        case .anxious: 520
        case .irritable: 470
        case .sad: 360
        case nil: 500
        }
    }

    /// Vowels get recognizable pitches; consonants vary a little so words sound different.
    private static func letterFactor(for character: Character) -> Double {
        switch character.lowercased() {
        case "a": return 1.0
        case "e": return 1.12
        case "i": return 1.26
        case "o": return 0.9
        case "u": return 0.84
        case "y": return 1.18
        default:
            let scalar = Double(character.unicodeScalars.first?.value ?? 0)
            return 0.94 + scalar.truncatingRemainder(dividingBy: 7) * 0.03
        }
    }
}
