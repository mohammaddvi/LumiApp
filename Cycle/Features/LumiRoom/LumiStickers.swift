import Foundation

/// An emoji sticker placed around Lumi in her room. `x` and `y` are fractions of the stage
/// around her, so stickers stay in place on any screen size.
struct LumiSticker: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var emoji: String
    var x: Double
    var y: Double
    var scale: Double = 1
}

/// Every sticker in Lumi's room. Saved on this iPhone as JSON. Plain value so it can be tested.
struct LumiStickerBoard: Equatable, Sendable, RawRepresentable {
    static let storageKey = "lumi.stickers"
    static let limit = 20
    static let scaleRange = 0.6...2.2
    static let choices = ["💖", "✨", "🌙", "⭐️", "🌸", "🦋", "🍓", "🌈", "☁️", "🎀", "🍄", "🔮", "🧁", "🌷", "🐾", "💫", "🍒", "🫧"]

    /// Where new stickers land: around Lumi, never on her face. Then the user drags them anywhere.
    static let spots: [(x: Double, y: Double)] = [
        (0.16, 0.18), (0.84, 0.20), (0.10, 0.55), (0.90, 0.55), (0.20, 0.88),
        (0.80, 0.88), (0.30, 0.06), (0.70, 0.06), (0.06, 0.34), (0.94, 0.36),
    ]

    private(set) var stickers: [LumiSticker]

    init(_ stickers: [LumiSticker] = []) {
        self.stickers = Array(stickers.prefix(Self.limit))
    }

    init(rawValue: String) {
        let decoded = try? JSONDecoder().decode([LumiSticker].self, from: Data(rawValue.utf8))
        self.init(decoded ?? [])
    }

    var rawValue: String {
        guard let data = try? JSONEncoder().encode(stickers) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }

    var isFull: Bool { stickers.count >= Self.limit }

    func adding(_ emoji: String) -> LumiStickerBoard {
        guard !isFull else { return self }
        let spot = Self.spots[stickers.count % Self.spots.count]
        return LumiStickerBoard(stickers + [LumiSticker(emoji: emoji, x: spot.x, y: spot.y)])
    }

    /// Moves a sticker, keeping it inside the stage.
    func moving(_ id: LumiSticker.ID, toX x: Double, y: Double) -> LumiStickerBoard {
        updating(id) { sticker in
            sticker.x = min(max(x, 0.04), 0.96)
            sticker.y = min(max(y, 0.04), 0.96)
        }
    }

    func resizing(_ id: LumiSticker.ID, to scale: Double) -> LumiStickerBoard {
        updating(id) { sticker in
            sticker.scale = min(max(scale, Self.scaleRange.lowerBound), Self.scaleRange.upperBound)
        }
    }

    func removing(_ id: LumiSticker.ID) -> LumiStickerBoard {
        LumiStickerBoard(stickers.filter { $0.id != id })
    }

    private func updating(_ id: LumiSticker.ID, _ change: (inout LumiSticker) -> Void) -> LumiStickerBoard {
        var copy = stickers
        if let index = copy.firstIndex(where: { $0.id == id }) {
            change(&copy[index])
        }
        return LumiStickerBoard(copy)
    }
}
