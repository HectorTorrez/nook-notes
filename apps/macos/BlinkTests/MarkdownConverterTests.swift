import AppKit
import Foundation
import Testing

@testable import Blink

@MainActor
struct MarkdownConverterTests {
    private let regular = NSFont.systemFont(ofSize: 16)
    private let bold = NSFont.systemFont(ofSize: 16, weight: .semibold)
    private let code = NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)

    @Test
    func convertsSupportedStylesToMarkdown() {
        let attributed = NSMutableAttributedString()

        append("Title", to: attributed, attributes: [
            .font: NSFont.systemFont(ofSize: 27, weight: .semibold),
            .blinkHeading: HeadingLevel.heading1.rawValue,
        ])
        appendNewline(to: attributed)

        append("Bold", to: attributed, attributes: [.font: bold])
        append(" and ", to: attributed, attributes: [.font: regular])
        append("code", to: attributed, attributes: [
            .font: code,
            .blinkCode: true,
        ])
        appendNewline(to: attributed)

        append("Item", to: attributed, attributes: [.font: regular], list: .disc)
        appendNewline(to: attributed)

        append("Done", to: attributed, attributes: [.font: regular], list: .check)
        appendNewline(to: attributed)

        append("Quoted", to: attributed, attributes: [
            .font: regular,
            .blinkBlockquote: true,
        ], quote: true)
        appendNewline(to: attributed)

        append("Example", to: attributed, attributes: [
            .font: regular,
            .link: "https://example.com",
        ])

        let markdown = MarkdownConverter.markdown(from: attributed)

        #expect(markdown.contains("# Title"))
        #expect(markdown.contains("**Bold**"))
        #expect(markdown.contains("`code`"))
        #expect(markdown.contains("- Item"))
        #expect(markdown.contains("- [x] Done"))
        #expect(markdown.contains("> Quoted"))
        #expect(markdown.contains("[Example](https://example.com)"))
        #expect(markdown.contains("**Title**") == false)
    }

    @Test
    func plainNotesFallBackToTheirContent() {
        let note = Note(content: "Plain text", createdAt: Date(timeIntervalSince1970: 0))

        #expect(note.markdown == "Plain text")
    }

    @Test
    func copyWritesPlainRichAndMarkdownPayloads() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("BlinkTests-\(UUID().uuidString)"))
        let rich = NSMutableAttributedString(
            string: "Hello",
            attributes: [
                .font: bold,
                .blinkHeading: HeadingLevel.heading1.rawValue,
            ]
        )
        let data = try #require(RichTextCoding.data(from: rich))
        let note = Note(content: "Hello", richTextData: data, createdAt: Date(timeIntervalSince1970: 0))

        note.copyToPasteboard(pasteboard)

        #expect(pasteboard.string(forType: .string) == "Hello")
        #expect(pasteboard.data(forType: .rtf) != nil)
        #expect(pasteboard.data(forType: .html) != nil)
        #expect(pasteboard.data(forType: .blinkRichText) == data)

        note.copyMarkdownToPasteboard(pasteboard)

        #expect(pasteboard.string(forType: .string) == "# Hello")
        #expect(pasteboard.data(forType: .rtf) == nil)
    }

    private func append(
        _ text: String,
        to attributed: NSMutableAttributedString,
        attributes: [NSAttributedString.Key: Any],
        list: NSTextList.MarkerFormat? = nil,
        quote: Bool = false
    ) {
        var attributes = attributes
        let style = NSMutableParagraphStyle()
        style.lineSpacing = NotesTextEditor.lineSpacing

        if let list {
            style.textLists = [NSTextList(markerFormat: list, options: 0)]
            style.headIndent = 22
            style.firstLineHeadIndent = 0
            style.tabStops = [NSTextTab(textAlignment: .left, location: 22)]
        }
        if quote {
            style.headIndent = 16
            style.firstLineHeadIndent = 16
        }
        attributes[.paragraphStyle] = style

        attributed.append(NSAttributedString(string: text, attributes: attributes))
    }

    private func appendNewline(to attributed: NSMutableAttributedString) {
        let attributes = attributed.length > 0
            ? attributed.attributes(at: attributed.length - 1, effectiveRange: nil)
            : [NSAttributedString.Key: Any]()
        attributed.append(NSAttributedString(string: "\n", attributes: attributes))
    }
}
