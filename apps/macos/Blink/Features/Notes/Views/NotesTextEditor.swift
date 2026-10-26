import AppKit
import SwiftUI

struct NotesTextEditor: NSViewRepresentable {
    var noteID: Note.ID
    var text: String
    var richTextData: Data?
    var fontSize: CGFloat
    var preferences: EditorPreferences
    var accessibilityLabel: String
    var caretColor: Color
    var controller: RichTextController
    var onTextChange: (Note.ID, String) -> Void
    var onRichTextChange: (Note.ID, String, Data?) -> Void
    /// Handles Escape while the editor is focused. Return `true` to consume the
    /// key, or `false` to let the text view's default behavior run.
    var onEscape: () -> Bool

    static let horizontalInset: CGFloat = 24
    static let topInset: CGFloat = 6
    static let lineSpacing: CGFloat = 6

    static func baseAttributes(
        fontSize: CGFloat,
        family: EditorFontFamily = .system
    ) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        return [
            .font: family.font(size: fontSize, bold: false),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: style,
        ]
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 52, right: 0)

        let textView = NotesTextView(frame: .zero)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        scrollView.documentView = textView

        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.drawsBackground = false
        textView.focusRingType = .none
        textView.textContainerInset = NSSize(width: Self.horizontalInset, height: Self.topInset)
        textView.textContainer?.lineFragmentPadding = 0
        textView.isAutomaticDataDetectionEnabled = false
        textView.insertionPointColor = NSColor(caretColor)
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .cursor: NSCursor.pointingHand,
        ]
        textView.setAccessibilityLabel(accessibilityLabel)

        textView.onCancel = { [weak coordinator = context.coordinator] in
            coordinator?.parent.onEscape() ?? false
        }

        textView.baseFontSize = fontSize
        textView.fontFamily = preferences.fontFamily
        textView.richTextController = controller
        context.coordinator.textView = textView
        applyPreferences(to: textView)
        context.coordinator.noteID = noteID
        context.coordinator.appliedFontSize = fontSize
        context.coordinator.appliedFontFamily = preferences.fontFamily
        controller.baseFontSize = fontSize
        controller.fontFamily = preferences.fontFamily
        controller.attach(textView)
        context.coordinator.loadContent(into: textView)
        controller.restyleFonts()
        controller.refresh()

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NotesTextView else { return }
        let coordinator = context.coordinator
        coordinator.parent = self

        textView.insertionPointColor = NSColor(caretColor)
        textView.setAccessibilityLabel(accessibilityLabel)
        textView.baseFontSize = fontSize
        textView.fontFamily = preferences.fontFamily
        textView.richTextController = controller
        applyPreferences(to: textView)
        controller.baseFontSize = fontSize
        controller.fontFamily = preferences.fontFamily

        if coordinator.noteID != noteID {
            coordinator.flushArchiveNow(deferringStoreUpdate: true)
            coordinator.noteID = noteID
            coordinator.appliedFontSize = fontSize
            coordinator.appliedFontFamily = preferences.fontFamily
            textView.pendingParagraphStyle = nil
            coordinator.loadContent(into: textView)
            controller.restyleFonts()
            textView.undoManager?.removeAllActions()
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            textView.scrollToBeginningOfDocument(nil)
            textView.window?.makeFirstResponder(textView)
            controller.selectionDidChange()
        } else if coordinator.appliedFontSize != fontSize
            || coordinator.appliedFontFamily != preferences.fontFamily {
            coordinator.appliedFontSize = fontSize
            coordinator.appliedFontFamily = preferences.fontFamily
            controller.restyleFonts()
        }
    }

    private func applyPreferences(to textView: NSTextView) {
        textView.isContinuousSpellCheckingEnabled = preferences.checksSpelling
        textView.isAutomaticSpellingCorrectionEnabled = preferences.correctsSpelling
        textView.isAutomaticQuoteSubstitutionEnabled = preferences.usesSmartQuotes
        textView.isAutomaticDashSubstitutionEnabled = preferences.usesSmartDashes
        textView.isAutomaticTextReplacementEnabled = preferences.usesTextReplacement
        textView.isAutomaticLinkDetectionEnabled = preferences.detectsLinks
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        coordinator.flushArchiveNow()
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NotesTextEditor
        var noteID: Note.ID?
        var appliedFontSize: CGFloat = 0
        var appliedFontFamily: EditorFontFamily = .system
        weak var textView: NSTextView?

        private var archiveTask: Task<Void, Never>?
        nonisolated(unsafe) private var terminationObserver: NSObjectProtocol?

        init(_ parent: NotesTextEditor) {
            self.parent = parent
            super.init()

            terminationObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.flushArchiveNow()
                }
            }
        }

        deinit {
            archiveTask?.cancel()
            if let terminationObserver {
                NotificationCenter.default.removeObserver(terminationObserver)
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.controller.refresh()
            if let noteID {
                parent.onTextChange(noteID, textView.string)
            }
            scheduleArchive(from: textView)
        }

        /// Rich text is archived after a short pause instead of on every
        /// keystroke. The plain text is still saved immediately.
        private func scheduleArchive(from textView: NSTextView) {
            archiveTask?.cancel()
            archiveTask = Task { [weak self, weak textView] in
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled, let self, let textView else { return }
                self.archiveNow(textView)
            }
        }

        private func archiveNow(_ textView: NSTextView) {
            archiveTask?.cancel()
            archiveTask = nil
            guard let noteID,
                  let data = RichTextCoding.data(from: textView.attributedString()) else {
                return
            }
            parent.onRichTextChange(noteID, textView.string, data)
        }

        func flushArchiveNow(deferringStoreUpdate: Bool = false) {
            guard let textView, let noteID,
                  let data = RichTextCoding.data(from: textView.attributedString()) else {
                return
            }

            archiveTask?.cancel()
            archiveTask = nil

            let content = textView.string
            if deferringStoreUpdate {
                DispatchQueue.main.async { [weak self] in
                    MainActor.assumeIsolated {
                        self?.parent.onRichTextChange(noteID, content, data)
                    }
                }
            } else {
                parent.onRichTextChange(noteID, content, data)
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard notification.object is NSTextView else { return }
            parent.controller.selectionDidChange()
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            let url: URL?
            switch link {
            case let value as URL:
                url = value
            case let value as String:
                url = URL(string: value)
            default:
                url = nil
            }
            guard let url else { return false }
            NSWorkspace.shared.open(url)
            return true
        }

        /// Replaces the text view's contents with the note's stored rich text, or plain
        /// text rendered with the current base typography when there is none.
        func loadContent(into textView: NSTextView) {
            if let data = parent.richTextData,
               let attributed = RichTextCoding.attributedString(from: data),
               attributed.length > 0 {
                textView.textStorage?.setAttributedString(attributed)
            } else {
                textView.string = parent.text
                applyBaseTypography(to: textView)
            }
            textView.typingAttributes = baseAttributes
        }

        private var baseAttributes: [NSAttributedString.Key: Any] {
            NotesTextEditor.baseAttributes(
                fontSize: parent.fontSize,
                family: parent.preferences.fontFamily
            )
        }

        private func applyBaseTypography(to textView: NSTextView) {
            textView.defaultParagraphStyle = baseAttributes[.paragraphStyle] as? NSParagraphStyle
            let range = NSRange(location: 0, length: (textView.string as NSString).length)
            if range.length > 0 {
                textView.textStorage?.setAttributes(baseAttributes, range: range)
            }
        }
    }
}

/// Editor text view that lets Escape dismiss the floating formatting bar by
/// clearing the current selection, and sanitizes external rich text before it
/// reaches the document.
final class NotesTextView: NSTextView {
    var onCancel: (() -> Bool)?
    weak var richTextController: RichTextController?
    var baseFontSize: CGFloat = 16
    var fontFamily: EditorFontFamily = .system
    /// Paragraph style chosen for an empty note, applied once text is typed.
    var pendingParagraphStyle: NSParagraphStyle?

    override func cancelOperation(_ sender: Any?) {
        if onCancel?() == true { return }
        super.cancelOperation(sender)
    }

    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        if insertString as? String == " ",
           replacementRange.length == 0,
           applyMarkdownPrefix() {
            return
        }
        super.insertText(insertString, replacementRange: replacementRange)
        applyPendingParagraphStyle()
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if event.keyCode == 48,
           (modifiers.isEmpty || modifiers == .shift),
           let controller = richTextController,
           controller.canAdjustIndent {
            controller.adjustIndent(by: modifiers == .shift ? -22 : 22)
            return
        }
        super.keyDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        if toggleChecklistIfNeeded(event) { return }
        super.mouseDown(with: event)
    }

    override func paste(_ sender: Any?) {
        if let richText = RichTextSanitizer.richText(
            from: .general,
            fontSize: baseFontSize,
            family: fontFamily
        ) {
            insertText(richText, replacementRange: selectedRange())
        } else {
            super.paste(sender)
        }
    }

    override func copy(_ sender: Any?) {
        let data = selectedRichTextData()
        super.copy(sender)
        if let data {
            NSPasteboard.general.setData(data, forType: .blinkRichText)
        }
    }

    override func cut(_ sender: Any?) {
        let data = selectedRichTextData()
        super.cut(sender)
        if let data {
            NSPasteboard.general.setData(data, forType: .blinkRichText)
        }
    }

    override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        let before = selectedRange()
        let previousLength = textStorage?.length ?? 0
        let didRead = super.readSelection(from: pboard, type: type)
        guard didRead, let storage = textStorage else { return didRead }

        let insertedLength = storage.length - previousLength + before.length
        guard insertedLength > 0, before.location + insertedLength <= storage.length else {
            return didRead
        }
        sanitize(NSRange(location: before.location, length: insertedLength))
        return didRead
    }

    /// Turns Markdown block prefixes (`# `, `- `, `1. `, `[] `) into rich text
    /// when the user types the trailing space.
    private func applyMarkdownPrefix() -> Bool {
        guard let controller = richTextController else { return false }
        let selection = selectedRange()
        guard selection.length == 0 else { return false }

        let nsString = string as NSString
        guard nsString.length > 0 else { return false }
        let paragraph = nsString.paragraphRange(
            for: NSRange(location: selection.location, length: 0)
        )
        let prefixLength = selection.location - paragraph.location
        guard prefixLength > 0, prefixLength <= 10 else { return false }

        let prefix = nsString.substring(
            with: NSRange(location: paragraph.location, length: prefixLength)
        )
        guard let transform = MarkdownPrefix(prefix) else { return false }

        var textEnd = NSMaxRange(paragraph)
        if textEnd > paragraph.location, nsString.character(at: textEnd - 1) == 10 {
            textEnd -= 1
        }
        guard selection.location == textEnd else { return false }

        guard let storage = textStorage, paragraph.location < storage.length else { return false }
        if let style = storage.attribute(
            .paragraphStyle,
            at: paragraph.location,
            effectiveRange: nil
        ) as? NSParagraphStyle, !style.textLists.isEmpty {
            return false
        }
        if storage.attribute(.blinkHeading, at: paragraph.location, effectiveRange: nil) != nil {
            return false
        }

        undoManager?.beginUndoGrouping()
        insertText("", replacementRange: NSRange(location: paragraph.location, length: prefixLength))
        setSelectedRange(NSRange(location: paragraph.location, length: 0))
        switch transform {
        case .heading(let level):
            controller.setHeading(level)
        case .list(let style):
            controller.setList(style)
        }
        undoManager?.endUndoGrouping()
        undoManager?.setActionName("Markdown Style")
        return true
    }

    /// Clicking the marker gutter of a task-list item checks or unchecks it.
    /// Applies a paragraph style chosen while the note was empty to the first
    /// text that is typed into it.
    private func applyPendingParagraphStyle() {
        guard let style = pendingParagraphStyle,
              let storage = textStorage,
              storage.length > 0 else { return }

        let selection = selectedRange()
        let probe = min(max(0, selection.location - 1), storage.length - 1)
        let paragraph = (storage.string as NSString).paragraphRange(
            for: NSRange(location: probe, length: 0)
        )
        storage.addAttribute(.paragraphStyle, value: style, range: paragraph)
        pendingParagraphStyle = nil
        didChangeText()
    }

    private func toggleChecklistIfNeeded(_ event: NSEvent) -> Bool {
        guard let controller = richTextController,
              let storage = textStorage,
              storage.length > 0 else { return false }

        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard modifiers.isEmpty else { return false }

        let point = convert(event.locationInWindow, from: nil)
        let index = characterIndexForInsertion(at: point)
        let nsString = storage.string as NSString
        let probe = min(max(0, index), nsString.length - 1)
        let paragraph = nsString.paragraphRange(for: NSRange(location: probe, length: 0))

        guard let style = storage.attribute(
            .paragraphStyle,
            at: paragraph.location,
            effectiveRange: nil
        ) as? NSParagraphStyle,
            let list = style.textLists.first,
            list.markerFormat == .box || list.markerFormat == .check else {
            return false
        }

        let x = point.x - textContainerOrigin.x
        guard x >= 0, x <= style.firstLineHeadIndent + 20 else { return false }

        setSelectedRange(NSRange(location: paragraph.location, length: 0))
        controller.selectionDidChange()
        controller.toggleChecklist()
        return true
    }

    private enum MarkdownPrefix {
        case heading(HeadingLevel)
        case list(ListStyle)

        init?(_ prefix: String) {
            switch prefix {
            case "#":
                self = .heading(.heading1)
            case "##":
                self = .heading(.heading2)
            case "###":
                self = .heading(.heading3)
            case "-", "*":
                self = .list(.bullet)
            case "[]", "[ ]":
                self = .list(.task)
            default:
                let number = prefix.dropLast()
                guard prefix.hasSuffix("."),
                      !number.isEmpty,
                      number.allSatisfy(\.isNumber) else {
                    return nil
                }
                self = .list(.ordered)
            }
        }
    }

    private func selectedRichTextData() -> Data? {
        guard let storage = textStorage else { return nil }
        let range = selectedRange()
        guard range.length > 0, NSMaxRange(range) <= storage.length else { return nil }
        return RichTextCoding.data(from: storage.attributedSubstring(from: range))
    }

    private func sanitize(_ range: NSRange) {
        guard let storage = textStorage, NSMaxRange(range) <= storage.length else { return }
        let original = storage.attributedSubstring(from: range)
        let sanitized = RichTextSanitizer.sanitize(
            original,
            fontSize: baseFontSize,
            family: fontFamily
        )
        guard original.string == sanitized.string, !original.isEqual(to: sanitized) else {
            return
        }
        storage.replaceCharacters(in: range, with: sanitized)
    }
}
