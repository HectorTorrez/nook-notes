import AppKit
import SwiftUI

enum NoteAction: String, CaseIterable, Identifiable {
    case newNote
    case browseNotes
    case copyNote
    case deleteNote
    case restoreLastDeleted

    var id: Self { self }

    var title: String {
        switch self {
        case .newNote: "New Note"
        case .browseNotes: "Browse Notes"
        case .copyNote: "Copy Note"
        case .deleteNote: "Delete Note"
        case .restoreLastDeleted: "Restore Last Deleted"
        }
    }

    var systemImage: String {
        switch self {
        case .newNote: "square.and.pencil"
        case .browseNotes: "square.stack.fill"
        case .copyNote: "doc.on.doc.fill"
        case .deleteNote: "trash.fill"
        case .restoreLastDeleted: "arrow.uturn.backward"
        }
    }

    var tint: Color {
        switch self {
        case .newNote: .orange
        case .browseNotes: .blue
        case .copyNote: .teal
        case .deleteNote: .red
        case .restoreLastDeleted: .indigo
        }
    }

    var keyboardShortcut: KeyboardShortcut? {
        switch self {
        case .newNote: KeyboardShortcut("n")
        case .browseNotes: KeyboardShortcut("p")
        case .copyNote: KeyboardShortcut("c", modifiers: [.command, .shift])
        case .deleteNote: KeyboardShortcut(.delete, modifiers: [.command, .shift])
        case .restoreLastDeleted: nil
        }
    }

    var shortcutKeys: [String] {
        switch self {
        case .newNote: ["⌘", "N"]
        case .browseNotes: ["⌘", "P"]
        case .copyNote: ["⇧", "⌘", "C"]
        case .deleteNote: ["⇧", "⌘", "⌫"]
        case .restoreLastDeleted: []
        }
    }
}

enum NotesPanel {
    case actions
    case notes
    case appearance
}

/// Routes menu-bar commands to the key notes window.
struct NotesCommandHandler {
    var perform: (NoteAction) -> Void
    var showActions: () -> Void
}

extension FocusedValues {
    @Entry var notesCommandHandler: NotesCommandHandler?
}

extension Note {
    func copyToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
    }
}
