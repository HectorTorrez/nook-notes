import SwiftUI

struct NotesBrowser: View {
    let store: NotesStore
    /// Captured when the list opens, so the labels stay put until the next open.
    let listedAt: Date
    let onSelect: (Note.ID) -> Void

    @Environment(\.themeAccent) private var accent

    private var noteCountLabel: String {
        store.notes.count == 1 ? "1 note" : "\(store.notes.count) notes"
    }

    var body: some View {
        SearchPanel(
            placeholder: "Search notes",
            emptyMessage: "No matching notes",
            items: store.notesByRecency,
            rowHeight: 50,
            listCaption: noteCountLabel,
            emptyIcon: "note.text",
            matches: { note, query in
                note.content.localizedCaseInsensitiveContains(query)
            },
            onSelect: { onSelect($0.id) },
            row: { note in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        if note.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.orange)
                                .accessibilityHidden(true)
                        }
                        Text(note.title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(note.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                    }
                    HStack(spacing: 5) {
                        if note.id == store.selectedID {
                            Text("Current")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(accent)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background {
                                    Capsule(style: .continuous)
                                        .fill(accent.opacity(0.16))
                                }
                        } else {
                            Text(OpenedWhen.label(for: note.lastOpenedAt, now: listedAt))
                                .foregroundStyle(.secondary)
                        }
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(characterLabel(for: note))
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 11))
                    .lineLimit(1)
                }
                .padding(.trailing, 52)
            },
            trailing: { note in
                HStack(spacing: 0) {
                    RowActionButton(
                        systemImage: note.isPinned ? "pin.fill" : "pin",
                        help: note.isPinned ? "Unpin" : "Pin",
                        tint: note.isPinned ? .orange : .secondary
                    ) {
                        store.togglePin(note.id)
                    }
                    RowActionButton(
                        systemImage: "trash",
                        help: "Delete",
                        tint: .secondary,
                        isDestructive: true
                    ) {
                        store.deleteNote(note.id)
                    }
                }
            }
        )
        .frame(width: 360)
    }

    private func characterLabel(for note: Note) -> String {
        note.characterCount == 1 ? "1 character" : "\(note.characterCount) characters"
    }
}

/// Coarse labels such as today, yesterday, and one week ago.
private enum OpenedWhen {
    static func label(for date: Date, now: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: now)
        ).day ?? 0

        if days <= 0 { return "today" }
        if days == 1 { return "yesterday" }
        if days < 7 { return "\(spell(days)) days ago" }
        if days < 30 {
            let weeks = max(1, days / 7)
            return weeks == 1 ? "one week ago" : "\(spell(weeks)) weeks ago"
        }
        if days < 365 {
            let months = max(1, days / 30)
            return months == 1 ? "one month ago" : "\(spell(months)) months ago"
        }
        let years = max(1, days / 365)
        return years == 1 ? "one year ago" : "\(spell(years)) years ago"
    }

    private static func spell(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

struct RowActionButton: View {
    let systemImage: String
    let help: String
    let tint: Color
    var isDestructive: Bool = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isHovering && isDestructive ? Color.red : tint)
                .frame(width: 24, height: 24)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(isHovering ? 0.08 : 0))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .onHover { isHovering = $0 }
    }
}
