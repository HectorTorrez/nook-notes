import SwiftUI

/// A keyboard-driven, filterable list shown inside a popover.
struct SearchPanel<Item: Identifiable, Row: View>: View {
    let placeholder: String
    let emptyMessage: String
    let items: [Item]
    let rowHeight: CGFloat
    let matches: (Item, String) -> Bool
    var isEnabled: (Item) -> Bool = { _ in true }
    let onSelect: (Item) -> Void
    @ViewBuilder let row: (Item) -> Row

    @State private var query = ""
    @State private var highlightedID: Item.ID?
    @FocusState private var isSearchFocused: Bool

    private static var maxListHeight: CGFloat { 320 }
    private static var listPadding: CGFloat { 6 }

    private var filtered: [Item] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? items : items.filter { matches($0, trimmed) }
    }

    private var selectable: [Item] {
        filtered.filter(isEnabled)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(placeholder, text: $query)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit(selectHighlighted)
                    .onKeyPress(.downArrow) { moveHighlight(by: 1); return .handled }
                    .onKeyPress(.upArrow) { moveHighlight(by: -1); return .handled }
            }
            .font(.system(size: 14))
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            Divider()

            if filtered.isEmpty {
                Text(emptyMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
            } else {
                list
            }
        }
        .onAppear {
            isSearchFocused = true
            highlightedID = selectable.first?.id
        }
        .onChange(of: query) {
            highlightedID = selectable.first?.id
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(filtered) { item in
                        let enabled = isEnabled(item)
                        Button {
                            onSelect(item)
                        } label: {
                            row(item)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .frame(height: rowHeight)
                                .background {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(item.id == highlightedID ? Color.primary.opacity(0.09) : .clear)
                                }
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!enabled)
                        .opacity(enabled ? 1 : 0.4)
                        .onHover { hovering in
                            if hovering, enabled { highlightedID = item.id }
                        }
                        .id(item.id)
                    }
                }
                .padding(Self.listPadding)
            }
            .scrollIndicators(.automatic)
            .frame(height: listHeight)
            .onChange(of: highlightedID) { _, id in
                if let id { proxy.scrollTo(id) }
            }
        }
    }

    private var listHeight: CGFloat {
        let rows = CGFloat(filtered.count)
        let content = rows * rowHeight + max(0, rows - 1) * 2 + Self.listPadding * 2
        return min(content, Self.maxListHeight)
    }

    private func moveHighlight(by offset: Int) {
        let ids = selectable.map(\.id)
        guard !ids.isEmpty else { return }
        guard let current = highlightedID, let index = ids.firstIndex(of: current) else {
            highlightedID = ids.first
            return
        }
        highlightedID = ids[(index + offset + ids.count) % ids.count]
    }

    private func selectHighlighted() {
        guard let item = selectable.first(where: { $0.id == highlightedID }) ?? selectable.first else { return }
        onSelect(item)
    }
}
