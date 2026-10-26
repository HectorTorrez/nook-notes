import Foundation
import Testing

@testable import Blink

@MainActor
struct NotesFileStorageTests {
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    @Test
    func savingAndLoadingRoundTripsWorkspacesAndSelection() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = NotesFileStorage(url: directory.appendingPathComponent("notes.json"))

        let store = NotesStore(storage: storage, now: { self.epoch })
        store.updateSelectedContent("Persisted note", richTextData: nil)
        store.saveNow()

        let expectedWorkspaceID = store.selectedWorkspaceID
        let library = try #require(storage.load())
        #expect(library.workspaces.count == 1)
        #expect(library.workspaces[0].notes[0].content == "Persisted note")
        #expect(library.selectedWorkspaceID == expectedWorkspaceID)
    }

    @Test
    func legacySnapshotMigratesIntoAPersonalWorkspace() {
        let note = Note(content: "Legacy note", createdAt: epoch)
        let legacy = NotesSnapshot(notes: [note], selectedID: note.id)

        let library = LibrarySnapshot(migrating: legacy, now: epoch)

        #expect(library.workspaces.count == 1)
        #expect(library.workspaces[0].name == Workspace.defaultName)
        #expect(library.workspaces[0].notes.map(\.id) == [note.id])
        #expect(library.workspaces[0].selectedNoteID == note.id)
        #expect(library.selectedWorkspaceID == library.workspaces[0].id)
    }

    @Test
    func unreadableFileIsMovedAsideInsteadOfOverwritten() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("notes.json")
        try Data("this is not JSON".utf8).write(to: url)
        let storage = NotesFileStorage(url: url)

        #expect(storage.load() == nil)
        #expect(FileManager.default.fileExists(atPath: url.path) == false)

        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(names.contains { $0.hasPrefix("notes.corrupt-") && $0.hasSuffix(".json") })
    }

    @Test
    func loadReturnsNilWhenNothingHasBeenSaved() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = NotesFileStorage(url: directory.appendingPathComponent("missing.json"))

        #expect(storage.load() == nil)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BlinkTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
