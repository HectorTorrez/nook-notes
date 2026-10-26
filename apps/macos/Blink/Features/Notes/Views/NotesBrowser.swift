import SwiftUI

struct NotesBrowser: View {
    let store: NotesStore
    /// Captured when the list opens, so the labels stay put until the next open.
    let listedAt: Date
    let onSelect: (Note.ID) -> Void

    @State private var scope: Scope = .workspace
    @Environment(\.themeAccent) private var accent

    private enum Scope: String, CaseIterable, Identifiable, Hashable {
        case workspace
        case all

        var id: String { rawValue }

        var title: String {
            switch self {
            case .workspace: "Workspace"
            case .all: "All Notes"
            }
        }
    }

    private struct NoteResult: Identifiable {
        let workspaceID: Workspace.ID
        let workspaceName: String
        let note: Note

        var id: Note.ID { note.id }
    }

    private var results: [NoteResult] {
        switch scope {
        case .workspace:
            let workspace = store.activeWorkspace
            return store.notesByRecency.map {
                NoteResult(
                    workspaceID: workspace.id,
                    workspaceName: workspace.name,
                    note: $0
                )
            }
        case .all:
            return store.allNotesByRecency.map {
                NoteResult(
                    workspaceID: $0.workspaceID,
                    workspaceName: $0.workspaceName,
                    note: $0.note
                )
            }
        }
    }

    private var caption: String {
        switch scope {
        case .workspace:
            return LocalizedCount.notes(store.notes.count)
        case .all:
            return "\(LocalizedCount.notes(results.count)) · "
                + LocalizedCount.workspaces(store.workspaces.count)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Search Scope", selection: $scope) {
                ForEach(Scope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .accessibilityLabel("Search scope")

            SearchPanel(
                placeholder: scope == .workspace ? "Search notes" : "Search all notes",
                emptyMessage: "No matching notes",
                items: results,
                rowHeight: 54,
                listCaption: caption,
                emptyIcon: "note.text",
                matches: { result, query in
                    result.note.content.localizedCaseInsensitiveContains(query)
                },
                onSelect: { result in
                    if result.workspaceID != store.selectedWorkspaceID {
                        store.selectWorkspace(result.workspaceID)
                    }
                    onSelect(result.note.id)
                },
                row: { result in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            if result.note.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.orange)
                                    .accessibilityHidden(true)
                            }
                            Text(result.note.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(result.note.isEmpty ? .secondary : .primary)
                                .lineLimit(1)
                        }
                        HStack(spacing: 5) {
                            if scope == .all {
                                Text(result.workspaceName)
                                    .foregroundStyle(accent)
                                Text("·")
                                    .foregroundStyle(.tertiary)
                            }

                            if result.workspaceID == store.selectedWorkspaceID,
                               result.note.id == store.selectedID {
                                Text("Current")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(accent)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background {
                                        Capsule(style: .continuous)
                                            .fill(accent.opacity(0.16))
                                    }
                            } else {
                                Text(OpenedWhen.label(for: result.note.modifiedAt, now: listedAt))
                                    .foregroundStyle(.secondary)
                            }
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(characterLabel(for: result.note))
                                .foregroundStyle(.secondary)
                        }
                        .font(.system(size: 11))
                        .lineLimit(1)
                    }
                    .padding(.trailing, 52)
                    .contextMenu {
                        Button(result.note.isPinned ? "Unpin" : "Pin") {
                            store.togglePin(result.note.id)
                        }
                        Button("Duplicate") {
                            store.duplicateNote(result.note.id)
                        }
                        if store.workspaces.count > 1 {
                            Menu("Move to Workspace") {
                                ForEach(
                                    store.workspaces.filter {
                                        $0.id != result.workspaceID
                                    }
                                ) { workspace in
                                    Button(workspace.name) {
                                        store.moveNote(result.note.id, to: workspace.id)
                                    }
                                }
                            }
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            store.deleteNote(result.note.id)
                        }
                    }
                },
                trailing: { result in
                    HStack(spacing: 0) {
                        RowActionButton(
                            systemImage: result.note.isPinned ? "pin.fill" : "pin",
                            help: result.note.isPinned ? "Unpin" : "Pin",
                            tint: result.note.isPinned ? .orange : .secondary
                        ) {
                            store.togglePin(result.note.id)
                        }
                        RowActionButton(
                            systemImage: "trash",
                            help: "Delete",
                            tint: .secondary,
                            isDestructive: true
                        ) {
                            store.deleteNote(result.note.id)
                        }
                    }
                }
            )
        }
        .frame(width: 380)
    }

    private func characterLabel(for note: Note) -> String {
        LocalizedCount.characters(note.characterCount)
    }
}

/// Coarse, localized labels such as “today”, “yesterday”, and “2 days ago”.
@MainActor
private enum OpenedWhen {
    static func label(for date: Date, now: Date) -> String {
        formatter.localizedString(for: date, relativeTo: now)
    }

    private static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
}

struct RowActionButton: View {
    let systemImage: String
    let help: String
    let tint: Color
    var isDestructive: Bool = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isHovering && isDestructive ? Color.red : tint)
                .frame(width: 24, height: 24)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(isHovering ? 0.08 : 0))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(PointerButtonStyle())
        .help(help)
        .accessibilityLabel(help)
        .onHover { isHovering = $0 }
    }
}
