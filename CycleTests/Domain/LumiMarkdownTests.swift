import Foundation
import Testing
@testable import Cycle

@Suite("Lumi Markdown")
struct LumiMarkdownTests {
    private func boldRuns(_ text: String) -> [String] {
        let styled = LumiMarkdown.attributed(text)
        return styled.runs.compactMap { run in
            run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true
                ? String(styled[run.range].characters) : nil
        }
    }

    @Test("Double stars become bold and disappear")
    func bold() {
        #expect(boldRuns("Try **Gentle Stretching:** today") == ["Gentle Stretching:"])
        #expect(LumiMarkdown.plain("Try **Gentle Stretching:** today") == "Try Gentle Stretching: today")
    }

    @Test("List markers become bullets, keeping line breaks")
    func bullets() {
        let text = "Ideas:\n*   **Stretch:** 5 minutes\n- Water 💧\n+ Rest"
        #expect(LumiMarkdown.plain(text) == "Ideas:\n• Stretch: 5 minutes\n• Water 💧\n• Rest")
        #expect(boldRuns(text) == ["Stretch:"])
    }

    @Test("Headings become a bold line")
    func headings() {
        #expect(LumiMarkdown.normalize("## **Tips for today**") == "**Tips for today**")
        #expect(boldRuns("### Food\nSnacks") == ["Food"])
        #expect(LumiMarkdown.normalize("#") == "")
    }

    @Test("Plain text, numbers and an unfinished ** stay readable")
    func plainText() {
        #expect(LumiMarkdown.plain("Hello 🌙") == "Hello 🌙")
        #expect(LumiMarkdown.plain("1. Water\n2. Sleep") == "1. Water\n2. Sleep")
        #expect(LumiMarkdown.plain("Still **typing").contains("typing"))
    }
}
