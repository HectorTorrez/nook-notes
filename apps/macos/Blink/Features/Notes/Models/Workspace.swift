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

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case notes
        case selectedNoteID
        case createdAt
    }

    /// A note that failed to decode is dropped instead of making the entire
    /// library unreadable.
    private struct FailableNote: Decodable {
        let note: Note?

        init(from decoder: Decoder) throws {
            note = try? Note(from: decoder)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? Workspace.defaultName
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()

        let decodedNotes = (try container.decodeIfPresent(
            [FailableNote].self,
            forKey: .notes
        ) ?? []).compactMap(\.note)
        notes = decodedNotes

        if let selected = try container.decodeIfPresent(
            Note.ID.self,
            forKey: .selectedNoteID
        ), decodedNotes.contains(where: { $0.id == selected }) {
            selectedNoteID = selected
        } else {
            selectedNoteID = decodedNotes.first?.id ?? UUID()
        }
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
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var workspaces: [Workspace]
    var selectedWorkspaceID: Workspace.ID
    var trash: [TrashedNote]

    init(
        workspaces: [Workspace],
        selectedWorkspaceID: Workspace.ID,
        trash: [TrashedNote] = [],
        schemaVersion: Int = currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
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
        schemaVersion = Self.currentSchemaVersion
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case workspaces
        case selectedWorkspaceID
        case trash
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        workspaces = try container.decodeIfPresent([Workspace].self, forKey: .workspaces) ?? []
        selectedWorkspaceID = try container.decodeIfPresent(
            Workspace.ID.self,
            forKey: .selectedWorkspaceID
        ) ?? UUID()
        trash = try container.decodeIfPresent([TrashedNote].self, forKey: .trash) ?? []
    }
}
