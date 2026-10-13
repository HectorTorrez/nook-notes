import SwiftUI

struct NotesBrowser: View {
    let store: NotesStore
    let onSelect: (Note.ID) -> Void

    var body: some View {
        SearchPanel(
            placeholder: "Search notes",
            emptyMessage: "No matching notes",
            items: store.notesByRecency,
            rowHeight: 46,
            matches: { note, query in
                note.content.localizedCaseInsensitiveContains(query)
            },
            onSelect: { onSelect($0.id) }
        ) { note in
            HStack(spacing: 10) {
                IconTile(
                    systemName: "note.text",
                    tint: note.id == store.selectedID ? .orange : .gray,
                    size: 26
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(note.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                    Text(note.modifiedAt, format: .relative(presentation: .named))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if note.id == store.selectedID {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Current note")
                }
            }
            .contextMenu {
                Button("Delete Note", role: .destructive) {
                    store.deleteNote(note.id)
                }
            }
        }
        .frame(width: 320)
    }
}
