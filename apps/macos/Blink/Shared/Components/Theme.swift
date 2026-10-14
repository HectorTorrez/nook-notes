import SwiftUI

/// The colors Blink can paint its active and selected states with.
enum AccentPalette: String, CaseIterable, Identifiable {
    case graphite
    case blue
    case indigo
    case purple
    case pink
    case red
    case orange
    case green
    case teal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .graphite: "Graphite"
        case .blue: "Blue"
        case .indigo: "Indigo"
        case .purple: "Purple"
        case .pink: "Pink"
        case .red: "Red"
        case .orange: "Orange"
        case .green: "Green"
        case .teal: "Teal"
        }
    }

    var color: Color {
        switch self {
        case .graphite: .gray
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .red: .red
        case .orange: .orange
        case .green: .green
        case .teal: .teal
        }
    }
}

/// Shared visual language for Blink's floating panels and chrome.
enum Theme {
    /// UserDefaults key and default for the selectable accent palette.
    static let accentPaletteKey = "accentPalette"
    static let defaultAccentPalette: AccentPalette = .graphite

    static let rowCornerRadius: CGFloat = 8
    static let fieldCornerRadius: CGFloat = 9
    static let rowSpacing: CGFloat = 2
    static let listPadding: CGFloat = 6
    static let controlHeight: CGFloat = 24
}

/// A small uppercase section label that sits above a list or form group.
struct SectionCaption: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.7)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 9)
            .padding(.bottom, 3)
            .accessibilityHidden(true)
    }
}

/// A row of keyboard affordances shown at the bottom of a panel, such as
/// `↑↓ Navigate  ↵ Open  esc Close`.
struct PanelFooter: View {
    struct Hint {
        let keys: [String]
        let label: String
    }

    let hints: [Hint]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(hints.indices, id: \.self) { index in
                let hint = hints[index]
                HStack(spacing: 5) {
                    ForEach(hint.keys, id: \.self) { key in
                        Text(key)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 16, minHeight: 16)
                            .padding(.horizontal, 4)
                            .background {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.primary.opacity(0.07))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                            }
                    }
                    Text(hint.label)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .accessibilityHidden(true)
    }

    static let navigation: [Hint] = [
        Hint(keys: ["↑", "↓"], label: "Navigate"),
        Hint(keys: ["↵"], label: "Open"),
        Hint(keys: ["esc"], label: "Close"),
    ]
}

/// A centred icon and message shown when a panel has nothing to display.
struct PanelEmptyState: View {
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tertiary)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }
}

private struct ThemeAccentKey: EnvironmentKey {
    static let defaultValue: Color = Theme.defaultAccentPalette.color
}

extension EnvironmentValues {
    /// The accent chosen in Appearance, inherited by every panel and control.
    var themeAccent: Color {
        get { self[ThemeAccentKey.self] }
        set { self[ThemeAccentKey.self] = newValue }
    }
}
