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

    @Test
    func changingBaseFontSizeRescalesBodyAndHeadingRuns() throws {
        let textView = makeTextView("Body\nHeading")
        let controller = RichTextController()
        controller.baseFontSize = 16
        controller.attach(textView)

        textView.setSelectedRange(NSRange(location: 5, length: 0))
        controller.selectionDidChange()
        controller.setHeading(.heading1)

        controller.baseFontSize = 21
        controller.restyleFonts()

        let storage = try #require(textView.textStorage)
        let body = try #require(storage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        let heading = try #require(storage.attribute(.font, at: 5, effectiveRange: nil) as? NSFont)

        #expect(body.pointSize == 21)
        #expect(heading.pointSize == 36)
    }

    @Test
    func caretFormattingUpdatesTypingAttributesWithoutChangingText() throws {
        let textView = makeTextView("Hello")
        let controller = RichTextController()
        controller.baseFontSize = 16
        controller.attach(textView)

        textView.setSelectedRange(NSRange(location: 2, length: 0))
        controller.selectionDidChange()
        controller.toggleBold()

        let typingFont = try #require(textView.typingAttributes[.font] as? NSFont)
        #expect(NSFontManager.shared.traits(of: typingFont).contains(.boldFontMask))

        let storage = try #require(textView.textStorage)
        let storedFont = try #require(storage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        #expect(NSFontManager.shared.traits(of: storedFont).contains(.boldFontMask) == false)
    }

    @Test
    func formattingIsUndoableAndRedoable() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let textView = makeTextView("Hello", in: window)
        textView.allowsUndo = true
        textView.undoManager?.removeAllActions()
        textView.setSelectedRange(NSRange(location: 0, length: 5))

        let controller = RichTextController()
        controller.baseFontSize = 16
        controller.attach(textView)
        controller.selectionDidChange()
        controller.toggleBold()

        #expect(isBold(0, in: textView))

        textView.undoManager?.undo()
        #expect(isBold(0, in: textView) == false)

        textView.undoManager?.redo()
        #expect(isBold(0, in: textView))
    }

    @Test
    func listAndQuoteFormattingShareIndentationWithoutFighting() throws {
        let textView = makeTextView("A list item")
        let controller = RichTextController()
        controller.baseFontSize = 16
        controller.attach(textView)
        controller.selectionDidChange()

        controller.setList(.bullet)
        controller.toggleBlockquote()

        let storage = try #require(textView.textStorage)
        let quotedList = try #require(
            storage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        )
        #expect(quotedList.lineSpacing == NotesTextEditor.lineSpacing)
        #expect(quotedList.headIndent == 38)
        #expect(quotedList.firstLineHeadIndent == 16)

        controller.setList(.bullet)

        let quoteOnly = try #require(
            storage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        )
        #expect(quoteOnly.headIndent == 16)
        #expect(quoteOnly.firstLineHeadIndent == 16)
    }

    private func makeTextView(_ string: String, in window: NSWindow? = nil) -> NSTextView {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        if let window {
            window.contentView = textView
        }
        textView.string = string
        textView.textStorage?.setAttributes(
            NotesTextEditor.baseAttributes(fontSize: 16),
            range: NSRange(location: 0, length: (string as NSString).length)
        )
        return textView
    }

    private func isBold(_ index: Int, in textView: NSTextView) -> Bool {
        guard let font = textView.textStorage?.attribute(.font, at: index, effectiveRange: nil) as? NSFont else {
            return false
        }
        return NSFontManager.shared.traits(of: font).contains(.boldFontMask)
    }
}
