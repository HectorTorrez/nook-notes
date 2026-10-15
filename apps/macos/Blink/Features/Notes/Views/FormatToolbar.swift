import SwiftUI

/// The floating formatting bar, shown while text is selected or pinned open from
/// the letter button. Mirrors the heading, character-style, list and appearance
/// controls into the note editor.
struct FormatToolbar: View {
    let controller: RichTextController
    @Binding var backgroundOpacity: Double
    @Binding var fontSize: Double
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                HeadingMenuButton(controller: controller)
                TextStyleMenuButton(controller: controller)

                LinkButton(controller: controller)

                FormatIconButton(
                    systemImage: "chevron.left.forwardslash.chevron.right",
                    help: "Code",
                    isActive: controller.isCode
                ) {
                    controller.toggleCode()
                }

                separator

                FormatIconButton(
                    systemImage: "text.quote",
                    help: "Block Quote",
                    isActive: controller.isBlockquote
                ) {
                    controller.toggleBlockquote()
                }

                AlignmentMenuButton(controller: controller)

                separator

                ListMenuButton(controller: controller)

                separator

                AppearanceMenuButton(
                    backgroundOpacity: $backgroundOpacity,
                    fontSize: $fontSize
                )
            }
            .padding(3)
            .formatGlass(in: Capsule())

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.black))
                    .contentShape(Circle())
            }
            .buttonStyle(PointerButtonStyle())
            .help("Dismiss")
            .accessibilityLabel("Dismiss formatting bar")
        }
        .fixedSize()
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 1, height: 16)
            .padding(.horizontal, 4)
    }
}

// MARK: - Menu buttons

private struct HeadingMenuButton: View {
    let controller: RichTextController
    @State private var shown = false

    var body: some View {
        Button { shown.toggle() } label: {
            FormatMenuLabel(isActive: controller.heading != nil, isOpen: shown) {
                Text("H").font(.system(size: 14, weight: .semibold, design: .serif))
            }
        }
        .buttonStyle(PointerButtonStyle())
        .popover(isPresented: $shown, arrowEdge: .top) {
            VStack(spacing: 2) {
                ForEach(HeadingLevel.allCases) { level in
                    Button {
                        controller.setHeading(level)
                        shown = false
                    } label: {
                        FormatMenuRow(
                            title: level.title,
                            keys: level.shortcutKeys,
                            isActive: controller.heading == level
                        ) {
                            Text("H").font(.system(size: 13, weight: .semibold, design: .serif))
                        }
                    }
                    .buttonStyle(PointerButtonStyle())
                }
            }
            .padding(6)
            .frame(width: 230)
        }
        .help("Heading")
        .accessibilityLabel("Heading")
    }
}

private struct TextStyleMenuButton: View {
    let controller: RichTextController
    @State private var shown = false

    private var isActive: Bool {
        controller.isBold || controller.isItalic || controller.isUnderlined || controller.isStruckThrough
    }

    var body: some View {
        Button { shown.toggle() } label: {
            FormatMenuLabel(isActive: isActive, isOpen: shown) {
                Text("I").font(.system(size: 14, weight: .semibold, design: .serif))
            }
        }
        .buttonStyle(PointerButtonStyle())
        .popover(isPresented: $shown, arrowEdge: .top) {
            VStack(spacing: 2) {
                Button {
                    controller.toggleBold()
                    shown = false
                } label: {
                    FormatMenuRow(title: "Bold", keys: ["⌘", "B"], isActive: controller.isBold) {
                        Text("B").font(.system(size: 13, weight: .bold, design: .serif))
                    }
                }
                .buttonStyle(PointerButtonStyle())

                Button {
                    controller.toggleItalic()
                    shown = false
                } label: {
                    FormatMenuRow(title: "Italic", keys: ["⌘", "I"], isActive: controller.isItalic) {
                        Text("I").font(.system(size: 13, weight: .medium, design: .serif)).italic()
                    }
                }
                .buttonStyle(PointerButtonStyle())

                Button {
                    controller.toggleStrikethrough()
                    shown = false
                } label: {
                    FormatMenuRow(
                        title: "Strikethrough",
                        keys: ["⇧", "⌘", "S"],
                        isActive: controller.isStruckThrough
                    ) {
                        Text("S").font(.system(size: 13, weight: .medium, design: .serif)).strikethrough()
                    }
                }
                .buttonStyle(PointerButtonStyle())

                Button {
                    controller.toggleUnderline()
                    shown = false
                } label: {
                    FormatMenuRow(title: "Underline", keys: ["⌘", "U"], isActive: controller.isUnderlined) {
                        Text("U").font(.system(size: 13, weight: .medium, design: .serif)).underline()
                    }
                }
                .buttonStyle(PointerButtonStyle())
            }
            .padding(6)
            .frame(width: 250)
        }
        .help("Text Style")
        .accessibilityLabel("Text Style")
    }
}

private struct ListMenuButton: View {
    let controller: RichTextController
    @State private var shown = false

    var body: some View {
        Button { shown.toggle() } label: {
            FormatMenuLabel(width: 46, isActive: controller.listStyle != nil, isOpen: shown) {
                Image(systemName: controller.listStyle?.systemImage ?? "list.bullet")
                    .font(.system(size: 13, weight: .medium))
            }
        }
        .buttonStyle(PointerButtonStyle())
        .popover(isPresented: $shown, arrowEdge: .top) {
            VStack(spacing: 2) {
                ForEach(ListStyle.allCases) { style in
                    Button {
                        controller.setList(style)
                        shown = false
                    } label: {
                        FormatMenuRow(
                            title: style.title,
                            keys: style.shortcutKeys,
                            isActive: controller.listStyle == style
                        ) {
                            Image(systemName: style.systemImage)
                                .font(.system(size: 13, weight: .medium))
                        }
                    }
                    .buttonStyle(PointerButtonStyle())
                }
            }
            .padding(6)
            .frame(width: 250)
        }
        .help("Lists")
        .accessibilityLabel("Lists")
    }
}

private struct AlignmentMenuButton: View {
    let controller: RichTextController
    @State private var shown = false

    private static let options: [(title: String, value: NSTextAlignment, symbol: String)] = [
        ("Left", .left, "text.alignleft"),
        ("Center", .center, "text.aligncenter"),
        ("Right", .right, "text.alignright"),
        ("Justify", .justified, "text.justify"),
    ]

    private var symbol: String {
        Self.options.first { $0.value == controller.alignment }?.symbol ?? "text.alignleft"
    }

    var body: some View {
        Button { shown.toggle() } label: {
            FormatMenuLabel(width: 46, isActive: controller.alignment != .natural && controller.alignment != .left, isOpen: shown) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
            }
        }
        .buttonStyle(PointerButtonStyle())
        .popover(isPresented: $shown, arrowEdge: .top) {
            VStack(spacing: 2) {
                ForEach(Self.options, id: \.title) { option in
                    Button {
                        controller.setAlignment(option.value)
                        shown = false
                    } label: {
                        FormatMenuRow(
                            title: option.title,
                            keys: [],
                            isActive: controller.alignment == option.value
                        ) {
                            Image(systemName: option.symbol)
                                .font(.system(size: 13, weight: .medium))
                        }
                    }
                    .buttonStyle(PointerButtonStyle())
                }
            }
            .padding(6)
            .frame(width: 200)
        }
        .help("Alignment")
        .accessibilityLabel("Alignment")
    }
}

private struct AppearanceMenuButton: View {
    @Binding var backgroundOpacity: Double
    @Binding var fontSize: Double
    @State private var shown = false

    var body: some View {
        Button { shown.toggle() } label: {
            FormatMenuLabel(isOpen: shown) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 13, weight: .medium))
            }
        }
        .buttonStyle(PointerButtonStyle())
        .popover(isPresented: $shown, arrowEdge: .top) {
            AppearancePanel(backgroundOpacity: $backgroundOpacity, fontSize: $fontSize)
        }
        .help("Appearance")
        .accessibilityLabel("Appearance")
    }
}

private struct LinkButton: View {
    let controller: RichTextController
    @State private var shown = false
    @State private var url = ""

    var body: some View {
        Button {
            url = controller.link ?? ""
            shown.toggle()
        } label: {
            Image(systemName: "link")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(controller.link != nil ? Color.accentColor : .primary)
                .frame(width: 30, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(PointerButtonStyle())
        .popover(isPresented: $shown, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Link")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("https://example.com", text: $url)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(apply)
                HStack {
                    if controller.link != nil {
                        Button("Remove") {
                            controller.applyLink(nil)
                            shown = false
                        }
                        .buttonStyle(PointerButtonStyle())
                    }
                    Spacer()
                    Button("Apply", action: apply)
                        .buttonStyle(PointerButtonStyle())
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(12)
            .frame(width: 260)
        }
        .help("Link")
        .accessibilityLabel("Link")
    }

    private func apply() {
        controller.applyLink(url)
        shown = false
    }
}

// MARK: - Building blocks

private struct FormatMenuLabel<Glyph: View>: View {
    var width: CGFloat = 44
    var isActive = false
    var isOpen = false
    @ViewBuilder let glyph: () -> Glyph

    @Environment(\.themeAccent) private var accent
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 3) {
            glyph()
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .frame(width: width, height: 26)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(hovering || isOpen ? accent.opacity(0.15) : (isActive ? accent.opacity(0.10) : .clear))
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

private struct FormatIconButton: View {
    let systemImage: String
    let help: String
    var isActive = false
    let action: () -> Void

    @Environment(\.themeAccent) private var accent
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isActive ? accent : .primary)
                .frame(width: 30, height: 26)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(hovering || isActive ? accent.opacity(isActive ? 0.18 : 0.12) : .clear)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(PointerButtonStyle())
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

private struct FormatMenuRow<Leading: View>: View {
    let title: String
    let keys: [String]
    var isActive = false
    @ViewBuilder let leading: () -> Leading

    @Environment(\.themeAccent) private var accent
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            leading()
                .frame(width: 22, height: 18)
            Text(title)
                .font(.system(size: 13, weight: .medium))
            Spacer(minLength: 16)
            if !keys.isEmpty {
                KeyCaps(keys: keys)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(hovering || isActive ? accent.opacity(0.15) : .clear)
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

private extension View {
    @ViewBuilder
    func formatGlass(in shape: some Shape) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
                .overlay(shape.stroke(.separator, lineWidth: 0.5))
        }
    }
}
