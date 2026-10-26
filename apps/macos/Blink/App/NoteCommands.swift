import SwiftUI

struct NoteCommands: Commands {
    let store: NotesStore
    @FocusedValue(\.notesCommandHandler) private var handler
    @FocusedValue(\.richTextController) private var format
    @AppStorage("fontSize") private var fontSize: Double = 16

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            button(for: .newNote)
        }

        CommandGroup(after: .importExport) {
            Button("Export Note…") {
                NoteFileActions.exportSelected(from: store)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(store.selectedNote.isEmpty)

            Button("Export All Notes…") {
                NoteFileActions.exportAll(from: store)
            }

            Button("Import Notes…") {
                NoteFileActions.importNotes(into: store)
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
        }

        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Find…") { format?.showFindPanel() }
                .keyboardShortcut("f")
                .disabled(format == nil)
            Button("Find Next") { format?.findNext() }
                .keyboardShortcut("g")
                .disabled(format == nil)
            Button("Find Previous") { format?.findPrevious() }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(format == nil)
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

        Button("Toggle Checklist") { format?.toggleChecklist() }
            .keyboardShortcut("k", modifiers: [.command, .control])
            .disabled(format?.isChecklist != true)

        Button("Clear Formatting") { format?.clearFormatting() }
            .keyboardShortcut("c", modifiers: [.command, .option])
            .disabled(format == nil)

        Divider()

        Button("Increase Indent") { format?.adjustIndent(by: 22) }
            .keyboardShortcut("]", modifiers: [.command])
            .disabled(format?.canAdjustIndent != true)
        Button("Decrease Indent") { format?.adjustIndent(by: -22) }
            .keyboardShortcut("[", modifiers: [.command])
            .disabled(format?.canAdjustIndent != true)

        Divider()

        Button("Increase Text Size") {
            fontSize = min(28, fontSize + 1)
        }
        .keyboardShortcut("=")
        Button("Decrease Text Size") {
            fontSize = max(12, fontSize - 1)
        }
        .keyboardShortcut("-")
        Button("Actual Size") {
            fontSize = 16
        }
        .keyboardShortcut("0")
    }

    private func button(for action: NoteAction) -> some View {
        Button(action.title) { handler?.perform(action) }
            .keyboardShortcut(action.keyboardShortcut)
            .disabled(handler == nil)
    }
}
