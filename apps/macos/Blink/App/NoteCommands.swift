import SwiftUI

struct NoteCommands: Commands {
    let store: NotesStore
    @FocusedValue(\.notesCommandHandler) private var handler

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            button(for: .newNote)
        }

        CommandMenu("Note") {
            Button("Show Actions") { handler?.showActions() }
                .keyboardShortcut("k")
                .disabled(handler == nil)
            button(for: .browseNotes)
            Divider()
            button(for: .copyNote)
            button(for: .deleteNote)
            button(for: .restoreLastDeleted)
                .disabled(handler == nil || store.lastDeleted == nil)
        }
    }

    private func button(for action: NoteAction) -> some View {
        Button(action.title) { handler?.perform(action) }
            .keyboardShortcut(action.keyboardShortcut)
            .disabled(handler == nil)
    }
}
