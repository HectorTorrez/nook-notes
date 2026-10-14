import SwiftUI

struct ActionPanel: View {
    let store: NotesStore
    let perform: (NoteAction) -> Void

    var body: some View {
        SearchPanel(
            placeholder: "Search actions",
            emptyMessage: "No matching actions",
            items: NoteAction.allCases,
            rowHeight: 38,
            emptyIcon: "command",
            matches: { action, query in
                action.title.localizedCaseInsensitiveContains(query)
            },
            isEnabled: isEnabled,
            onSelect: perform
        ) { action in
            HStack(spacing: 10) {
                IconTile(systemName: action.systemImage, tint: action.tint)
                Text(action.title)
                    .font(.system(size: 13, weight: .medium))
                if let detail = detail(for: action) {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 8)
                if !action.shortcutKeys.isEmpty {
                    KeyCaps(keys: action.shortcutKeys)
                }
            }
        }
        .frame(width: 340)
    }

    private func isEnabled(_ action: NoteAction) -> Bool {
        switch action {
        case .restoreLastDeleted: store.lastDeleted != nil
        case .copyNote: !store.selectedNote.isEmpty
        case .newNote, .switchWorkspace, .browseNotes, .deleteNote: true
        }
    }

    private func detail(for action: NoteAction) -> String? {
        switch action {
        case .restoreLastDeleted: store.lastDeleted?.title
        case .switchWorkspace: store.activeWorkspace.name
        case .browseNotes: store.notes.count == 1 ? "1 note" : "\(store.notes.count) notes"
        default: nil
        }
    }
}
