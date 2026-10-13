import Foundation
import Observation

/// In-memory note management. Always holds at least one note, and one note is always selected.
@MainActor
@Observable
final class NotesStore {
    private(set) var notes: [Note]
    private(set) var selectedID: Note.ID
    private(set) var recentlyDeleted: [Note] = []

    @ObservationIgnored private let now: () -> Date

    init(notes: [Note] = [], now: @escaping () -> Date = Date.init) {
        self.now = now
        let initial = notes.isEmpty ? [Note(createdAt: now())] : notes
        self.notes = initial
        self.selectedID = initial[0].id
    }

    var selectedNote: Note {
        notes.first { $0.id == selectedID } ?? notes[0]
    }

    var notesByRecency: [Note] {
        notes.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    var lastDeleted: Note? {
        recentlyDeleted.last
    }

    func select(_ id: Note.ID) {
        guard notes.contains(where: { $0.id == id }) else { return }
        selectedID = id
    }

    /// Reuses the selected note when it is still empty instead of piling up blank notes.
    func createNote() {
        guard !selectedNote.isEmpty else { return }
        let note = Note(createdAt: now())
        notes.append(note)
        selectedID = note.id
    }

    func updateSelectedContent(_ content: String) {
        guard let index = notes.firstIndex(where: { $0.id == selectedID }),
              notes[index].content != content
        else { return }
        notes[index].content = content
        notes[index].modifiedAt = now()
    }

    func deleteNote(_ id: Note.ID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        let removed = notes.remove(at: index)
        if !removed.isEmpty {
            recentlyDeleted.append(removed)
        }
        if notes.isEmpty {
            notes.append(Note(createdAt: now()))
        }
        if selectedID == id {
            selectedID = notesByRecency[0].id
        }
    }

    func restoreLastDeleted() {
        guard let note = recentlyDeleted.popLast() else { return }
        if selectedNote.isEmpty {
            notes.removeAll { $0.id == selectedID }
        }
        notes.append(note)
        selectedID = note.id
    }
}
