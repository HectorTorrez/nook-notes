import SwiftUI

struct TrashPanel: View {
    let store: NotesStore
    let onClose: () -> Void

    @State private var confirmingEmpty = false
    @Environment(\.themeAccent) private var accent

    private var entries: [TrashedNote] {
        store.trash.sorted { $0.deletedAt > $1.deletedAt }
    }

    private var countLabel: String {
        store.trashCount == 1 ? "1 deleted note" : "\(store.trashCount) deleted notes"
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchPanel(
                placeholder: "Search trash",
                emptyMessage: "Trash is empty",
                items: entries,
                rowHeight: 54,
                listCaption: countLabel,
                emptyIcon: "trash",
                matches: { entry, query in
                    entry.note.content.localizedCaseInsensitiveContains(query)
                        || entry.workspaceName.localizedCaseInsensitiveContains(query)
                },
                onSelect: { entry in
                    store.restore(entry.id)
                    onClose()
                },
                row: { entry in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.note.title)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)

                        HStack(spacing: 5) {
                            Text(entry.workspaceName)
                                .foregroundStyle(accent)
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(relativeDate(entry.deletedAt))
                                .foregroundStyle(.secondary)
                        }
                        .font(.system(size: 11))
                        .lineLimit(1)
                    }
                    .padding(.trailing, 52)
                },
                trailing: { entry in
                    HStack(spacing: 0) {
                        RowActionButton(
                            systemImage: "arrow.uturn.backward",
                            help: "Restore",
                            tint: .secondary
                        ) {
                            store.restore(entry.id)
                            onClose()
                        }
                        RowActionButton(
                            systemImage: "trash.slash",
                            help: "Delete Permanently",
                            tint: .secondary,
                            isDestructive: true
                        ) {
                            store.deletePermanently(entry.id)
                        }
                    }
                }
            )

            if !store.trash.isEmpty {
                Divider()
                HStack {
                    Text("Deleted notes are kept across launches.")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button("Empty Trash…") {
                        confirmingEmpty = true
                    }
                    .buttonStyle(PointerButtonStyle())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.red)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .frame(width: 380)
        .alert("Empty Trash?", isPresented: $confirmingEmpty) {
            Button("Cancel", role: .cancel) {}
            Button("Empty Trash", role: .destructive) {
                store.emptyTrash()
            }
        } message: {
            Text(
                "This permanently deletes \(store.trashCount) note"
                    + "\(store.trashCount == 1 ? "" : "s")."
            )
        }
    }

    private func relativeDate(_ date: Date) -> String {
        Self.formatter.localizedString(for: date, relativeTo: Date())
    }

    private static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
}
