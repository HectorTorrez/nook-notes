import Foundation

struct Note: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    var content: String
    let createdAt: Date
    var modifiedAt: Date
    var lastOpenedAt: Date
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        content: String = "",
        createdAt: Date,
        modifiedAt: Date? = nil,
        lastOpenedAt: Date? = nil,
        isPinned: Bool = false
    ) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt ?? createdAt
        self.lastOpenedAt = lastOpenedAt ?? createdAt
        self.isPinned = isPinned
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

    var characterCount: Int {
        content.count
    }

    enum CodingKeys: String, CodingKey {
        case id, content, createdAt, modifiedAt, lastOpenedAt, isPinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
        lastOpenedAt = try container.decodeIfPresent(Date.self, forKey: .lastOpenedAt) ?? modifiedAt
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }
}
