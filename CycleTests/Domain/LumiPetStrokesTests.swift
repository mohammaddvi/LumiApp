import CoreGraphics
import Testing
@testable import Cycle

@Suite("Lumi petting")
struct LumiPetStrokesTests {
    private func strokes(along xs: [CGFloat]) -> Int {
        var strokes = LumiPetStrokes(threshold: 18)
        return xs.filter { strokes.move(to: $0) }.count
    }

    @Test("A short wobble isn't a stroke")
    func wobble() {
        #expect(strokes(along: [100, 108, 96, 104]) == 0)
    }

    @Test("Each turn after a long enough sweep is a new stroke")
    func backAndForth() {
        // Right, then left, then right again.
        #expect(strokes(along: [100, 110, 125, 140, 120, 100, 90, 110, 130]) == 3)
    }

    @Test("Moving further the same way doesn't count twice")
    func oneLongSweep() {
        #expect(strokes(along: [0, 20, 40, 60, 80]) == 1)
    }

    @Test("Reset starts fresh")
    func reset() {
        var strokes = LumiPetStrokes(threshold: 18)
        _ = strokes.move(to: 0)
        let first = strokes.move(to: 30)
        strokes.reset()
        let afterReset = [strokes.move(to: 0), strokes.move(to: 10)]
        #expect(first)
        #expect(afterReset == [false, false])
    }
}
