import AVFoundation
import Testing
@testable import Cycle

@MainActor
@Suite("LumiBabble", .serialized)
struct LumiBabbleTests {
    /// Plays a few chirps, pauses like between sentences, plays again, and checks real audio came out both times.
    @Test("Chirps produce audible output, also after the engine pauses")
    func producesSound() async throws {
        let babble = LumiBabble.shared
        let peak = PeakMeter()
        babble.chirp(for: "h", mood: .happy) // starts the engine so the tap can attach
        babble.engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: nil, block: peak.tapBlock())
        defer { babble.engine.mainMixerNode.removeTap(onBus: 0) }

        for character in "hello" {
            babble.chirp(for: character, mood: .happy)
            try await Task.sleep(for: .milliseconds(60))
        }
        try await Task.sleep(for: .milliseconds(300))
        #expect(peak.value > 0.01, "first sentence was silent")

        // Simulate the idle pause between two lines.
        babble.engine.pause()
        peak.reset()
        try babble.engine.start()
        for character in "again" {
            babble.chirp(for: character, mood: .calm)
            try await Task.sleep(for: .milliseconds(60))
        }
        try await Task.sleep(for: .milliseconds(300))
        #expect(peak.value > 0.01, "second sentence after a pause was silent")
    }
}

private final class PeakMeter: @unchecked Sendable {
    private let lock = NSLock()
    private var peak: Float = 0

    var value: Float { lock.withLock { peak } }

    func reset() { lock.withLock { peak = 0 } }

    /// Built outside any actor: the tap runs on an audio thread.
    nonisolated func tapBlock() -> AVAudioNodeTapBlock {
        { [self] buffer, _ in record(buffer) }
    }

    func record(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        var local: Float = 0
        for index in 0..<Int(buffer.frameLength) { local = max(local, abs(data[index])) }
        lock.withLock { peak = max(peak, local) }
    }
}
