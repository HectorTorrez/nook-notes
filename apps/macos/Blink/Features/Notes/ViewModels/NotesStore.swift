import AppKit
import Observation
import os

/// Note management. Always holds at least one note, and one note is always selected.
/// When given a storage, changes are written to disk shortly after they happen and on quit.
@MainActor
@Observable
final class NotesStore {
    private(set) var notes: [Note]
    private(set) var selectedID: Note.ID
    private(set) var recentlyDeleted: [Note] = []

    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let storage: NotesFileStorage?
    @ObservationIgnored private var pendingSave: Task<Void, Never>?
    @ObservationIgnored private var terminationObserver: NSObjectProtocol?

    private static let saveDelay: Duration = .milliseconds(500)
    private static let logger = Logger(subsystem: "com.hectortorrez.blink", category: "NotesStore")

    init(notes: [Note] = [], storage: NotesFileStorage? = nil, now: @escaping () -> Date = Date.init) {
        self.now = now
        self.storage = storage
        let snapshot = storage?.load()
        let loaded = snapshot?.notes ?? notes
        let initial = loaded.isEmpty ? [Note(createdAt: now())] : loaded
        self.notes = initial
        if let saved = snapshot?.selectedID, initial.contains(where: { $0.id == saved }) {
            self.selectedID = saved
        } else {
            self.selectedID = initial[0].id
        }

        if storage != nil {
            terminationObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.saveNow() }
            }
        }
    }

    /// Writes any pending changes immediately.
    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        guard let storage else { return }
        do {
            try storage.save(NotesSnapshot(notes: notes, selectedID: selectedID))
        } catch {
            Self.logger.error("Failed to save notes: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func scheduleSave() {
        guard storage != nil else { return }
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
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
        scheduleSave()
    }

    /// Reuses the selected note when it is still empty instead of piling up blank notes.
    func createNote() {
        guard !selectedNote.isEmpty else { return }
        let note = Note(createdAt: now())
        notes.append(note)
        selectedID = note.id
        scheduleSave()
    }

    func updateSelectedContent(_ content: String) {
        guard let index = notes.firstIndex(where: { $0.id == selectedID }),
              notes[index].content != content
        else { return }
        notes[index].content = content
        notes[index].modifiedAt = now()
        scheduleSave()
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
        scheduleSave()
    }

    func restoreLastDeleted() {
        guard let note = recentlyDeleted.popLast() else { return }
        if selectedNote.isEmpty {
            notes.removeAll { $0.id == selectedID }
        }
        notes.append(note)
        selectedID = note.id
        scheduleSave()
    }
}
