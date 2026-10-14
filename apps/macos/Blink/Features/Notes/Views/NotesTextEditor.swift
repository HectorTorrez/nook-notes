import AppKit
import SwiftUI

struct NotesTextEditor: NSViewRepresentable {
    var noteID: Note.ID
    var text: String
    var richTextData: Data?
    var fontSize: CGFloat
    var caretColor: Color
    var controller: RichTextController
    var onChange: (String, Data?) -> Void

    static let horizontalInset: CGFloat = 24
    static let topInset: CGFloat = 6
    static let lineSpacing: CGFloat = 6

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 52, right: 0)

        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.focusRingType = .none
        textView.textContainerInset = NSSize(width: Self.horizontalInset, height: Self.topInset)
        textView.textContainer?.lineFragmentPadding = 0
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.insertionPointColor = NSColor(caretColor)
        textView.setAccessibilityLabel("Note")

        context.coordinator.noteID = noteID
        context.coordinator.appliedFontSize = fontSize
        controller.baseFontSize = fontSize
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
        controller.baseFontSize = fontSize

        if coordinator.noteID != noteID {
            coordinator.noteID = noteID
            coordinator.appliedFontSize = fontSize
            coordinator.loadContent(into: textView)
            controller.restyleFonts()
            textView.undoManager?.removeAllActions()
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            textView.scrollToBeginningOfDocument(nil)
            textView.window?.makeFirstResponder(textView)
            controller.refresh()
        } else if coordinator.appliedFontSize != fontSize {
            coordinator.appliedFontSize = fontSize
            controller.restyleFonts()
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NotesTextEditor
        var noteID: Note.ID?
        var appliedFontSize: CGFloat = 0

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
            parent.controller.refresh()
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
            let style = NSMutableParagraphStyle()
            style.lineSpacing = NotesTextEditor.lineSpacing
            return [
                .font: NSFont.systemFont(ofSize: parent.fontSize),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: style,
            ]
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
