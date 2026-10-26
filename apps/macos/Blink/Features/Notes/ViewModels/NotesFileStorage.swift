import Foundation

struct NotesSnapshot: Codable, Equatable, Sendable {
    var notes: [Note]
    var selectedID: Note.ID
}

/// Reads and writes the workspace library as a JSON file.
/// Files saved before workspaces existed are loaded as a single Personal workspace.
struct NotesFileStorage: Sendable {
    let url: URL

    enum LoadResult: Sendable {
        case missing
        case loaded(LibrarySnapshot)
        case failure(LoadFailure)
    }

    struct LoadFailure: Sendable, LocalizedError {
        let url: URL
        let backupURL: URL?
        let blocksSaving: Bool
        let message: String

        var errorDescription: String? { message }
    }

    static var `default`: NotesFileStorage {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return NotesFileStorage(url: support.appendingPathComponent("Blink/notes.json"))
    }

    var backupsDirectory: URL {
        url.deletingLastPathComponent().appendingPathComponent("Backups", isDirectory: true)
    }

    /// Returns `.missing` when nothing has been saved yet. A file that can't be
    /// decoded is moved aside (never overwritten) and returned as a failure so
    /// the app can tell the user where the old data went.
    func load() -> LoadResult {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return .missing }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            return .failure(LoadFailure(
                url: url,
                backupURL: nil,
                blocksSaving: true,
                message: "Blink couldn’t read \(url.lastPathComponent): "
                    + "\(error.localizedDescription). Changes are not being saved "
                    + "to protect your data."
            ))
        }

        if let library = try? Self.decoder.decode(LibrarySnapshot.self, from: data) {
            guard library.schemaVersion <= LibrarySnapshot.currentSchemaVersion else {
                return .failure(LoadFailure(
                    url: url,
                    backupURL: nil,
                    blocksSaving: true,
                    message: "This notes file was created by a newer version of Blink. "
                        + "Update Blink to open it."
                ))
            }
            return .loaded(library)
        }

        if let legacy = try? Self.decoder.decode(NotesSnapshot.self, from: data) {
            return .loaded(LibrarySnapshot(migrating: legacy))
        }

        let stamp = Int(Date().timeIntervalSince1970 * 1000)
        let backup = url.deletingPathExtension()
            .appendingPathExtension("corrupt-\(stamp).json")

        do {
            try fileManager.moveItem(at: url, to: backup)
            try? fileManager.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: backup.path
            )
            return .failure(LoadFailure(
                url: url,
                backupURL: backup,
                blocksSaving: false,
                message: "Blink couldn’t read your notes file. The old file was "
                    + "moved to \(backup.lastPathComponent), and Blink started "
                    + "with a fresh note."
            ))
        } catch {
            return .failure(LoadFailure(
                url: url,
                backupURL: nil,
                blocksSaving: true,
                message: "Blink couldn’t read your notes file or move it aside. "
                    + "Changes are not being saved to protect your data."
            ))
        }
    }

    func save(_ snapshot: LibrarySnapshot) throws {
        let fileManager = FileManager.default
        let directory = url.deletingLastPathComponent()

        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        createDailyBackupIfNeeded()

        try Self.encoder.encode(snapshot).write(to: url, options: .atomic)
        try? fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }

    private func createDailyBackupIfNeeded() {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return }

        let directory = backupsDirectory
        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let name = "notes-\(Self.dayFormatter.string(from: Date())).json"
        let backup = directory.appendingPathComponent(name)
        if !fileManager.fileExists(atPath: backup.path) {
            try? fileManager.copyItem(at: url, to: backup)
            try? fileManager.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: backup.path
            )
        }

        pruneBackups(in: directory)
    }

    private func pruneBackups(in directory: URL) {
        let fileManager = FileManager.default
        let cutoff = Date().addingTimeInterval(-14 * 24 * 60 * 60)
        guard let names = try? fileManager.contentsOfDirectory(atPath: directory.path) else {
            return
        }

        for name in names where name.hasPrefix("notes-") && name.hasSuffix(".json") {
            let fileURL = directory.appendingPathComponent(name)
            guard let values = try? fileURL.resourceValues(
                forKeys: [.contentModificationDateKey]
            ), let date = values.contentModificationDate, date < cutoff else {
                continue
            }
            try? fileManager.removeItem(at: fileURL)
        }
    }

    /// Fractional seconds keep recency ordering stable across launches.
    private static let dateStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(dateStyle))
        }
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            try Date(decoder.singleValueContainer().decode(String.self), strategy: dateStyle)
        }
        return decoder
    }()
}
