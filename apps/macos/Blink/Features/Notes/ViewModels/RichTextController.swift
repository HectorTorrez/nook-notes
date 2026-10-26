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
    @ObservationIgnored var fontFamily: EditorFontFamily = .system

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
            apply(attributes: baseTypingAttributes())
            return
        }

        // While typing, the caret's typing attributes are the ones the next
        // character will use. They also keep caret-only toggles reflected in
        // the toolbar until the selection moves.
        if !hasSelection, textView.typingAttributes[.font] != nil {
            apply(attributes: textView.typingAttributes)
            return
        }

        let probe = min(max(0, selection.location), storage.length - 1)
        apply(attributes: storage.attributes(at: probe, effectiveRange: nil))
    }

    /// Called when the selection changes so typing attributes are rebuilt from
    /// the character next to the caret instead of carrying a stale style.
    func selectionDidChange() {
        syncTypingAttributes()
        refresh()
    }

    private func apply(attributes: [NSAttributedString.Key: Any]) {
        let font = attributes[.font] as? NSFont
        let traits = font.map { NSFontManager.shared.traits(of: $0) } ?? []

        isBold = traits.contains(.boldFontMask)
        isItalic = traits.contains(.italicFontMask)
        isUnderlined = (attributes[.underlineStyle] as? Int).map { $0 != 0 } ?? false
        isStruckThrough = (attributes[.strikethroughStyle] as? Int).map { $0 != 0 } ?? false
        isCode = attributes[.blinkCode] != nil
        isBlockquote = attributes[.blinkBlockquote] != nil
        heading = (attributes[.blinkHeading] as? Int).flatMap(HeadingLevel.init(rawValue:))

        if let value = attributes[.link] as? URL {
            link = value.absoluteString
        } else {
            link = attributes[.link] as? String
        }

        if let style = attributes[.paragraphStyle] as? NSParagraphStyle {
            alignment = style.alignment
            listStyle = style.textLists.first.flatMap { ListStyle(markerFormat: $0.markerFormat) }
        } else {
            alignment = .natural
            listStyle = nil
        }
    }

    // MARK: - Paragraph styles

    func setHeading(_ level: HeadingLevel) {
        let target = (heading == level) ? nil : level
        editParagraphs(actionName: "Heading") { storage, range in
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
        editParagraphs(actionName: "List") { storage, range in
            let paragraphStyle = self.mutableParagraphStyle(at: range, storage: storage)
            let quoted = storage.attribute(.blinkBlockquote, at: range.location, effectiveRange: nil) != nil
            if let target {
                let list = NSTextList(markerFormat: target.markerFormat, options: 0)
                list.startingItemNumber = 1
                paragraphStyle.textLists = [list]
            } else {
                paragraphStyle.textLists = []
            }
            self.applyIndentation(to: paragraphStyle, list: target != nil, quote: quoted)
            storage.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        }
    }

    func toggleBlockquote() {
        let applying = !isBlockquote
        editParagraphs(actionName: "Block Quote") { storage, range in
            let paragraphStyle = self.mutableParagraphStyle(at: range, storage: storage)
            let hasList = !paragraphStyle.textLists.isEmpty
            if applying {
                storage.addAttribute(.blinkBlockquote, value: true, range: range)
            } else {
                storage.removeAttribute(.blinkBlockquote, range: range)
            }
            self.applyIndentation(to: paragraphStyle, list: hasList, quote: applying)
            storage.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        }
    }

    func setAlignment(_ value: NSTextAlignment) {
        editParagraphs(actionName: "Alignment") { storage, range in
            let style = self.mutableParagraphStyle(at: range, storage: storage)
            style.alignment = value
            storage.addAttribute(.paragraphStyle, value: style, range: range)
        }
    }

    // MARK: - Character styles

    func toggleBold() {
        setTrait(.boldFontMask, applying: !isBold, actionName: "Bold")
    }

    func toggleItalic() {
        setTrait(.italicFontMask, applying: !isItalic, actionName: "Italic")
    }

    func toggleUnderline() {
        setCharacterAttribute(
            .underlineStyle,
            value: isUnderlined ? nil : NSUnderlineStyle.single.rawValue,
            actionName: "Underline"
        )
    }

    func toggleStrikethrough() {
        setCharacterAttribute(
            .strikethroughStyle,
            value: isStruckThrough ? nil : NSUnderlineStyle.single.rawValue,
            actionName: "Strikethrough"
        )
    }

    func toggleCode() {
        let applying = !isCode
        if hasSelection {
            editSelection(actionName: "Code") { storage, range in
                if applying {
                    storage.addAttribute(.blinkCode, value: true, range: range)
                } else {
                    storage.removeAttribute(.blinkCode, range: range)
                }
                self.rewriteFonts(in: range, storage: storage)
            }
        } else {
            var attributes = typingAttributes()
            if applying {
                attributes[.blinkCode] = true
            } else {
                attributes.removeValue(forKey: .blinkCode)
            }
            attributes[.font] = font(for: attributes)
            textView?.typingAttributes = attributes
            refresh()
        }
    }

    /// Adds or removes a link on the current selection. Returns `false` when
    /// there is no selection, since a link needs text to attach to.
    @discardableResult
    func applyLink(_ value: String?) -> Bool {
        guard hasSelection else { return false }
        let normalized = RichTextLink.normalized(value)
        editSelection(actionName: normalized == nil ? "Remove Link" : "Link") { storage, range in
            if let normalized {
                storage.addAttribute(.link, value: normalized, range: range)
            } else {
                storage.removeAttribute(.link, range: range)
            }
        }
        return true
    }

    // MARK: - Editing helpers

    private func editParagraphs(
        actionName: String = "Formatting",
        _ body: (NSTextStorage, NSRange) -> Void
    ) {
        guard let storage = textView?.textStorage, storage.length > 0 else { return }
        applyEdit(in: paragraphRange(in: storage), actionName: actionName, body)
    }

    private func editSelection(
        actionName: String = "Formatting",
        _ body: (NSTextStorage, NSRange) -> Void
    ) {
        guard let textView else { return }
        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        applyEdit(in: range, actionName: actionName, body)
    }

    private func applyEdit(
        in range: NSRange,
        actionName: String,
        _ body: (NSTextStorage, NSRange) -> Void
    ) {
        guard let textView, let storage = textView.textStorage, storage.length > 0 else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        let before = storage.attributedSubstring(from: fullRange)

        storage.beginEditing()
        body(storage, range)
        storage.endEditing()

        let after = storage.attributedSubstring(from: fullRange)
        if !before.isEqual(to: after) {
            registerUndo(restoring: before, actionName: actionName)
        }
        finishEdit()
    }

    private func setCharacterAttribute(
        _ key: NSAttributedString.Key,
        value: Any?,
        actionName: String
    ) {
        if hasSelection {
            editSelection(actionName: actionName) { storage, range in
                if let value {
                    storage.addAttribute(key, value: value, range: range)
                } else {
                    storage.removeAttribute(key, range: range)
                }
            }
        } else {
            var attributes = typingAttributes()
            if let value {
                attributes[key] = value
            } else {
                attributes.removeValue(forKey: key)
            }
            textView?.typingAttributes = attributes
            refresh()
        }
    }

    private func setTrait(_ trait: NSFontTraitMask, applying: Bool, actionName: String) {
        if hasSelection {
            editSelection(actionName: actionName) { storage, range in
                var updates: [(NSRange, NSFont)] = []
                storage.enumerateAttributes(in: range, options: []) { attributes, subrange, _ in
                    let current = attributes[.font] as? NSFont
                    var traits = current.map { NSFontManager.shared.traits(of: $0) } ?? []
                    if applying {
                        traits.insert(trait)
                    } else {
                        traits.remove(trait)
                    }
                    let font = RichTextFont.make(
                        size: self.normalizedSize(for: attributes),
                        bold: traits.contains(.boldFontMask),
                        italic: traits.contains(.italicFontMask),
                        code: attributes[.blinkCode] != nil,
                        family: self.fontFamily
                    )
                    updates.append((subrange, font))
                }
                for (subrange, font) in updates {
                    storage.addAttribute(.font, value: font, range: subrange)
                }
            }
        } else {
            var attributes = typingAttributes()
            var traits = NSFontManager.shared.traits(of: font(for: attributes))
            if applying {
                traits.insert(trait)
            } else {
                traits.remove(trait)
            }
            attributes[.font] = RichTextFont.make(
                size: normalizedSize(for: attributes),
                bold: traits.contains(.boldFontMask),
                italic: traits.contains(.italicFontMask),
                code: attributes[.blinkCode] != nil,
                family: fontFamily
            )
            textView?.typingAttributes = attributes
            refresh()
        }
    }

    /// Recomputes every run's font from its heading, code and trait flags.
    private func rewriteFonts(in range: NSRange, storage: NSTextStorage) {
        var updates: [(NSRange, NSFont)] = []
        storage.enumerateAttributes(in: range, options: []) { attributes, subrange, _ in
            let traits = (attributes[.font] as? NSFont).map { NSFontManager.shared.traits(of: $0) } ?? []
            let level = (attributes[.blinkHeading] as? Int).flatMap(HeadingLevel.init(rawValue:))
            let font = RichTextFont.make(
                size: self.normalizedSize(for: attributes),
                bold: level != nil || traits.contains(.boldFontMask),
                italic: traits.contains(.italicFontMask),
                code: attributes[.blinkCode] != nil,
                family: self.fontFamily
            )
            updates.append((subrange, font))
        }
        for (subrange, font) in updates {
            storage.addAttribute(.font, value: font, range: subrange)
        }
    }

    /// Called when the appearance font size changes so body and heading runs rescale.
    func restyleFonts() {
        guard let textView, let storage = textView.textStorage else { return }
        if storage.length > 0 {
            let range = NSRange(location: 0, length: storage.length)
            storage.beginEditing()
            rewriteFonts(in: range, storage: storage)
            storage.endEditing()
        }
        syncTypingAttributes()
    }

    private func mutableParagraphStyle(at range: NSRange, storage: NSTextStorage) -> NSMutableParagraphStyle {
        let existing = storage.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle
        let style = NSMutableParagraphStyle()
        if let existing {
            style.setParagraphStyle(existing)
        }
        style.lineSpacing = NotesTextEditor.lineSpacing
        return style
    }

    private func applyIndentation(
        to style: NSMutableParagraphStyle,
        list: Bool,
        quote: Bool
    ) {
        let listIndent: CGFloat = list ? 22 : 0
        let quoteIndent: CGFloat = quote ? 16 : 0
        style.headIndent = listIndent + quoteIndent
        style.firstLineHeadIndent = quoteIndent
        if list {
            style.tabStops = [NSTextTab(textAlignment: .left, location: listIndent + quoteIndent)]
        } else {
            style.tabStops = []
        }
    }

    private func paragraphRange(in storage: NSTextStorage) -> NSRange {
        let selection = textView?.selectedRange() ?? NSRange()
        let length = storage.length
        guard length > 0 else { return NSRange(location: 0, length: 0) }
        let location = min(max(0, selection.location), length - 1)
        let end = min(max(selection.location + selection.length, location + 1), length)
        return (storage.string as NSString).paragraphRange(for: NSRange(location: location, length: end - location))
    }

    private func finishEdit() {
        syncTypingAttributes()
        textView?.didChangeText()
        textView?.window?.makeFirstResponder(textView)
        refresh()
    }

    private func syncTypingAttributes() {
        guard let textView, let storage = textView.textStorage else { return }
        guard storage.length > 0 else {
            textView.typingAttributes = baseTypingAttributes()
            return
        }

        let selection = textView.selectedRange()
        let probe = min(max(0, selection.location + max(selection.length, 1) - 1), storage.length - 1)
        textView.typingAttributes = normalizedAttributes(
            storage.attributes(at: probe, effectiveRange: nil)
        )
    }

    private func typingAttributes() -> [NSAttributedString.Key: Any] {
        guard let attributes = textView?.typingAttributes, attributes[.font] != nil else {
            return baseTypingAttributes()
        }
        return attributes
    }

    private func baseTypingAttributes() -> [NSAttributedString.Key: Any] {
        NotesTextEditor.baseAttributes(fontSize: baseFontSize, family: fontFamily)
    }

    private func normalizedAttributes(
        _ attributes: [NSAttributedString.Key: Any]
    ) -> [NSAttributedString.Key: Any] {
        var normalized = attributes
        normalized[.font] = font(for: attributes)
        normalized[.foregroundColor] = NSColor.labelColor

        let style = NSMutableParagraphStyle()
        if let existing = attributes[.paragraphStyle] as? NSParagraphStyle {
            style.setParagraphStyle(existing)
        }
        style.lineSpacing = NotesTextEditor.lineSpacing
        normalized[.paragraphStyle] = style
        return normalized
    }

    private func font(for attributes: [NSAttributedString.Key: Any]) -> NSFont {
        let traits = (attributes[.font] as? NSFont).map { NSFontManager.shared.traits(of: $0) } ?? []
        return RichTextFont.make(
            size: normalizedSize(for: attributes),
            bold: traits.contains(.boldFontMask),
            italic: traits.contains(.italicFontMask),
            code: attributes[.blinkCode] != nil,
            family: fontFamily
        )
    }

    private func normalizedSize(for attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        let level = (attributes[.blinkHeading] as? Int).flatMap(HeadingLevel.init(rawValue:))
        return level?.size(base: baseFontSize) ?? baseFontSize
    }

    private func registerUndo(restoring snapshot: NSAttributedString, actionName: String) {
        guard let textView, let undoManager = textView.undoManager,
              let data = RichTextCoding.data(from: snapshot) else { return }
        let selection = textView.selectedRange()
        undoManager.registerUndo(withTarget: textView) { target in
            MainActor.assumeIsolated {
                Self.restore(data, selection: selection, in: target, actionName: actionName)
            }
        }
        undoManager.setActionName(actionName)
    }

    /// Restores a snapshot and registers the inverse so Redo works as well.
    private static func restore(
        _ data: Data,
        selection: NSRange,
        in textView: NSTextView,
        actionName: String
    ) {
        let currentSelection = textView.selectedRange()
        if let storage = textView.textStorage {
            let current = storage.attributedSubstring(
                from: NSRange(location: 0, length: storage.length)
            )
            if let currentData = RichTextCoding.data(from: current) {
                textView.undoManager?.registerUndo(withTarget: textView) { target in
                    MainActor.assumeIsolated {
                        Self.restore(
                            currentData,
                            selection: currentSelection,
                            in: target,
                            actionName: actionName
                        )
                    }
                }
                textView.undoManager?.setActionName(actionName)
            }
        }

        if let restored = RichTextCoding.attributedString(from: data) {
            textView.textStorage?.setAttributedString(restored)
        }
        textView.setSelectedRange(selection)
        textView.didChangeText()
    }

    /// Shows the in-note find bar.
    func showFindPanel() {
        performFind(.showFindPanel)
    }

    func findNext() {
        performFind(.next)
    }

    func findPrevious() {
        performFind(.previous)
    }

    private func performFind(_ action: NSFindPanelAction) {
        guard let textView else { return }
        let item = NSMenuItem()
        item.tag = Int(action.rawValue)
        textView.performFindPanelAction(item)
    }

    /// Drops the selection so the formatting bar can collapse.
    func dismiss() {
        guard let textView else { return }
        let selection = textView.selectedRange()
        textView.setSelectedRange(NSRange(location: selection.location + selection.length, length: 0))
        hasSelection = false
    }

}
