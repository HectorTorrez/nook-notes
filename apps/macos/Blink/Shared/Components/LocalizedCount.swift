import Foundation

/// Small count helper that localizes the noun without needing plural rules in
/// call sites.
enum LocalizedCount {
    static func text(
        _ value: Int,
        singular: String.LocalizationValue,
        plural: String.LocalizationValue
    ) -> String {
        let noun = value == 1 ? String(localized: singular) : String(localized: plural)
        return "\(value) \(noun)"
    }

    static func notes(_ value: Int) -> String {
        text(value, singular: "note", plural: "notes")
    }

    static func workspaces(_ value: Int) -> String {
        text(value, singular: "workspace", plural: "workspaces")
    }

    static func words(_ value: Int) -> String {
        text(value, singular: "word", plural: "words")
    }

    static func characters(_ value: Int) -> String {
        text(value, singular: "character", plural: "characters")
    }

    static func deletedNotes(_ value: Int) -> String {
        text(value, singular: "deleted note", plural: "deleted notes")
    }
}
