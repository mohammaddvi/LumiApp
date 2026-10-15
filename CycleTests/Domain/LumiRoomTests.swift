import Foundation
import Testing
@testable import Cycle

@Suite("Moon phase")
struct MoonPhaseTests {
    private func utc(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    @Test("Known 2024 moon moments land on the right phase")
    func knownMoons() {
        #expect(MoonPhase.on(utc(2024, 4, 8, 18, 21)) == .new)
        #expect(MoonPhase.on(utc(2024, 4, 15, 19, 13)) == .firstQuarter)
        #expect(MoonPhase.on(utc(2024, 4, 23, 23, 49)) == .full)
        #expect(MoonPhase.on(utc(2024, 5, 1, 11, 27)) == .lastQuarter)
    }

    @Test("Days between quarters fall in the in-between phases")
    func inBetween() {
        #expect(MoonPhase.on(utc(2024, 4, 12, 0, 0)) == .waxingCrescent)
        #expect(MoonPhase.on(utc(2024, 4, 19, 12, 0)) == .waxingGibbous)
        #expect(MoonPhase.on(utc(2024, 4, 27, 12, 0)) == .waningGibbous)
        #expect(MoonPhase.on(utc(2024, 5, 4, 12, 0)) == .waningCrescent)
    }

    @Test("Age stays within one lunar month, even before the reference")
    func ageRange() {
        for date in [utc(1990, 1, 1, 0, 0), utc(2026, 10, 15, 12, 0), utc(2100, 6, 1, 0, 0)] {
            let age = MoonPhase.age(on: date)
            #expect(age >= 0 && age < MoonPhase.synodicMonth)
        }
    }
}

@Suite("Breathing with Lumi")
struct BreathingPatternTests {
    @Test("Six rounds of in for 4 and out for 6 take one minute")
    func oneMinute() {
        let pattern = BreathingPattern()
        #expect(pattern.steps.count == 12)
        #expect(pattern.totalSeconds == 60)
    }

    @Test("Steps alternate in and out, counting rounds from 1")
    func alternates() {
        let steps = BreathingPattern(rounds: 2).steps
        #expect(steps == [.inhale(round: 1), .exhale(round: 1), .inhale(round: 2), .exhale(round: 2)])
    }
}

@Suite("Lumi's outfit")
struct LumiOutfitTests {
    @Test("One item per slot: a new hat replaces the old one")
    func oneHatAtATime() {
        let outfit = LumiOutfit([.bow]).toggling(.crown)
        #expect(outfit.items == [.crown])
    }

    @Test("One item from each shelf can be worn together, in shelf order")
    func wholeOutfit() {
        let outfit = LumiOutfit([.rainBoots, .roundGlasses, .sweater, .flowerCrown, .bun])
        #expect(outfit.items == [.bun, .flowerCrown, .roundGlasses, .sweater, .rainBoots])
        #expect(outfit.item(in: .clothes) == .sweater)
        #expect(outfit.item(in: .shoes) == .rainBoots)
    }

    @Test("Every shelf has something to wear")
    func shelvesFilled() {
        for slot in LumiWearSlot.allCases {
            #expect(!slot.items.isEmpty)
        }
    }

    @Test("Tapping a worn item takes it off")
    func takeOff() {
        let outfit = LumiOutfit([.bow, .heartGlasses]).toggling(.bow)
        #expect(outfit.items == [.heartGlasses])
    }

    @Test("Saves as text and reads back, skipping unknown items")
    func storage() {
        let outfit = LumiOutfit([.headphones, .roundGlasses])
        #expect(outfit.rawValue == "headphones,roundGlasses")
        #expect(LumiOutfit(rawValue: outfit.rawValue) == outfit)
        #expect(LumiOutfit(rawValue: "cape,bow").items == [.bow])
        #expect(LumiOutfit(rawValue: "").items.isEmpty)
    }
}

@Suite("Lumi's stickers")
struct LumiStickerBoardTests {
    @Test("New stickers land around Lumi, one spot after another")
    func adding() {
        let board = LumiStickerBoard().adding("💖").adding("✨")
        #expect(board.stickers.map(\.emoji) == ["💖", "✨"])
        #expect(board.stickers[0].x == LumiStickerBoard.spots[0].x)
        #expect(board.stickers[1].y == LumiStickerBoard.spots[1].y)
    }

    @Test("Stops adding at the limit")
    func limit() {
        var board = LumiStickerBoard()
        for _ in 0..<(LumiStickerBoard.limit + 3) {
            board = board.adding("⭐️")
        }
        #expect(board.stickers.count == LumiStickerBoard.limit)
        #expect(board.isFull)
    }

    @Test("Moving and resizing stay within bounds")
    func clamps() throws {
        let board = LumiStickerBoard().adding("🌙")
        let id = try #require(board.stickers.first?.id)
        let moved = board.moving(id, toX: 1.4, y: -0.3)
        #expect(moved.stickers[0].x == 0.96)
        #expect(moved.stickers[0].y == 0.04)
        #expect(moved.resizing(id, to: 9).stickers[0].scale == LumiStickerBoard.scaleRange.upperBound)
        #expect(moved.resizing(id, to: 0.1).stickers[0].scale == LumiStickerBoard.scaleRange.lowerBound)
    }

    @Test("Removing one leaves the others; saving round-trips")
    func removeAndSave() throws {
        let board = LumiStickerBoard().adding("🌸").adding("🦋")
        let first = try #require(board.stickers.first?.id)
        let trimmed = board.removing(first)
        #expect(trimmed.stickers.map(\.emoji) == ["🦋"])
        // JSON can round the last bit of a position, so compare closely rather than exactly.
        let saved = LumiStickerBoard(rawValue: board.rawValue).stickers
        #expect(saved.map(\.id) == board.stickers.map(\.id))
        #expect(saved.map(\.emoji) == board.stickers.map(\.emoji))
        for (read, original) in zip(saved, board.stickers) {
            #expect(abs(read.x - original.x) < 1e-9 && abs(read.y - original.y) < 1e-9)
        }
        #expect(LumiStickerBoard(rawValue: "not json").stickers.isEmpty)
    }
}
