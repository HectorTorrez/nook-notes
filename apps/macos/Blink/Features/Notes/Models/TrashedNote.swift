import Foundation

/// A deleted note waiting in the trash. The workspace metadata lets a restore
/// return the note to where it came from, even after another workspace switch.
struct TrashedNote: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let note: Note
    let workspaceID: Workspace.ID
    let workspaceName: String
    let deletedAt: Date

    init(
        id: UUID = UUID(),
        note: Note,
        workspaceID: Workspace.ID,
        workspaceName: String,
        deletedAt: Date
    ) {
        self.id = id
        self.note = note
        self.workspaceID = workspaceID
        self.workspaceName = workspaceName
        self.deletedAt = deletedAt
    }
}
