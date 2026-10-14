import AppKit
import Observation

/// Bridges the AppKit text view and SwiftUI formatting chrome. It mirrors the
/// formatting at the caret so the toolbar can highlight the active styles, and
/// applies the toolbar's commands back onto the selected text.
@MainActor
@Observable
final class RichTextController {
    @ObservationIgnored weak var textView: NSTextView?
    @ObservationIgnored var baseFontSize: CGFloat = 16

    private(set) var hasSelection = false
    private(set) var heading: HeadingLevel?
    private(set) var isBold = false
    private(set) var isItalic = false
    private(set) var isUnderlined = false
    private(set) var isStruckThrough = false
    private(set) var isCode = false
    private(set) var isBlockquote = false
    private(set) var listStyle: ListStyle?
    private(set) var alignment: NSTextAlignment = .natural
    private(set) var link: String?

    func attach(_ textView: NSTextView) {
        self.textView = textView
        refresh()
    }

    // MARK: - State

    func refresh() {
        guard let textView else { return }
        let selection = textView.selectedRange()
        hasSelection = selection.length > 0

        guard let storage = textView.textStorage, storage.length > 0 else {
            resetAttributes()
            return
        }

        let probe = min(max(0, selection.location), storage.length - 1)
        let attributes = storage.attributes(at: probe, effectiveRange: nil)
        let font = attributes[.font] as? NSFont
        let traits = font.map { NSFontManager.shared.traits(of: $0) } ?? []

        isBold = traits.contains(.boldFontMask)
        isItalic = traits.contains(.italicFontMask)
        isUnderlined = (attributes[.underlineStyle] as? Int).map { $0 != 0 } ?? false
        isStruckThrough = (attributes[.strikethroughStyle] as? Int).map { $0 != 0 } ?? false
        isCode = attributes[.blinkCode] != nil
        isBlockquote = attributes[.blinkBlockquote] != nil
        heading = (attributes[.blinkHeading] as? Int).flatMap(HeadingLevel.init(rawValue:))
        link = attributes[.link] as? String
        if let style = attributes[.paragraphStyle] as? NSParagraphStyle {
            alignment = style.alignment
            listStyle = style.textLists.first.flatMap { ListStyle(markerFormat: $0.markerFormat) }
        } else {
            alignment = .natural
            listStyle = nil
        }
    }

    private func resetAttributes() {
        heading = nil
        isBold = false
        isItalic = false
        isUnderlined = false
        isStruckThrough = false
        isCode = false
        isBlockquote = false
        listStyle = nil
        alignment = .natural
        link = nil
    }

    // MARK: - Paragraph styles

    func setHeading(_ level: HeadingLevel) {
        let target = (heading == level) ? nil : level
        editParagraphs { storage, range in
            if let target {
                storage.addAttribute(.blinkHeading, value: target.rawValue, range: range)
            } else {
                storage.removeAttribute(.blinkHeading, range: range)
            }
            self.rewriteFonts(in: range, storage: storage)
        }
    }

    func setList(_ style: ListStyle) {
        let target = (listStyle == style) ? nil : style
        editParagraphs { storage, range in
            let style = self.mutableParagraphStyle(at: range, storage: storage)
            if let target {
                let list = NSTextList(markerFormat: target.markerFormat, options: 0)
                list.startingItemNumber = 1
                style.textLists = [list]
                style.headIndent = 22
                style.firstLineHeadIndent = 0
                style.tabStops = [NSTextTab(textAlignment: .left, location: 22)]
            } else {
                style.textLists = []
                style.headIndent = 0
                style.firstLineHeadIndent = 0
                style.tabStops = []
            }
            storage.addAttribute(.paragraphStyle, value: style, range: range)
        }
    }

    func toggleBlockquote() {
        let applying = !isBlockquote
        editParagraphs { storage, range in
            let style = self.mutableParagraphStyle(at: range, storage: storage)
            if applying {
                storage.addAttribute(.blinkBlockquote, value: true, range: range)
                style.headIndent = 16
                style.firstLineHeadIndent = 16
            } else {
                storage.removeAttribute(.blinkBlockquote, range: range)
                style.headIndent = 0
                style.firstLineHeadIndent = 0
            }
            storage.addAttribute(.paragraphStyle, value: style, range: range)
        }
    }

    func setAlignment(_ value: NSTextAlignment) {
        editParagraphs { storage, range in
            let style = self.mutableParagraphStyle(at: range, storage: storage)
            style.alignment = value
            storage.addAttribute(.paragraphStyle, value: style, range: range)
        }
    }

    // MARK: - Character styles

    func toggleBold() { toggleTrait(.boldFontMask, set: !isBold) }
    func toggleItalic() { toggleTrait(.italicFontMask, set: !isItalic) }

    func toggleUnderline() {
        setCharacterAttribute(.underlineStyle, value: isUnderlined ? nil : NSUnderlineStyle.single.rawValue)
    }

    func toggleStrikethrough() {
        setCharacterAttribute(.strikethroughStyle, value: isStruckThrough ? nil : NSUnderlineStyle.single.rawValue)
    }

    func toggleCode() {
        let applying = !isCode
        editSelection { storage, range in
            if applying {
                storage.addAttribute(.blinkCode, value: true, range: range)
            } else {
                storage.removeAttribute(.blinkCode, range: range)
            }
            self.rewriteFonts(in: range, storage: storage)
        }
    }

    func applyLink(_ value: String?) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        editSelection { storage, range in
            if let trimmed, !trimmed.isEmpty {
                storage.addAttribute(.link, value: trimmed, range: range)
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            } else {
                storage.removeAttribute(.link, range: range)
                storage.removeAttribute(.underlineStyle, range: range)
            }
        }
    }

    // MARK: - Editing helpers

    private func editParagraphs(_ body: (NSTextStorage, NSRange) -> Void) {
        guard let storage = textView?.textStorage, storage.length > 0 else { return }
        let range = paragraphRange(in: storage)
        storage.beginEditing()
        body(storage, range)
        storage.endEditing()
        finishEdit(around: range)
    }

    private func editSelection(_ body: (NSTextStorage, NSRange) -> Void) {
        guard let storage = textView?.textStorage, storage.length > 0 else { return }
        let range = textView?.selectedRange() ?? NSRange()
        guard range.length > 0 else { return }
        storage.beginEditing()
        body(storage, range)
        storage.endEditing()
        finishEdit(around: range)
    }

    private func setCharacterAttribute(_ key: NSAttributedString.Key, value: Any?) {
        editSelection { storage, range in
            if let value {
                storage.addAttribute(key, value: value, range: range)
            } else {
                storage.removeAttribute(key, range: range)
            }
        }
    }

    private func toggleTrait(_ trait: NSFontTraitMask, set: Bool) {
        editSelection { storage, range in
            var updates: [(NSRange, NSFont)] = []
            storage.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
                let current = value as? NSFont
                let existing = current.map { NSFontManager.shared.traits(of: $0) } ?? []
                var traits = existing
                if set {
                    traits.insert(trait)
                } else {
                    traits.remove(trait)
                }
                let font = RichTextFont.make(
                    size: current?.pointSize ?? self.baseFontSize,
                    bold: traits.contains(.boldFontMask),
                    italic: traits.contains(.italicFontMask),
                    code: storage.attribute(.blinkCode, at: subrange.location, effectiveRange: nil) != nil
                )
                updates.append((subrange, font))
            }
            for (subrange, font) in updates {
                storage.addAttribute(.font, value: font, range: subrange)
            }
        }
    }

    /// Recomputes every run's font from its heading, code and trait flags.
    private func rewriteFonts(in range: NSRange, storage: NSTextStorage) {
        var updates: [(NSRange, NSFont)] = []
        storage.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
            let current = value as? NSFont
            let traits = current.map { NSFontManager.shared.traits(of: $0) } ?? []
            let level = (storage.attribute(.blinkHeading, at: subrange.location, effectiveRange: nil) as? Int)
                .flatMap(HeadingLevel.init(rawValue:))
            let code = storage.attribute(.blinkCode, at: subrange.location, effectiveRange: nil) != nil
            let size = level?.size(base: self.baseFontSize) ?? current?.pointSize ?? self.baseFontSize
            let font = RichTextFont.make(
                size: size,
                bold: level != nil || traits.contains(.boldFontMask),
                italic: traits.contains(.italicFontMask),
                code: code
            )
            updates.append((subrange, font))
        }
        for (subrange, font) in updates {
            storage.addAttribute(.font, value: font, range: subrange)
        }
    }

    /// Called when the appearance font size changes so body and heading runs rescale.
    func restyleFonts() {
        guard let textView, let storage = textView.textStorage, storage.length > 0 else { return }
        let range = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        rewriteFonts(in: range, storage: storage)
        storage.endEditing()
        syncTypingAttributes()
    }

    private func mutableParagraphStyle(at range: NSRange, storage: NSTextStorage) -> NSMutableParagraphStyle {
        let existing = storage.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle
        let style = NSMutableParagraphStyle()
        style.lineSpacing = NotesTextEditor.lineSpacing
        if let existing {
            style.setParagraphStyle(existing)
        }
        return style
    }

    private func paragraphRange(in storage: NSTextStorage) -> NSRange {
        let selection = textView?.selectedRange() ?? NSRange()
        let length = storage.length
        guard length > 0 else { return NSRange(location: 0, length: 0) }
        let location = min(max(0, selection.location), length - 1)
        let end = min(max(selection.location + selection.length, location + 1), length)
        return (storage.string as NSString).paragraphRange(for: NSRange(location: location, length: end - location))
    }

    private func finishEdit(around range: NSRange) {
        syncTypingAttributes()
        textView?.didChangeText()
        textView?.window?.makeFirstResponder(textView)
        refresh()
    }

    private func syncTypingAttributes() {
        guard let textView, let storage = textView.textStorage, storage.length > 0 else { return }
        let selection = textView.selectedRange()
        let probe = min(max(0, selection.location + selection.length - 1), storage.length - 1)
        textView.typingAttributes = storage.attributes(at: probe, effectiveRange: nil)
    }

    /// Drops the selection so the formatting bar can collapse.
    func dismiss() {
        guard let textView else { return }
        let selection = textView.selectedRange()
        textView.setSelectedRange(NSRange(location: selection.location + selection.length, length: 0))
        hasSelection = false
    }
}
