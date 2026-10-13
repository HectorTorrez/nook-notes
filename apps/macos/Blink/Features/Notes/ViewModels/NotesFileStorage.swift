import Foundation

struct NotesSnapshot: Codable, Equatable, Sendable {
    var notes: [Note]
    var selectedID: Note.ID
}

/// Reads and writes notes as a JSON file.
struct NotesFileStorage: Sendable {
    let url: URL

    static var `default`: NotesFileStorage {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return NotesFileStorage(url: support.appendingPathComponent("Blink/notes.json"))
    }

    /// Returns `nil` when nothing has been saved yet. A file that can't be decoded is moved aside
    /// (never overwritten) so the user's data can still be recovered by hand.
    func load() -> NotesSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try Self.decoder.decode(NotesSnapshot.self, from: data)
        } catch {
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = url.deletingPathExtension().appendingPathExtension("corrupt-\(stamp).json")
            try? FileManager.default.moveItem(at: url, to: backup)
            return nil
        }
    }

    func save(_ snapshot: NotesSnapshot) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Self.encoder.encode(snapshot).write(to: url, options: .atomic)
    }

    /// Fractional seconds keep recency ordering stable across launches.
    private static let dateStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

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
