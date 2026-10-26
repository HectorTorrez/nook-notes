import AppKit

/// The font families the editor can use for body text and headings.
enum EditorFontFamily: String, CaseIterable, Identifiable {
    case system
    case serif
    case rounded
    case monospaced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: String(localized: "System")
        case .serif: String(localized: "Serif")
        case .rounded: String(localized: "Rounded")
        case .monospaced: String(localized: "Monospaced")
        }
    }

    func font(size: CGFloat, bold: Bool) -> NSFont {
        let weight: NSFont.Weight = bold ? .semibold : .regular
        switch self {
        case .system:
            return .systemFont(ofSize: size, weight: weight)
        case .monospaced:
            return .monospacedSystemFont(ofSize: size, weight: weight)
        case .serif:
            return .systemFont(ofSize: size, weight: weight).withDesign(.serif)
        case .rounded:
            return .systemFont(ofSize: size, weight: weight).withDesign(.rounded)
        }
    }
}

/// The editor options shared by Settings, the format bar, and the text view.
struct EditorPreferences: Equatable {
    var fontFamily: EditorFontFamily = .system
    var checksSpelling = true
    var correctsSpelling = true
    var usesSmartQuotes = false
    var usesSmartDashes = false
    var usesTextReplacement = false
    var detectsLinks = false
    var showsFormatBarOnSelection = true
}

/// `@AppStorage` keys and defaults for editor preferences.
enum EditorSettings {
    static let fontFamilyKey = "editorFontFamily"
    static let spellCheckingKey = "editorSpellChecking"
    static let spellingCorrectionKey = "editorSpellingCorrection"
    static let smartQuotesKey = "editorSmartQuotes"
    static let smartDashesKey = "editorSmartDashes"
    static let textReplacementKey = "editorTextReplacement"
    static let linkDetectionKey = "editorLinkDetection"
    static let formatBarOnSelectionKey = "editorFormatBarOnSelection"

    static let checksSpellingDefault = true
    static let correctsSpellingDefault = true
    static let smartQuotesDefault = false
    static let smartDashesDefault = false
    static let textReplacementDefault = false
    static let detectsLinksDefault = false
    static let showsFormatBarOnSelectionDefault = true
}

private extension NSFont {
    func withDesign(_ design: NSFontDescriptor.SystemDesign) -> NSFont {
        guard let descriptor = fontDescriptor.withDesign(design),
              let font = NSFont(descriptor: descriptor, size: pointSize) else {
            return self
        }
        return font
    }
}
