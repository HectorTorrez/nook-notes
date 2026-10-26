import Foundation

/// A note together with the workspace it belongs to, used by global search.
struct WorkspaceNote: Identifiable, Equatable, Sendable {
    let workspaceID: Workspace.ID
    let workspaceName: String
    let note: Note

    var id: Note.ID { note.id }
}
