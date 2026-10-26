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
}
