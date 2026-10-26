import Foundation

struct Workspace: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    var name: String
    var notes: [Note]
    var selectedNoteID: Note.ID
    let createdAt: Date

    static let defaultName = "Personal"

    init(
        id: UUID = UUID(),
        name: String,
        notes: [Note],
        selectedNoteID: Note.ID,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.selectedNoteID = selectedNoteID
        self.createdAt = createdAt
    }

    var noteCountLabel: String {
        notes.count == 1 ? "1 note" : "\(notes.count) notes"
    }

    static func makeDefault(notes: [Note], now: Date) -> Workspace {
        let initial = notes.isEmpty ? [Note(createdAt: now)] : notes
        let selected = initial[0].id
        let created = initial.map(\.createdAt).min() ?? now
        return Workspace(
            name: defaultName,
            notes: initial,
            selectedNoteID: selected,
            createdAt: created
        )
    }
}

struct LibrarySnapshot: Codable, Equatable, Sendable {
    var workspaces: [Workspace]
    var selectedWorkspaceID: Workspace.ID
    var trash: [TrashedNote]

    init(
        workspaces: [Workspace],
        selectedWorkspaceID: Workspace.ID,
        trash: [TrashedNote] = []
    ) {
        self.workspaces = workspaces
        self.selectedWorkspaceID = selectedWorkspaceID
        self.trash = trash
    }

    /// Existing single-list saves become one workspace named Personal.
    init(migrating legacy: NotesSnapshot, now: Date = Date()) {
        let workspace = Workspace.makeDefault(notes: legacy.notes, now: now)
        var migrated = workspace
        if migrated.notes.contains(where: { $0.id == legacy.selectedID }) {
            migrated.selectedNoteID = legacy.selectedID
        }
        workspaces = [migrated]
        selectedWorkspaceID = migrated.id
        trash = []
    }

    private enum CodingKeys: String, CodingKey {
        case workspaces
        case selectedWorkspaceID
        case trash
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        workspaces = try container.decode([Workspace].self, forKey: .workspaces)
        selectedWorkspaceID = try container.decode(
            Workspace.ID.self,
            forKey: .selectedWorkspaceID
        )
        trash = try container.decodeIfPresent([TrashedNote].self, forKey: .trash) ?? []
    }
}
