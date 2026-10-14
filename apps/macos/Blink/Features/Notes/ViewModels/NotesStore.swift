import AppKit
import Observation
import os

/// Workspace and note management. Always holds at least one workspace, and each workspace
/// holds at least one note. When given a storage, changes are written to disk shortly after
/// they happen and on quit.
@MainActor
@Observable
final class NotesStore {
    private(set) var workspaces: [Workspace]
    private(set) var selectedWorkspaceID: Workspace.ID
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
        let createdAt = now()

        if let library = storage?.load() {
            let repaired = Self.repaired(library.workspaces, now: createdAt)
            if repaired.isEmpty {
                let workspace = Workspace.makeDefault(notes: notes, now: createdAt)
                self.workspaces = [workspace]
                self.selectedWorkspaceID = workspace.id
            } else {
                self.workspaces = repaired
                self.selectedWorkspaceID = repaired.contains(where: { $0.id == library.selectedWorkspaceID })
                    ? library.selectedWorkspaceID
                    : repaired[0].id
            }
        } else {
            let workspace = Workspace.makeDefault(notes: notes, now: createdAt)
            self.workspaces = [workspace]
            self.selectedWorkspaceID = workspace.id
        }

        markOpened(selectedID)

        if storage != nil {
            terminationObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.saveNow() }
            }
            scheduleSave()
        }
    }

    var activeWorkspace: Workspace { workspaces[activeIndex] }

    var notes: [Note] { activeWorkspace.notes }

    var selectedID: Note.ID { activeWorkspace.selectedNoteID }

    var selectedNote: Note {
        notes.first { $0.id == selectedID } ?? notes[0]
    }

    /// Pinned notes first, then newest created first so oldest sit last.
    var notesByRecency: [Note] {
        Self.sortedNotes(notes)
    }

    /// Newest workspaces first, oldest last.
    var workspacesByRecency: [Workspace] {
        workspaces.sorted { $0.createdAt > $1.createdAt }
    }

    var canDeleteWorkspace: Bool { workspaces.count > 1 }

    var lastDeleted: Note? {
        recentlyDeleted.last
    }

    func selectWorkspace(_ id: Workspace.ID) {
        guard id != selectedWorkspaceID, workspaces.contains(where: { $0.id == id }) else { return }
        selectedWorkspaceID = id
        recentlyDeleted = []
        markOpened(selectedID)
        scheduleSave()
    }

    @discardableResult
    func createWorkspace(named name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let note = Note(createdAt: now())
        let workspace = Workspace(
            name: trimmed,
            notes: [note],
            selectedNoteID: note.id,
            createdAt: now()
        )
        workspaces.append(workspace)
        selectedWorkspaceID = workspace.id
        recentlyDeleted = []
        scheduleSave()
        return true
    }

    func renameWorkspace(_ id: Workspace.ID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = workspaces.firstIndex(where: { $0.id == id }) else { return }
        workspaces[index].name = trimmed
        scheduleSave()
    }

    func deleteWorkspace(_ id: Workspace.ID) {
        guard canDeleteWorkspace, let index = workspaces.firstIndex(where: { $0.id == id }) else { return }
        let wasActive = selectedWorkspaceID == id
        workspaces.remove(at: index)
        if wasActive {
            selectedWorkspaceID = workspacesByRecency[0].id
            recentlyDeleted = []
            markOpened(selectedID)
        }
        scheduleSave()
    }

    func select(_ id: Note.ID) {
        guard notes.contains(where: { $0.id == id }) else { return }
        updateActive { $0.selectedNoteID = id }
        markOpened(id)
        scheduleSave()
    }

    func togglePin(_ id: Note.ID) {
        guard notes.contains(where: { $0.id == id }) else { return }
        updateActive { workspace in
            guard let index = workspace.notes.firstIndex(where: { $0.id == id }) else { return }
            workspace.notes[index].isPinned.toggle()
        }
        scheduleSave()
    }

    /// Reuses the selected note when it is still empty instead of piling up blank notes.
    func createNote() {
        guard !selectedNote.isEmpty else { return }
        let note = Note(createdAt: now())
        updateActive { workspace in
            workspace.notes.append(note)
            workspace.selectedNoteID = note.id
        }
        scheduleSave()
    }

    func updateSelectedContent(_ content: String, richTextData: Data?) {
        guard selectedNote.content != content || selectedNote.richTextData != richTextData else { return }
        updateActive { workspace in
            guard let index = workspace.notes.firstIndex(where: { $0.id == workspace.selectedNoteID }) else { return }
            workspace.notes[index].content = content
            workspace.notes[index].richTextData = richTextData
            workspace.notes[index].modifiedAt = now()
        }
        scheduleSave()
    }

    func deleteNote(_ id: Note.ID) {
        guard notes.contains(where: { $0.id == id }) else { return }
        let deletedSelection = selectedID == id
        updateActive { workspace in
            guard let index = workspace.notes.firstIndex(where: { $0.id == id }) else { return }
            let removed = workspace.notes.remove(at: index)
            if !removed.isEmpty {
                recentlyDeleted.append(removed)
            }
            if workspace.notes.isEmpty {
                workspace.notes.append(Note(createdAt: now()))
            }
            if workspace.selectedNoteID == id {
                workspace.selectedNoteID = Self.sortedNotes(workspace.notes)[0].id
            }
        }
        if deletedSelection {
            markOpened(selectedID)
        }
        scheduleSave()
    }

    func restoreLastDeleted() {
        guard let note = recentlyDeleted.popLast() else { return }
        updateActive { workspace in
            if workspace.notes.first(where: { $0.id == workspace.selectedNoteID })?.isEmpty == true {
                workspace.notes.removeAll { $0.id == workspace.selectedNoteID }
            }
            workspace.notes.append(note)
            workspace.selectedNoteID = note.id
        }
        markOpened(note.id)
        scheduleSave()
    }

    /// Writes any pending changes immediately.
    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        guard let storage else { return }
        do {
            try storage.save(LibrarySnapshot(workspaces: workspaces, selectedWorkspaceID: selectedWorkspaceID))
        } catch {
            Self.logger.error("Failed to save notes: \(error.localizedDescription, privacy: .public)")
        }
    }

    private var activeIndex: Int {
        workspaces.firstIndex { $0.id == selectedWorkspaceID } ?? 0
    }

    private func updateActive(_ update: (inout Workspace) -> Void) {
        update(&workspaces[activeIndex])
    }

    private func markOpened(_ id: Note.ID) {
        updateActive { workspace in
            guard let index = workspace.notes.firstIndex(where: { $0.id == id }) else { return }
            workspace.notes[index].lastOpenedAt = now()
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

    private static func sortedNotes(_ notes: [Note]) -> [Note] {
        notes.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
            return $0.createdAt > $1.createdAt
        }
    }

    private static func repaired(_ workspaces: [Workspace], now: Date) -> [Workspace] {
        workspaces.map { workspace in
            var workspace = workspace
            let trimmed = workspace.name.trimmingCharacters(in: .whitespacesAndNewlines)
            workspace.name = trimmed.isEmpty ? Workspace.defaultName : trimmed
            if workspace.notes.isEmpty {
                let note = Note(createdAt: now)
                workspace.notes = [note]
                workspace.selectedNoteID = note.id
            } else if !workspace.notes.contains(where: { $0.id == workspace.selectedNoteID }) {
                workspace.selectedNoteID = workspace.notes[0].id
            }
            return workspace
        }
    }
}
