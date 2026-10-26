import AppKit
import SwiftUI

enum NoteAction: String, CaseIterable, Identifiable {
    case newNote
    case switchWorkspace
    case browseNotes
    case copyNote
    case copyAsMarkdown
    case deleteNote
    case restoreLastDeleted
    case trash

    var id: Self { self }

    var title: String {
        switch self {
        case .newNote: "New Note"
        case .switchWorkspace: "Workspaces"
        case .browseNotes: "Browse Notes"
        case .copyNote: "Copy Note"
        case .copyAsMarkdown: "Copy as Markdown"
        case .deleteNote: "Delete Note"
        case .restoreLastDeleted: "Restore Last Deleted"
        case .trash: "Trash"
        }
    }

    var systemImage: String {
        switch self {
        case .newNote: "square.and.pencil"
        case .switchWorkspace: "square.stack.3d.up.fill"
        case .browseNotes: "square.stack.fill"
        case .copyNote: "doc.on.doc.fill"
        case .copyAsMarkdown: "doc.plaintext"
        case .deleteNote: "trash.fill"
        case .restoreLastDeleted: "arrow.uturn.backward"
        case .trash: "trash"
        }
    }

    var tint: Color {
        switch self {
        case .newNote: .orange
        case .switchWorkspace: .purple
        case .browseNotes: .blue
        case .copyNote: .teal
        case .copyAsMarkdown: .mint
        case .deleteNote: .red
        case .restoreLastDeleted: .indigo
        case .trash: .gray
        }
    }

    var keyboardShortcut: KeyboardShortcut? {
        switch self {
        case .newNote: KeyboardShortcut("n")
        case .switchWorkspace: KeyboardShortcut("o", modifiers: [.command, .shift])
        case .browseNotes: KeyboardShortcut("p")
        case .copyNote: KeyboardShortcut("c", modifiers: [.command, .shift])
        case .copyAsMarkdown: KeyboardShortcut("m", modifiers: [.command, .shift])
        case .deleteNote: KeyboardShortcut(.delete, modifiers: [.command, .shift])
        case .restoreLastDeleted: nil
        case .trash: KeyboardShortcut("t", modifiers: [.command, .option])
        }
    }

    var shortcutKeys: [String] {
        switch self {
        case .newNote: ["⌘", "N"]
        case .switchWorkspace: ["⇧", "⌘", "O"]
        case .browseNotes: ["⌘", "P"]
        case .copyNote: ["⇧", "⌘", "C"]
        case .copyAsMarkdown: ["⇧", "⌘", "M"]
        case .deleteNote: ["⇧", "⌘", "⌫"]
        case .restoreLastDeleted: []
        case .trash: ["⌥", "⌘", "T"]
        }
    }
}

enum NotesPanel {
    case actions
    case notes
    case workspaces
    case trash
}

/// Routes menu-bar commands to the key notes window.
struct NotesCommandHandler {
    var perform: (NoteAction) -> Void
    var showActions: () -> Void
}

extension FocusedValues {
    @Entry var notesCommandHandler: NotesCommandHandler?
    @Entry var richTextController: RichTextController?
}

extension Note {
    func copyToPasteboard(_ pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)

        guard let richTextData,
              let attributed = RichTextCoding.attributedString(from: richTextData),
              attributed.length > 0 else {
            return
        }

        let range = NSRange(location: 0, length: attributed.length)
        if let rtf = try? attributed.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) {
            pasteboard.setData(rtf, forType: .rtf)
        }
        if let html = try? attributed.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
        ) {
            pasteboard.setData(html, forType: .html)
        }
        pasteboard.setData(richTextData, forType: .blinkRichText)
    }

    func copyMarkdownToPasteboard(_ pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.setString(markdown, forType: .string)
    }
}
