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
        let library = try load(storage)
        #expect(library.schemaVersion == LibrarySnapshot.currentSchemaVersion)
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

        guard case .failure(let failure) = storage.load() else {
            Issue.record("Expected a load failure")
            return
        }

        #expect(failure.blocksSaving == false)
        #expect(failure.backupURL != nil)
        #expect(FileManager.default.fileExists(atPath: url.path) == false)

        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(names.contains { $0.hasPrefix("notes.corrupt-") && $0.hasSuffix(".json") })
    }

    @Test
    func unreadableFileThatCannotBeMovedBlocksSaving() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("notes.json")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let storage = NotesFileStorage(url: url)

        guard case .failure(let failure) = storage.load() else {
            Issue.record("Expected a load failure")
            return
        }

        #expect(failure.blocksSaving)
        #expect(failure.backupURL == nil)
    }

    @Test
    func decodesLibrariesThatPredateTheTrash() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("notes.json")
        let storage = NotesFileStorage(url: url)

        let note = Note(content: "Old note", createdAt: epoch)
        let workspace = Workspace(
            name: Workspace.defaultName,
            notes: [note],
            selectedNoteID: note.id,
            createdAt: epoch
        )
        try storage.save(LibrarySnapshot(
            workspaces: [workspace],
            selectedWorkspaceID: workspace.id
        ))

        var json = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
        json.removeValue(forKey: "trash")
        try JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ).write(to: url)

        let loaded = try load(storage)
        #expect(loaded.trash.isEmpty)
        #expect(loaded.workspaces[0].notes[0].content == "Old note")
    }

    @Test
    func newerSchemaVersionsAreRejected() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("notes.json")
        let storage = NotesFileStorage(url: url)

        let note = Note(content: "Future", createdAt: epoch)
        let workspace = Workspace(
            name: Workspace.defaultName,
            notes: [note],
            selectedNoteID: note.id,
            createdAt: epoch
        )
        try storage.save(LibrarySnapshot(
            workspaces: [workspace],
            selectedWorkspaceID: workspace.id
        ))

        var json = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
        json["schemaVersion"] = 99
        try JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ).write(to: url)

        guard case .failure(let failure) = storage.load() else {
            Issue.record("Expected a load failure")
            return
        }
        #expect(failure.blocksSaving)
        #expect(failure.message.localizedCaseInsensitiveContains("newer version"))
    }

    @Test
    func malformedNotesAreDroppedInsteadOfFailingTheLibrary() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("notes.json")
        let storage = NotesFileStorage(url: url)

        let first = Note(content: "Good", createdAt: epoch)
        let second = Note(content: "Bad", createdAt: epoch)
        let workspace = Workspace(
            name: Workspace.defaultName,
            notes: [first, second],
            selectedNoteID: second.id,
            createdAt: epoch
        )
        try storage.save(LibrarySnapshot(
            workspaces: [workspace],
            selectedWorkspaceID: workspace.id
        ))

        var json = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
        var workspaces = try #require(json["workspaces"] as? [[String: Any]])
        var notes = try #require(workspaces[0]["notes"] as? [[String: Any]])
        notes[1]["content"] = 123
        workspaces[0]["notes"] = notes
        json["workspaces"] = workspaces
        try JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ).write(to: url)

        let loaded = try load(storage)
        #expect(loaded.workspaces[0].notes.count == 1)
        #expect(loaded.workspaces[0].notes[0].content == "Good")
        #expect(loaded.workspaces[0].selectedNoteID == first.id)
    }

    @Test
    func savingCreatesADailyBackupAndOwnerOnlyFiles() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Blink/notes.json")
        let storage = NotesFileStorage(url: url)

        let first = Note(content: "First save", createdAt: epoch)
        let firstWorkspace = Workspace(
            name: Workspace.defaultName,
            notes: [first],
            selectedNoteID: first.id,
            createdAt: epoch
        )
        try storage.save(LibrarySnapshot(
            workspaces: [firstWorkspace],
            selectedWorkspaceID: firstWorkspace.id
        ))

        let second = Note(content: "Second save", createdAt: epoch)
        let secondWorkspace = Workspace(
            name: Workspace.defaultName,
            notes: [second],
            selectedNoteID: second.id,
            createdAt: epoch
        )
        try storage.save(LibrarySnapshot(
            workspaces: [secondWorkspace],
            selectedWorkspaceID: secondWorkspace.id
        ))

        let backups = try FileManager.default.contentsOfDirectory(
            atPath: storage.backupsDirectory.path
        )
        #expect(backups.contains { $0.hasPrefix("notes-") && $0.hasSuffix(".json") })

        let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let filePermissions = try #require(fileAttributes[.posixPermissions] as? NSNumber)
        #expect(filePermissions.intValue == 0o600)

        let directoryAttributes = try FileManager.default.attributesOfItem(
            atPath: url.deletingLastPathComponent().path
        )
        let directoryPermissions = try #require(
            directoryAttributes[.posixPermissions] as? NSNumber
        )
        #expect(directoryPermissions.intValue == 0o700)
    }

    @Test
    func loadReportsMissingFiles() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = NotesFileStorage(url: directory.appendingPathComponent("missing.json"))

        guard case .missing = storage.load() else {
            Issue.record("Expected a missing file")
            return
        }
    }

    private func load(_ storage: NotesFileStorage) throws -> LibrarySnapshot {
        switch storage.load() {
        case .loaded(let snapshot):
            return snapshot
        case .missing:
            throw CocoaError(.fileNoSuchFile)
        case .failure(let failure):
            throw failure
        }
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BlinkTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
