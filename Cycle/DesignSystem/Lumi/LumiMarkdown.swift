import Foundation

/// Turns the Markdown Lumi's AI writes into styled text for her chat bubbles: `**bold**`,
/// `*italic*`, bullets (`* `, `- `, `+ ` → •) and headings (`## Title` → a bold line).
/// The stored message keeps the raw text; only what's shown is styled.
enum LumiMarkdown {
    static func attributed(_ text: String) -> AttributedString {
        let source = text.components(separatedBy: "\n").map(normalize).joined(separator: "\n")
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            // While a reply streams in, an unfinished `**` just shows as typed.
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: source, options: options)) ?? AttributedString(text)
    }

    /// The text without Markdown symbols, for VoiceOver.
    static func plain(_ text: String) -> String {
        String(attributed(text).characters)
    }

    /// One line as Lumi shows it: list markers become •, headings become bold.
    static func normalize(_ line: String) -> String {
        let indent = String(line.prefix { $0 == " " })
        let content = line.dropFirst(indent.count)

        for marker in ["* ", "- ", "+ "] where content.hasPrefix(marker) {
            let item = content.dropFirst(marker.count).drop { $0 == " " }
            return indent + "• " + item
        }

        if content.hasPrefix("#") {
            let title = content.drop { $0 == "#" }
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "**", with: "")
            return title.isEmpty ? "" : "**\(title)**"
        }
        return line
    }
}
