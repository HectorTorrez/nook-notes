import Foundation

struct Note: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    var content: String
    let createdAt: Date
    var modifiedAt: Date

    init(id: UUID = UUID(), content: String = "", createdAt: Date, modifiedAt: Date? = nil) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt ?? createdAt
    }

    /// The first non-blank line, which the UI treats as the note's title.
    var title: String {
        for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { return trimmed }
        }
        return "Untitled"
    }

    var isEmpty: Bool {
        content.allSatisfy(\.isWhitespace)
    }
}
