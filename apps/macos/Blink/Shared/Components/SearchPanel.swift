import SwiftUI

/// A keyboard-driven, filterable list shown inside a popover. Every panel in Blink
/// is built on this: a rounded search field, an optional section label, an animated
/// selection, and a footer of keyboard affordances.
struct SearchPanel<Item: Identifiable, Row: View, Trailing: View>: View {
    let placeholder: String
    let emptyMessage: String
    let items: [Item]
    let rowHeight: CGFloat
    var listCaption: String? = nil
    var emptyIcon: String = "magnifyingglass"
    var footerHints: [PanelFooter.Hint] = PanelFooter.navigation
    let matches: (Item, String) -> Bool
    var isEnabled: (Item) -> Bool = { _ in true }
    var showsTrailing: (Item) -> Bool = { _ in false }
    let onSelect: (Item) -> Void
    @ViewBuilder let row: (Item) -> Row
    @ViewBuilder let trailing: (Item) -> Trailing

    @State private var query = ""
    @State private var highlightedID: Item.ID?
    @State private var hoveredID: Item.ID?
    @FocusState private var isSearchFocused: Bool
    @Environment(\.themeAccent) private var accent

    private static var maxListHeight: CGFloat { 320 }
    private static var listPadding: CGFloat { Theme.listPadding }

    private var filtered: [Item] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? items : items.filter { matches($0, trimmed) }
    }

    private var selectable: [Item] {
        filtered.filter(isEnabled)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField

            if let listCaption {
                SectionCaption(text: listCaption)
            }

            if filtered.isEmpty {
                VStack(spacing: 0) {
                    Divider()
                    PanelEmptyState(systemImage: emptyIcon, message: emptyMessage)
                }
            } else {
                Divider()
                list
                Divider()
                PanelFooter(hints: footerHints)
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

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSearchFocused ? accent : .secondary)
            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onSubmit(selectHighlighted)
                .onKeyPress(.downArrow) { moveHighlight(by: 1); return .handled }
                .onKeyPress(.upArrow) { moveHighlight(by: -1); return .handled }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background {
            RoundedRectangle(cornerRadius: Theme.fieldCornerRadius, style: .continuous)
                .fill(Color.primary.opacity(0.055))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.fieldCornerRadius, style: .continuous)
                .strokeBorder(accent.opacity(isSearchFocused ? 0.5 : 0), lineWidth: 1)
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, listCaption == nil ? 10 : 6)
        .animation(.easeOut(duration: 0.15), value: isSearchFocused)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: Theme.rowSpacing) {
                    ForEach(filtered) { item in
                        let enabled = isEnabled(item)
                        Button {
                            onSelect(item)
                        } label: {
                            row(item)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                .padding(.leading, 8)
                                .padding(.trailing, 8)
                                .frame(height: rowHeight)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!enabled)
                        .overlay(alignment: .trailing) {
                            let trailingVisible = hoveredID == item.id || showsTrailing(item)
                            trailing(item)
                                .padding(.trailing, 6)
                                .opacity(trailingVisible ? 1 : 0)
                                .allowsHitTesting(trailingVisible)
                        }
                        .background {
                            RoundedRectangle(cornerRadius: Theme.rowCornerRadius, style: .continuous)
                                .fill(item.id == highlightedID ? accent.opacity(0.15) : .clear)
                        }
                        .opacity(enabled ? 1 : 0.4)
                        .onHover { hovering in
                            if hovering {
                                hoveredID = item.id
                                if enabled { highlightedID = item.id }
                            } else if hoveredID == item.id {
                                hoveredID = nil
                            }
                        }
                        .id(item.id)
                    }
                }
                .padding(Self.listPadding)
                .animation(.easeOut(duration: 0.12), value: highlightedID)
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
        let content = rows * rowHeight + max(0, rows - 1) * Theme.rowSpacing + Self.listPadding * 2
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

extension SearchPanel where Trailing == EmptyView {
    init(
        placeholder: String,
        emptyMessage: String,
        items: [Item],
        rowHeight: CGFloat,
        listCaption: String? = nil,
        emptyIcon: String = "magnifyingglass",
        footerHints: [PanelFooter.Hint] = PanelFooter.navigation,
        matches: @escaping (Item, String) -> Bool,
        isEnabled: @escaping (Item) -> Bool = { _ in true },
        onSelect: @escaping (Item) -> Void,
        @ViewBuilder row: @escaping (Item) -> Row
    ) {
        self.init(
            placeholder: placeholder,
            emptyMessage: emptyMessage,
            items: items,
            rowHeight: rowHeight,
            listCaption: listCaption,
            emptyIcon: emptyIcon,
            footerHints: footerHints,
            matches: matches,
            isEnabled: isEnabled,
            onSelect: onSelect,
            row: row,
            trailing: { _ in EmptyView() }
        )
    }
}
