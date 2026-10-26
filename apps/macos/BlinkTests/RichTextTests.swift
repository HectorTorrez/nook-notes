import AppKit
import Foundation
import Testing

@testable import Blink

@MainActor
struct RichTextTests {
    @Test
    func archiveRoundTripsFormattingAndLinks() throws {
        let string = NSMutableAttributedString(string: "Heading\nbody code")
        let fullRange = NSRange(location: 0, length: string.length)
        string.addAttribute(.font, value: NSFont.systemFont(ofSize: 16), range: fullRange)
        string.addAttribute(.blinkHeading, value: HeadingLevel.heading1.rawValue, range: NSRange(location: 0, length: 7))
        string.addAttribute(.blinkBlockquote, value: true, range: NSRange(location: 8, length: 4))
        string.addAttribute(.blinkCode, value: true, range: NSRange(location: 13, length: 4))
        string.addAttribute(.link, value: "https://example.com", range: NSRange(location: 13, length: 4))

        let data = try #require(RichTextCoding.data(from: string))
        let decoded = try #require(RichTextCoding.attributedString(from: data))

        #expect(decoded.string == string.string)
        #expect(decoded.attribute(.blinkHeading, at: 0, effectiveRange: nil) as? Int == 1)
        #expect(decoded.attribute(.blinkBlockquote, at: 8, effectiveRange: nil) as? Bool == true)
        #expect(decoded.attribute(.blinkCode, at: 13, effectiveRange: nil) as? Bool == true)
        #expect(decoded.attribute(.link, at: 13, effectiveRange: nil) as? String == "https://example.com")
    }

    @Test
    func fontBuilderAppliesBoldItalicAndCodeTraits() {
        let bold = RichTextFont.make(size: 16, bold: true, italic: false, code: false)
        #expect(NSFontManager.shared.traits(of: bold).contains(.boldFontMask))

        let italic = RichTextFont.make(size: 16, bold: false, italic: true, code: false)
        #expect(NSFontManager.shared.traits(of: italic).contains(.italicFontMask))

        let code = RichTextFont.make(size: 16, bold: false, italic: false, code: true)
        #expect(code.isFixedPitch)
    }

    @Test
    func textListStylesMapBackFromTheirMarkerFormats() {
        #expect(ListStyle(markerFormat: .decimal) == .ordered)
        #expect(ListStyle(markerFormat: .disc) == .bullet)
        #expect(ListStyle(markerFormat: .box) == .task)
        #expect(ListStyle(markerFormat: .check) == .task)
        #expect(ListStyle(markerFormat: .hyphen) == nil)
    }
}
