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
    private(set) var trash: [TrashedNote] = []
    private(set) var loadFailure: NotesFileStorage.LoadFailure? = nil
    private(set) var saveError: String? = nil

    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let storage: NotesFileStorage?
    @ObservationIgnored private var pendingSave: Task<Void, Never>?
    @ObservationIgnored nonisolated(unsafe) private var terminationObserver: NSObjectProtocol?
    @ObservationIgnored nonisolated(unsafe) private var resignObserver: NSObjectProtocol?
    @ObservationIgnored private var isTerminating = false

    private static let saveDelay: Duration = .milliseconds(500)
    private static let logger = Logger(subsystem: "com.hectortorrez.blink", category: "NotesStore")

    init(notes: [Note] = [], storage: NotesFileStorage? = nil, now: @escaping () -> Date = Date.init) {
        self.now = now
        self.storage = storage
        let createdAt = now()
        let result = storage?.load() ?? .missing

        switch result {
        case .loaded(let library):
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
            self.trash = library.trash
        case .missing:
            let workspace = Workspace.makeDefault(notes: notes, now: createdAt)
            self.workspaces = [workspace]
            self.selectedWorkspaceID = workspace.id
            self.trash = []
        case .failure(let failure):
            let workspace = Workspace.makeDefault(notes: notes, now: createdAt)
            self.workspaces = [workspace]
            self.selectedWorkspaceID = workspace.id
            self.trash = []
            self.loadFailure = failure
        }

        markOpened(selectedID)

        if storage != nil {
            terminationObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.isTerminating = true
                    self.saveNow()
                }
            }
            resignObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.saveNow()
                }
            }
            scheduleSave()
        }
    }

    deinit {
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
        }
    }

    var activeWorkspace: Workspace { workspaces[activeIndex] }

    var notes: [Note] { activeWorkspace.notes }

    var selectedID: Note.ID { activeWorkspace.selectedNoteID }

    var selectedNote: Note {
        notes.first { $0.id == selectedID } ?? notes[0]
    }

    /// Pinned notes first, then most recently edited first.
    var notesByRecency: [Note] {
        Self.sortedNotes(notes)
    }

    /// Newest workspaces first, oldest last.
    var workspacesByRecency: [Workspace] {
        workspaces.sorted { $0.createdAt > $1.createdAt }
    }

    var canDeleteWorkspace: Bool { workspaces.count > 1 }

    var lastDeleted: Note? {
        trash.last?.note
    }

    var trashCount: Int { trash.count }

    var hasStorageIssue: Bool { loadFailure != nil || saveError != nil }

    var savesBlocked: Bool { loadFailure?.blocksSaving ?? false }

    var storageIssueMessage: String {
        if let loadFailure {
            return loadFailure.message
        }
        if let saveError {
            return "Blink couldn’t save your notes: \(saveError)"
        }
        return ""
    }

    var storageIssueURL: URL? {
        loadFailure?.backupURL ?? loadFailure?.url ?? storage?.url
    }

    var notesURL: URL? { storage?.url }

    func dismissStorageIssue() {
        if saveError != nil {
            saveError = nil
        }
        if let loadFailure, !loadFailure.blocksSaving {
            self.loadFailure = nil
        }
    }

    func retrySave() {
        saveError = nil
        saveNow()
    }

    func selectWorkspace(_ id: Workspace.ID) {
        guard id != selectedWorkspaceID, workspaces.contains(where: { $0.id == id }) else { return }
        selectedWorkspaceID = id
        markOpened(selectedID)
        scheduleSave()
    }

    @discardableResult
    func createWorkspace(named name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let note = Note(createdAt: now())
        let workspace = Workspace(
            name: uniqueWorkspaceName(trimmed),
            notes: [note],
            selectedNoteID: note.id,
            createdAt: now()
        )
        workspaces.append(workspace)
        selectedWorkspaceID = workspace.id
        scheduleSave()
        return true
    }

    func renameWorkspace(_ id: Workspace.ID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = workspaces.firstIndex(where: { $0.id == id }) else {
            return
        }
        workspaces[index].name = uniqueWorkspaceName(trimmed, excluding: id)
        scheduleSave()
    }

    private func uniqueWorkspaceName(_ name: String, excluding id: Workspace.ID? = nil) -> String {
        var candidate = name
        var suffix = 2
        while workspaces.contains(where: {
            $0.id != id && $0.name.caseInsensitiveCompare(candidate) == .orderedSame
        }) {
            candidate = "\(name) \(suffix)"
            suffix += 1
        }
        return candidate
    }

    func deleteWorkspace(_ id: Workspace.ID) {
        guard canDeleteWorkspace, let index = workspaces.firstIndex(where: { $0.id == id }) else {
            return
        }
        let removedWorkspace = workspaces[index]
        let wasActive = selectedWorkspaceID == id

        for note in removedWorkspace.notes where !note.isEmpty {
            trash.append(TrashedNote(
                note: note,
                workspaceID: removedWorkspace.id,
                workspaceName: removedWorkspace.name,
                deletedAt: now()
            ))
        }

        workspaces.remove(at: index)
        if wasActive {
            selectedWorkspaceID = workspacesByRecency[0].id
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

    /// Duplicates a note in its workspace and selects the copy when that
    /// workspace is active. Returns the new note's ID.
    @discardableResult
    func duplicateNote(_ id: Note.ID) -> Note.ID? {
        guard let location = locate(id) else { return nil }
        let original = workspaces[location.workspace].notes[location.note]
        let copy = Note(
            content: original.content,
            richTextData: original.richTextData,
            createdAt: now(),
            modifiedAt: now(),
            lastOpenedAt: now(),
            isPinned: original.isPinned
        )

        workspaces[location.workspace].notes.append(copy)
        if location.workspace == activeIndex {
            workspaces[location.workspace].selectedNoteID = copy.id
            markOpened(copy.id)
        }
        scheduleSave()
        return copy.id
    }

    @discardableResult
    func duplicateSelectedNote() -> Note.ID? {
        duplicateNote(selectedID)
    }

    /// Moves a note to another workspace while keeping both workspaces valid.
    @discardableResult
    func moveNote(_ id: Note.ID, to workspaceID: Workspace.ID) -> Bool {
        guard let source = locate(id),
              source.workspace != workspaces.firstIndex(where: { $0.id == workspaceID }),
              let target = workspaces.firstIndex(where: { $0.id == workspaceID }) else {
            return false
        }

        let note = workspaces[source.workspace].notes.remove(at: source.note)
        let sourceWasActive = source.workspace == activeIndex

        if workspaces[source.workspace].notes.isEmpty {
            let replacement = Note(createdAt: now())
            workspaces[source.workspace].notes.append(replacement)
            workspaces[source.workspace].selectedNoteID = replacement.id
        } else if workspaces[source.workspace].selectedNoteID == id {
            workspaces[source.workspace].selectedNoteID =
                Self.sortedNotes(workspaces[source.workspace].notes)[0].id
        }

        workspaces[target].notes.append(note)
        if sourceWasActive {
            markOpened(selectedID)
        }
        scheduleSave()
        return true
    }

    func selectNextNote() {
        let ordered = notesByRecency
        guard ordered.count > 1,
              let index = ordered.firstIndex(where: { $0.id == selectedID }) else {
            return
        }
        select(ordered[(index + 1) % ordered.count].id)
    }

    func selectPreviousNote() {
        let ordered = notesByRecency
        guard ordered.count > 1,
              let index = ordered.firstIndex(where: { $0.id == selectedID }) else {
            return
        }
        select(ordered[(index - 1 + ordered.count) % ordered.count].id)
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
        updateRichText(for: selectedID, content: content, richTextData: richTextData)
    }

    /// Updates just the plain text. Rich text is archived separately on a short
    /// debounce so typing does not run a full archive on every keystroke.
    func updateText(for noteID: Note.ID, content: String) {
        guard let location = locate(noteID),
              workspaces[location.workspace].notes[location.note].content != content else {
            return
        }
        workspaces[location.workspace].notes[location.note].content = content
        workspaces[location.workspace].notes[location.note].modifiedAt = now()
        scheduleSave()
    }

    /// Writes the latest rich-text archive. The note is located by ID so a
    /// delayed archive can never land on a note that became selected later.
    func updateRichText(for noteID: Note.ID, content: String, richTextData: Data?) {
        guard let location = locate(noteID) else { return }
        var note = workspaces[location.workspace].notes[location.note]
        guard note.content != content || note.richTextData != richTextData else { return }
        note.content = content
        note.richTextData = richTextData
        note.modifiedAt = now()
        workspaces[location.workspace].notes[location.note] = note
        scheduleSave()
    }

    private func locate(_ noteID: Note.ID) -> (workspace: Int, note: Int)? {
        for (workspaceIndex, workspace) in workspaces.enumerated() {
            if let noteIndex = workspace.notes.firstIndex(where: { $0.id == noteID }) {
                return (workspaceIndex, noteIndex)
            }
        }
        return nil
    }

    func deleteNote(_ id: Note.ID) {
        guard notes.contains(where: { $0.id == id }) else { return }
        let deletedSelection = selectedID == id
        let workspaceID = activeWorkspace.id
        let workspaceName = activeWorkspace.name

        updateActive { workspace in
            guard let index = workspace.notes.firstIndex(where: { $0.id == id }) else { return }
            let removed = workspace.notes.remove(at: index)
            if !removed.isEmpty {
                self.trash.append(TrashedNote(
                    note: removed,
                    workspaceID: workspaceID,
                    workspaceName: workspaceName,
                    deletedAt: self.now()
                ))
            }
            if workspace.notes.isEmpty {
                workspace.notes.append(Note(createdAt: self.now()))
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

    /// Adds imported notes to the active workspace, replacing an untouched
    /// empty note, and selects the first imported note.
    func importNotes(_ notes: [Note]) {
        guard !notes.isEmpty else { return }
        updateActive { workspace in
            if let index = workspace.notes.firstIndex(where: { $0.id == workspace.selectedNoteID }),
               workspace.notes[index].isEmpty {
                workspace.notes.remove(at: index)
            }
            workspace.notes.append(contentsOf: notes)
            workspace.selectedNoteID = notes[0].id
        }
        markOpened(notes[0].id)
        scheduleSave()
    }

    func restoreLastDeleted() {
        guard let entry = trash.last else { return }
        restore(entry.id)
    }

    /// Restores a trashed note to its original workspace, falling back to the
    /// active workspace when that workspace no longer exists.
    func restore(_ entryID: TrashedNote.ID) {
        guard let index = trash.firstIndex(where: { $0.id == entryID }) else { return }
        let entry = trash.remove(at: index)

        let targetID = workspaces.contains(where: { $0.id == entry.workspaceID })
            ? entry.workspaceID
            : selectedWorkspaceID
        guard let targetIndex = workspaces.firstIndex(where: { $0.id == targetID }) else {
            return
        }

        selectedWorkspaceID = targetID
        var workspace = workspaces[targetIndex]

        if let emptyIndex = workspace.notes.firstIndex(
            where: { $0.id == workspace.selectedNoteID }
        ), workspace.notes[emptyIndex].isEmpty {
            workspace.notes.remove(at: emptyIndex)
        }

        if !workspace.notes.contains(where: { $0.id == entry.note.id }) {
            workspace.notes.append(entry.note)
        }
        workspace.selectedNoteID = entry.note.id
        workspaces[targetIndex] = workspace

        markOpened(entry.note.id)
        scheduleSave()
    }

    func deletePermanently(_ entryID: TrashedNote.ID) {
        trash.removeAll { $0.id == entryID }
        scheduleSave()
    }

    func emptyTrash() {
        guard !trash.isEmpty else { return }
        trash.removeAll()
        scheduleSave()
    }

    /// Writes any pending changes immediately.
    func saveNow() {
        pendingSave?.cancel()
        pendingSave = nil
        guard let storage, !savesBlocked else { return }
        do {
            try storage.save(LibrarySnapshot(
                workspaces: workspaces,
                selectedWorkspaceID: selectedWorkspaceID,
                trash: trash
            ))
            saveError = nil
        } catch {
            saveError = error.localizedDescription
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
        if isTerminating {
            saveNow()
            return
        }
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
            if $0.modifiedAt != $1.modifiedAt { return $0.modifiedAt > $1.modifiedAt }
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
