import AppKit
import SwiftUI

struct NotesTextEditor: NSViewRepresentable {
    var noteID: Note.ID
    @Binding var text: String
    var fontSize: CGFloat
    var caretColor: Color

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
        textView.string = text
        textView.isRichText = false
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
        context.coordinator.applyTypography(to: textView)

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

        if coordinator.noteID != noteID {
            coordinator.noteID = noteID
            textView.string = text
            coordinator.applyTypography(to: textView)
            textView.undoManager?.removeAllActions()
            textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
            textView.scrollToBeginningOfDocument(nil)
            textView.window?.makeFirstResponder(textView)
        } else if textView.string != text {
            let selection = textView.selectedRanges
            textView.string = text
            coordinator.applyTypography(to: textView)
            textView.selectedRanges = selection
        } else if coordinator.appliedFontSize != fontSize {
            coordinator.applyTypography(to: textView)
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
            if parent.text != textView.string {
                parent.text = textView.string
            }
        }

        func applyTypography(to textView: NSTextView) {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = NotesTextEditor.lineSpacing
            let font = NSFont.systemFont(ofSize: parent.fontSize)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: style,
            ]
            textView.defaultParagraphStyle = style
            textView.typingAttributes = attributes
            let range = NSRange(location: 0, length: (textView.string as NSString).length)
            if range.length > 0 {
                textView.textStorage?.setAttributes(attributes, range: range)
            }
            appliedFontSize = parent.fontSize
        }
    }
}
