import SwiftUI

struct WorkspacesPanel: View {
    let store: NotesStore
    let onSwitch: () -> Void

    @State private var draft = ""
    @State private var renamingID: Workspace.ID?
    @State private var pendingDeleteID: Workspace.ID?
    @FocusState private var isNameFocused: Bool
    @Environment(\.themeAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var workspaceCountLabel: String {
        LocalizedCount.workspaces(store.workspaces.count)
    }

    private var isRenaming: Bool { renamingID != nil }

    var body: some View {
        VStack(spacing: 0) {
            SearchPanel(
                placeholder: "Search workspaces",
                emptyMessage: "No matching workspaces",
                items: store.workspacesByRecency,
                rowHeight: 50,
                listCaption: workspaceCountLabel,
                emptyIcon: "square.stack.3d.up",
                matches: { workspace, query in
                    workspace.name.localizedCaseInsensitiveContains(query)
                },
                showsTrailing: { workspace in
                    workspace.id == pendingDeleteID
                },
                onSelect: { workspace in
                    store.selectWorkspace(workspace.id)
                    onSwitch()
                },
                row: { workspace in
                    HStack(spacing: 10) {
                        IconTile(
                            systemName: "square.stack.3d.up.fill",
                            tint: .gray,
                            size: 26
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workspace.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(workspace.noteCountLabel)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        if workspace.id == store.selectedWorkspaceID {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Current workspace")
                        }
                    }
                    .padding(.trailing, 52)
                },
                trailing: { workspace in
                    if pendingDeleteID == workspace.id {
                        deleteTooltip(for: workspace)
                    } else {
                        HStack(spacing: 0) {
                            RowActionButton(
                                systemImage: "pencil",
                                help: "Rename",
                                tint: .secondary
                            ) {
                                renamingID = workspace.id
                                pendingDeleteID = nil
                                draft = workspace.name
                                isNameFocused = true
                            }
                            if store.canDeleteWorkspace {
                                RowActionButton(
                                    systemImage: "trash",
                                    help: "Delete",
                                    tint: .secondary,
                                    isDestructive: true
                                ) {
                                    renamingID = nil
                                    draft = ""
                                    pendingDeleteID = workspace.id
                                }
                            }
                        }
                    }
                }
            )

            Divider()

            nameField
        }
        .frame(width: 360)
    }

    private var nameField: some View {
        HStack(spacing: 8) {
            Image(systemName: isRenaming ? "pencil" : "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isNameFocused ? accent : .secondary)
            TextField(isRenaming ? "Rename workspace" : "New workspace", text: $draft)
                .textFieldStyle(.plain)
                .focused($isNameFocused)
                .onSubmit(commitName)
            if isRenaming {
                Button("Cancel", action: cancelRename)
                    .buttonStyle(PointerButtonStyle())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            } else if !draft.isEmpty {
                Button {
                    commitName()
                } label: {
                    Image(systemName: "arrow.turn.down.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .buttonStyle(PointerButtonStyle())
                .help("Create workspace")
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background {
            RoundedRectangle(cornerRadius: Theme.fieldCornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.055))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.fieldCornerRadius, style: .continuous)
                .strokeBorder(accent.opacity(isNameFocused ? 0.5 : 0), lineWidth: 1)
        }
        .padding(10)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isNameFocused)
    }

    private func deleteTooltip(for workspace: Workspace) -> some View {
        HStack(spacing: 8) {
            Text("Delete \(workspace.name) and \(workspace.noteCountLabel)?")
                .lineLimit(1)
            Button("Cancel") { pendingDeleteID = nil }
                .foregroundStyle(.white.opacity(0.72))
            Button("Delete") {
                store.deleteWorkspace(workspace.id)
                pendingDeleteID = nil
            }
            .foregroundStyle(Color(red: 1, green: 0.45, blue: 0.42))
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: 220)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.9))
        }
        .buttonStyle(PointerButtonStyle())
    }

    private func commitName() {
        if let renamingID {
            store.renameWorkspace(renamingID, to: draft)
            cancelRename()
        } else if store.createWorkspace(named: draft) {
            draft = ""
            onSwitch()
        }
    }

    private func cancelRename() {
        renamingID = nil
        draft = ""
        isNameFocused = false
    }
}
