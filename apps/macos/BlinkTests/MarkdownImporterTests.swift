import AppKit
import Foundation
import Testing

@testable import Blink

@MainActor
struct MarkdownImporterTests {
    @Test
    func parsesBlocksAndInlineStyles() throws {
        let source = """
        # Title

        Some **bold** and *italic* with `code` and [link](https://example.com).

        - Bullet
        - [x] Done
        - [ ] Todo
        1. First
        2. Second
        > Quoted
        """

        let attributed = MarkdownImporter.attributedString(
            from: source,
            fontSize: 16,
            family: .system
        )
        let text = attributed.string as NSString

        let titleIndex = text.range(of: "Title").location
        let boldIndex = text.range(of: "bold").location
        let italicIndex = text.range(of: "italic").location
        let codeIndex = text.range(of: "code").location
        let linkIndex = text.range(of: "link").location
        let bulletIndex = text.range(of: "Bullet").location
        let doneIndex = text.range(of: "Done").location
        let todoIndex = text.range(of: "Todo").location
        let firstIndex = text.range(of: "First").location
        let secondIndex = text.range(of: "Second").location
        let quotedIndex = text.range(of: "Quoted").location

        #expect(attributed.attribute(.blinkHeading, at: titleIndex, effectiveRange: nil) as? Int == 1)

        let boldFont = try #require(
            attributed.attribute(.font, at: boldIndex, effectiveRange: nil) as? NSFont
        )
        #expect(NSFontManager.shared.traits(of: boldFont).contains(.boldFontMask))

        let italicFont = try #require(
            attributed.attribute(.font, at: italicIndex, effectiveRange: nil) as? NSFont
        )
        #expect(NSFontManager.shared.traits(of: italicFont).contains(.italicFontMask))

        #expect(attributed.attribute(.blinkCode, at: codeIndex, effectiveRange: nil) as? Bool == true)
        #expect(
            attributed.attribute(.link, at: linkIndex, effectiveRange: nil) as? String
                == "https://example.com"
        )

        #expect(marker(at: bulletIndex, in: attributed) == .disc)
        #expect(marker(at: doneIndex, in: attributed) == .check)
        #expect(marker(at: todoIndex, in: attributed) == .box)
        #expect(marker(at: firstIndex, in: attributed) == .decimal)
        #expect(marker(at: secondIndex, in: attributed) == .decimal)

        let firstList = try #require(paragraphStyle(at: firstIndex, in: attributed)?.textLists.first)
        let secondList = try #require(paragraphStyle(at: secondIndex, in: attributed)?.textLists.first)
        #expect(firstList === secondList)

        #expect(
            attributed.attribute(.blinkBlockquote, at: quotedIndex, effectiveRange: nil) as? Bool
                == true
        )
    }

    @Test
    func leavesPlainTextIntact() {
        let attributed = MarkdownImporter.attributedString(from: "Just text")

        #expect(attributed.string == "Just text")
        #expect(attributed.attribute(.blinkHeading, at: 0, effectiveRange: nil) == nil)
    }

    private func paragraphStyle(
        at index: Int,
        in attributed: NSAttributedString
    ) -> NSParagraphStyle? {
        attributed.attribute(.paragraphStyle, at: index, effectiveRange: nil) as? NSParagraphStyle
    }

    private func marker(
        at index: Int,
        in attributed: NSAttributedString
    ) -> NSTextList.MarkerFormat? {
        paragraphStyle(at: index, in: attributed)?.textLists.first?.markerFormat
    }
}
