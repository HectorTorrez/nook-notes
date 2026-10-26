import AppKit
import Foundation
import Testing

@testable import Blink

@MainActor
struct RichTextSanitizerTests {
    @Test
    func replacesForeignTypographyAndColors() throws {
        let source = NSMutableAttributedString(string: "Hello")
        let range = NSRange(location: 0, length: source.length)
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 4
        source.addAttributes(
            [
                .font: NSFont(name: "Helvetica", size: 42) ?? NSFont.systemFont(ofSize: 42),
                .foregroundColor: NSColor.red,
                .backgroundColor: NSColor.yellow,
                .shadow: shadow,
            ],
            range: range
        )

        let sanitized = RichTextSanitizer.sanitize(
            source,
            fontSize: 16,
            family: .system
        )

        let font = try #require(sanitized.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        let color = try #require(
            sanitized.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        )

        #expect(font.pointSize == 16)
        #expect(color.isEqual(NSColor.labelColor))
        #expect(sanitized.attribute(.backgroundColor, at: 0, effectiveRange: nil) == nil)
        #expect(sanitized.attribute(.shadow, at: 0, effectiveRange: nil) == nil)
    }

    @Test
    func preservesSupportedCharacterAndParagraphStyles() throws {
        let source = NSMutableAttributedString(string: "Bold link")
        let boldRange = NSRange(location: 0, length: 4)
        let linkRange = NSRange(location: 5, length: 4)
        source.addAttribute(
            .font,
            value: RichTextFont.make(size: 30, bold: true, italic: false, code: false),
            range: boldRange
        )
        source.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: boldRange)
        source.addAttribute(.link, value: "example.com", range: linkRange)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.textLists = [NSTextList(markerFormat: .disc, options: 0)]
        source.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: source.length)
        )

        let sanitized = RichTextSanitizer.sanitize(source, fontSize: 16, family: .system)
        let font = try #require(sanitized.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        let style = try #require(
            sanitized.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        )

        #expect(NSFontManager.shared.traits(of: font).contains(.boldFontMask))
        #expect(sanitized.attribute(.underlineStyle, at: 0, effectiveRange: nil) != nil)
        #expect(sanitized.attribute(.link, at: 5, effectiveRange: nil) as? String == "https://example.com")
        #expect(style.textLists.count == 1)
        #expect(style.lineSpacing == NotesTextEditor.lineSpacing)
    }

    @Test
    func keepsHeadingsCodeAndQuotes() throws {
        let source = NSMutableAttributedString(string: "Heading\ncode")
        let fullRange = NSRange(location: 0, length: source.length)
        source.addAttribute(.blinkHeading, value: HeadingLevel.heading3.rawValue, range: fullRange)
        source.addAttribute(.blinkCode, value: true, range: fullRange)
        source.addAttribute(.blinkBlockquote, value: true, range: fullRange)

        let sanitized = RichTextSanitizer.sanitize(source, fontSize: 20, family: .system)
        let font = try #require(sanitized.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)

        #expect(sanitized.attribute(.blinkHeading, at: 0, effectiveRange: nil) as? Int == 3)
        #expect(sanitized.attribute(.blinkCode, at: 0, effectiveRange: nil) as? Bool == true)
        #expect(sanitized.attribute(.blinkBlockquote, at: 0, effectiveRange: nil) as? Bool == true)
        #expect(font.pointSize == HeadingLevel.heading3.size(base: 20))
        #expect(font.isFixedPitch)
    }

    @Test
    func dropsImageAttachments() {
        let source = NSMutableAttributedString(string: "A")
        source.append(NSAttributedString(attachment: NSTextAttachment()))
        source.append(NSAttributedString(string: "B"))

        let sanitized = RichTextSanitizer.sanitize(source, fontSize: 16, family: .system)

        #expect(sanitized.string == "AB")
    }

    @Test
    func readsAndSanitizesRTFFromThePasteboard() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("BlinkTests-\(UUID().uuidString)"))
        pasteboard.clearContents()

        let source = NSAttributedString(
            string: "Pasted",
            attributes: [
                .font: NSFont.systemFont(ofSize: 40),
                .foregroundColor: NSColor.red,
            ]
        )
        let data = try source.data(
            from: NSRange(location: 0, length: source.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        #expect(pasteboard.setData(data, forType: .rtf))

        let read = try #require(
            RichTextSanitizer.richText(from: pasteboard, fontSize: 16, family: .serif)
        )
        let font = try #require(read.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)

        #expect(read.string == "Pasted")
        #expect(font.pointSize == 16)
    }

    @Test
    func prefersBlinkRichTextOverRTF() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("BlinkTests-\(UUID().uuidString)"))
        pasteboard.clearContents()

        let source = NSMutableAttributedString(string: "Heading")
        source.addAttribute(
            .blinkHeading,
            value: HeadingLevel.heading1.rawValue,
            range: NSRange(location: 0, length: source.length)
        )
        let data = try #require(RichTextCoding.data(from: source))
        #expect(pasteboard.setData(data, forType: .blinkRichText))

        let read = try #require(
            RichTextSanitizer.richText(from: pasteboard, fontSize: 16, family: .system)
        )

        #expect(read.attribute(.blinkHeading, at: 0, effectiveRange: nil) as? Int == 1)
    }

    @Test
    func linkNormalizationAddsASchemeOnlyWhenNeeded() {
        #expect(RichTextLink.normalized("example.com") == "https://example.com")
        #expect(RichTextLink.normalized("https://example.com") == "https://example.com")
        #expect(RichTextLink.normalized("mailto:hi@example.com") == "mailto:hi@example.com")
        #expect(RichTextLink.normalized("   ") == nil)
        #expect(RichTextLink.normalized(nil) == nil)
    }
}
