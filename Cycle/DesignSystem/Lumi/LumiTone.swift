import Foundation

/// Picks Lumi's sticker expression for a chat reply from simple, kind keyword hints.
/// Matches whole words (so "steadier" doesn't count as "tea"); phrases are matched as written.
enum LumiTone {
    private static let sad: Set<String> = ["sorry", "tough", "overwhelmed", "overwhelming", "clinician", "doctor", "worry", "worried", "worrying"]
    private static let sadPhrases = ["hard day", "feels hard"]
    private static let tired: Set<String> = ["sleep", "sleepy", "rest", "resting", "nap", "tired", "bed", "bedtime"]
    private static let tiredPhrases = ["slow down"]
    private static let calm: Set<String> = ["breathe", "breath", "breathing", "calm", "calming", "relax", "relaxing", "gentle", "tea", "quiet", "journal", "journaling"]

    static func feeling(for reply: String) -> Feeling {
        let text = reply.lowercased()
        let words = Set(text.split { !$0.isLetter }.map(String.init))

        if !words.isDisjoint(with: sad) || sadPhrases.contains(where: text.contains) { return .sad }
        if !words.isDisjoint(with: tired) || tiredPhrases.contains(where: text.contains) { return .tired }
        if !words.isDisjoint(with: calm) { return .calm }
        return .happy
    }
}
