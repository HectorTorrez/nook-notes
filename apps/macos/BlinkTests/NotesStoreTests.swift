import AppKit
import Foundation
import Testing

@testable import Blink

@MainActor
struct NotesStoreTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    @Test
    func startsWithOnePersonalWorkspaceAndAnEmptyNote() {
        let store = NotesStore(now: { self.epoch })

        #expect(store.workspaces.count == 1)
        #expect(store.activeWorkspace.name == Workspace.defaultName)
        #expect(store.notes.count == 1)
        #expect(store.selectedNote.isEmpty)
    }

    @Test
    func reusesTheSelectedNoteWhenItIsStillEmpty() {
        let store = NotesStore(now: { self.epoch })

        store.updateSelectedContent("First note", richTextData: nil)
        store.createNote()
        #expect(store.notes.count == 2)

        store.createNote()
        #expect(store.notes.count == 2)
    }

    @Test
    func deletingAndRestoringANotePreservesItsContent() {
        let store = NotesStore(now: { self.epoch })
        store.updateSelectedContent("Keep me", richTextData: nil)

        let deletedID = store.selectedID
        store.deleteNote(deletedID)

        #expect(store.selectedID != deletedID)
        #expect(store.lastDeleted?.content == "Keep me")

        store.restoreLastDeleted()

        #expect(store.selectedNote.content == "Keep me")
        #expect(store.lastDeleted == nil)
    }

    @Test
    func pinnedNotesSortBeforeNewerNotes() {
        let store = NotesStore(now: { self.epoch })
        store.updateSelectedContent("Older", richTextData: nil)
        let olderID = store.selectedID

        store.createNote()
        store.updateSelectedContent("Newer", richTextData: nil)

        store.togglePin(olderID)

        #expect(store.notesByRecency.map(\.content) == ["Older", "Newer"])
    }

    @Test
    func workspacesKeepTheirOwnSelectedNote() {
        let store = NotesStore(now: { self.epoch })
        store.updateSelectedContent("Personal note", richTextData: nil)
        let personalWorkspaceID = store.selectedWorkspaceID

        #expect(store.createWorkspace(named: "Work"))
        store.updateSelectedContent("Work note", richTextData: nil)
        let workWorkspaceID = store.selectedWorkspaceID

        store.selectWorkspace(personalWorkspaceID)
        #expect(store.selectedNote.content == "Personal note")

        store.selectWorkspace(workWorkspaceID)
        #expect(store.selectedNote.content == "Work note")
    }

    @Test
    func textUpdatesTargetTheNoteIDInsteadOfTheCurrentSelection() {
        let store = NotesStore(now: { self.epoch })
        store.updateSelectedContent("First", richTextData: nil)
        let firstID = store.selectedID

        store.createNote()
        let secondID = store.selectedID

        store.updateText(for: firstID, content: "Edited first")

        #expect(store.selectedID == secondID)
        #expect(store.notes.first(where: { $0.id == firstID })?.content == "Edited first")
        #expect(store.notes.first(where: { $0.id == secondID })?.content == "")
    }

    @Test
    func trashPersistsAcrossLaunches() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = NotesFileStorage(url: directory.appendingPathComponent("notes.json"))

        let store = NotesStore(storage: storage, now: { self.epoch })
        store.updateSelectedContent("Persisted trash", richTextData: nil)
        store.deleteNote(store.selectedID)
        store.saveNow()

        let reloaded = NotesStore(storage: storage, now: { self.epoch })
        #expect(reloaded.trashCount == 1)
        #expect(reloaded.lastDeleted?.content == "Persisted trash")
        #expect(reloaded.trash.first?.workspaceName == Workspace.defaultName)
    }

    @Test
    func restoreReturnsANoteToItsOriginalWorkspace() throws {
        let store = NotesStore(now: { self.epoch })
        let personalID = store.selectedWorkspaceID

        #expect(store.createWorkspace(named: "Work"))
        let workID = store.selectedWorkspaceID
        store.updateSelectedContent("Work note", richTextData: nil)
        store.deleteNote(store.selectedID)

        store.selectWorkspace(personalID)
        let entry = try #require(store.trash.last)
        store.restore(entry.id)

        #expect(store.selectedWorkspaceID == workID)
        #expect(store.selectedNote.content == "Work note")
        #expect(store.trash.isEmpty)
    }

    @Test
    func deletingAWorkspaceMovesItsNotesToTrash() throws {
        let store = NotesStore(now: { self.epoch })
        let personalID = store.selectedWorkspaceID

        #expect(store.createWorkspace(named: "Work"))
        let workID = store.selectedWorkspaceID
        store.updateSelectedContent("Work note", richTextData: nil)

        store.deleteWorkspace(workID)

        #expect(store.trashCount == 1)
        #expect(store.lastDeleted?.content == "Work note")

        // The original workspace is gone, so the note returns to the active one.
        store.restoreLastDeleted()

        #expect(store.selectedWorkspaceID == personalID)
        #expect(store.selectedNote.content == "Work note")
    }

    @Test
    func trashCanBeEmptiedOrDeletedPermanently() throws {
        let store = NotesStore(now: { self.epoch })

        store.updateSelectedContent("One", richTextData: nil)
        store.deleteNote(store.selectedID)
        store.updateSelectedContent("Two", richTextData: nil)
        store.deleteNote(store.selectedID)

        #expect(store.trashCount == 2)
        let firstEntry = try #require(store.trash.first)
        store.deletePermanently(firstEntry.id)
        #expect(store.trashCount == 1)

        store.emptyTrash()
        #expect(store.trash.isEmpty)
        #expect(store.lastDeleted == nil)
    }

    @Test
    func importNotesReplacesTheEmptySelectedNoteAndSelectsTheFirstImport() {
        let store = NotesStore(now: { self.epoch })
        let first = Note(content: "Imported one", createdAt: epoch)
        let second = Note(content: "Imported two", createdAt: epoch)

        store.importNotes([first, second])

        #expect(store.notes.count == 2)
        #expect(store.selectedID == first.id)
        #expect(store.notes.contains(where: { $0.id == second.id }))
    }

    @Test
    func richTextUpdatesTargetTheNoteIDInsteadOfTheCurrentSelection() throws {
        let store = NotesStore(now: { self.epoch })
        store.updateSelectedContent("First", richTextData: nil)
        let firstID = store.selectedID

        store.createNote()
        let secondID = store.selectedID

        let archive = try #require(
            RichTextCoding.data(from: NSAttributedString(string: "Archived"))
        )
        store.updateRichText(for: firstID, content: "Edited first", richTextData: archive)

        #expect(store.selectedID == secondID)
        #expect(store.notes.first(where: { $0.id == firstID })?.richTextData == archive)
        #expect(store.notes.first(where: { $0.id == secondID })?.richTextData == nil)
    }

    @Test
    func deletingTheLastWorkspaceIsNotAllowed() {
        let store = NotesStore(now: { self.epoch })
        let onlyWorkspace = store.selectedWorkspaceID

        #expect(store.canDeleteWorkspace == false)
        store.deleteWorkspace(onlyWorkspace)
        #expect(store.workspaces.count == 1)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BlinkStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
