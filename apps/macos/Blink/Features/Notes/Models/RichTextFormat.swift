import AppKit
import SwiftUI

extension NSAttributedString.Key {
    /// Paragraph heading level (`Int`, mirroring `HeadingLevel`). Absent means body text.
    static let blinkHeading = NSAttributedString.Key("blink.heading")
    /// Marks a run as inline code (`Bool`).
    static let blinkCode = NSAttributedString.Key("blink.code")
    /// Marks a paragraph as a block quote (`Bool`).
    static let blinkBlockquote = NSAttributedString.Key("blink.blockquote")
}

/// The paragraph styles offered in the heading menu.
enum HeadingLevel: Int, CaseIterable, Identifiable {
    case heading1 = 1
    case heading2 = 2
    case heading3 = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .heading1: "Heading 1"
        case .heading2: "Heading 2"
        case .heading3: "Heading 3"
        }
    }

    var shortcutKeys: [String] {
        switch self {
        case .heading1: ["⌥", "⌘", "1"]
        case .heading2: ["⌥", "⌘", "2"]
        case .heading3: ["⌥", "⌘", "3"]
        }
    }

    var shortcut: KeyboardShortcut? {
        switch self {
        case .heading1: KeyboardShortcut("1", modifiers: [.command, .option])
        case .heading2: KeyboardShortcut("2", modifiers: [.command, .option])
        case .heading3: KeyboardShortcut("3", modifiers: [.command, .option])
        }
    }

    /// Point size relative to the user's chosen body size.
    func size(base: CGFloat) -> CGFloat {
        switch self {
        case .heading1: (base * 1.7).rounded()
        case .heading2: (base * 1.4).rounded()
        case .heading3: (base * 1.18).rounded()
        }
    }
}

/// The list styles offered in the list menu.
enum ListStyle: String, CaseIterable, Identifiable {
    case ordered
    case bullet
    case task

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ordered: "Ordered List"
        case .bullet: "Bullet List"
        case .task: "Task List"
        }
    }

    var systemImage: String {
        switch self {
        case .ordered: "list.number"
        case .bullet: "list.bullet"
        case .task: "checklist"
        }
    }

    var shortcutKeys: [String] {
        switch self {
        case .ordered: ["⇧", "⌘", "7"]
        case .bullet: ["⇧", "⌘", "8"]
        case .task: ["⇧", "⌘", "9"]
        }
    }

    var shortcut: KeyboardShortcut {
        switch self {
        case .ordered: KeyboardShortcut("7", modifiers: [.command, .shift])
        case .bullet: KeyboardShortcut("8", modifiers: [.command, .shift])
        case .task: KeyboardShortcut("9", modifiers: [.command, .shift])
        }
    }

    var markerFormat: NSTextList.MarkerFormat {
        switch self {
        case .ordered: .decimal
        case .bullet: .disc
        case .task: .box
        }
    }

    init?(markerFormat: NSTextList.MarkerFormat) {
        switch markerFormat {
        case .decimal: self = .ordered
        case .disc, .circle, .square: self = .bullet
        case .box, .check: self = .task
        default: return nil
        }
    }
}

/// Normalizes link text so links always have a scheme.
enum RichTextLink {
    static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil {
            return trimmed
        }
        return "https://\(trimmed)"
    }
}

/// Builds the concrete font for a run from its formatting flags.
enum RichTextFont {
    static func make(
        size: CGFloat,
        bold: Bool,
        italic: Bool,
        code: Bool,
        family: EditorFontFamily = .system
    ) -> NSFont {
        let base: NSFont
        if code {
            base = NSFont.monospacedSystemFont(ofSize: size, weight: bold ? .semibold : .regular)
        } else {
            base = family.font(size: size, bold: bold)
        }
        guard italic else { return base }
        return NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
    }
}

/// Persists rich notes as a keyed archive so custom attributes (headings, lists, code)
/// survive a round trip through the JSON store.
enum RichTextCoding {
    static func data(from attributedString: NSAttributedString) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: attributedString, requiringSecureCoding: true)
    }

    static func attributedString(from data: Data) -> NSAttributedString? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSAttributedString.self, from: data)
    }
}
