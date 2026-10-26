import AppKit
import SwiftUI

struct NotesTextEditor: NSViewRepresentable {
    var noteID: Note.ID
    var text: String
    var richTextData: Data?
    var fontSize: CGFloat
    var preferences: EditorPreferences
    var caretColor: Color
    var controller: RichTextController
    var onChange: (String, Data?) -> Void
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
        textView.setAccessibilityLabel("Note")

        textView.onCancel = { [weak coordinator = context.coordinator] in
            coordinator?.parent.onEscape() ?? false
        }

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
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let coordinator = context.coordinator
        coordinator.parent = self

        textView.insertionPointColor = NSColor(caretColor)
        applyPreferences(to: textView)
        controller.baseFontSize = fontSize
        controller.fontFamily = preferences.fontFamily

        if coordinator.noteID != noteID {
            coordinator.noteID = noteID
            coordinator.appliedFontSize = fontSize
            coordinator.appliedFontFamily = preferences.fontFamily
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

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NotesTextEditor
        var noteID: Note.ID?
        var appliedFontSize: CGFloat = 0
        var appliedFontFamily: EditorFontFamily = .system

        init(_ parent: NotesTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.controller.refresh()
            parent.onChange(textView.string, RichTextCoding.data(from: textView.attributedString()))
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
/// clearing the current selection.
final class NotesTextView: NSTextView {
    var onCancel: (() -> Bool)?

    override func cancelOperation(_ sender: Any?) {
        if onCancel?() == true { return }
        super.cancelOperation(sender)
    }
}
