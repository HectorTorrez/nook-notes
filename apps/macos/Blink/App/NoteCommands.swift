import SwiftUI

struct NoteCommands: Commands {
    let store: NotesStore
    @FocusedValue(\.notesCommandHandler) private var handler
    @FocusedValue(\.richTextController) private var format

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            button(for: .newNote)
        }

        CommandMenu("Note") {
            Button("Show Actions") { handler?.showActions() }
                .keyboardShortcut("k")
                .disabled(handler == nil)
            button(for: .switchWorkspace)
            button(for: .browseNotes)
            Divider()
            button(for: .copyNote)
            button(for: .deleteNote)
            button(for: .restoreLastDeleted)
                .disabled(handler == nil || store.lastDeleted == nil)
        }

        CommandMenu("Format") {
            formatMenu
        }
    }

    @ViewBuilder
    private var formatMenu: some View {
        Button("Bold") { format?.toggleBold() }
            .keyboardShortcut("b")
            .disabled(format == nil)
        Button("Italic") { format?.toggleItalic() }
            .keyboardShortcut("i")
            .disabled(format == nil)
        Button("Underline") { format?.toggleUnderline() }
            .keyboardShortcut("u")
            .disabled(format == nil)
        Button("Strikethrough") { format?.toggleStrikethrough() }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(format == nil)
        Button("Code") { format?.toggleCode() }
            .disabled(format == nil)

        Divider()

        ForEach(HeadingLevel.allCases) { level in
            Button(level.title) { format?.setHeading(level) }
                .keyboardShortcut(level.shortcut)
                .disabled(format == nil)
        }

        Divider()

        ForEach(ListStyle.allCases) { style in
            Button(style.title) { format?.setList(style) }
                .keyboardShortcut(style.shortcut)
                .disabled(format == nil)
        }
    }

    private func button(for action: NoteAction) -> some View {
        Button(action.title) { handler?.perform(action) }
            .keyboardShortcut(action.keyboardShortcut)
            .disabled(handler == nil)
    }
}
