import SwiftUI

struct NotesView: View {
    let store: NotesStore

    @State private var panel: NotesPanel?
    @State private var showsCopyConfirmation = false
    @State private var isHovering = false
    @State private var titleBarHeight: CGFloat = 40
    @AppStorage("fontSize") private var fontSize: Double = 16
    @AppStorage("backgroundOpacity") private var backgroundOpacity: Double = 0.75

    /// Clears the traffic lights on the leading edge of the title bar.
    private static let trafficLightsWidth: CGFloat = 86

    private var note: Note { store.selectedNote }

    /// Controls stay visible while one of their popovers is open so it keeps its anchor.
    private var showsControls: Bool {
        isHovering || panel != nil
    }

    var body: some View {
        ZStack(alignment: .top) {
            NotesTextEditor(noteID: note.id, text: contentBinding, fontSize: fontSize)
                .overlay(alignment: .topLeading) { placeholder }
                .overlay(alignment: .bottom) { footer }
                .padding(.top, titleBarHeight)

            header
                .frame(height: titleBarHeight)
        }
        .ignoresSafeArea()
        .frame(minWidth: 400, minHeight: 100)
        .background {
            GlassWindowBackground(tintOpacity: backgroundOpacity)
                .ignoresSafeArea()
        }
        .background {
            WindowChrome(
                onTitleBarHeightChange: { titleBarHeight = $0 },
                onHoverChange: { isHovering = $0 }
            )
            .ignoresSafeArea()
        }
        .animation(.easeOut(duration: 0.18), value: showsControls)
        .navigationTitle(note.title)
        .focusedSceneValue(\.notesCommandHandler, NotesCommandHandler(
            perform: perform,
            showActions: { panel = .actions }
        ))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(note.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .allowsHitTesting(false)

            Spacer(minLength: 8)

            if showsControls {
                actionBar
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .padding(.leading, Self.trafficLightsWidth)
        .padding(.trailing, 10)
    }

    private var actionBar: some View {
        GlassGroup {
            HStack(spacing: 0) {
                ChromeButton(systemImage: "command", help: "Actions (⌘K)") {
                    panel = .actions
                }
                .popover(isPresented: isPresented(.actions), arrowEdge: .bottom) {
                    ActionPanel(store: store, perform: perform)
                }

                ChromeButton(systemImage: "square.stack", help: "Browse Notes (⌘P)") {
                    panel = .notes
                }
                .popover(isPresented: isPresented(.notes), arrowEdge: .bottom) {
                    NotesBrowser(store: store) { id in
                        panel = nil
                        store.select(id)
                    }
                }

                ChromeButton(systemImage: "square.and.pencil", help: "New Note (⌘N)") {
                    perform(.newNote)
                }
            }
            .padding(3)
            .glass(in: Capsule())
        }
        .fixedSize()
    }

    @ViewBuilder
    private var placeholder: some View {
        if note.content.isEmpty {
            Text("Start writing…")
                .font(.system(size: fontSize))
                .foregroundStyle(.secondary)
                .padding(.leading, NotesTextEditor.horizontalInset)
                .padding(.top, NotesTextEditor.topInset)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var footer: some View {
        GlassGroup {
            ZStack {
                if showsControls || showsCopyConfirmation {
                    wordCount
                        .transition(.opacity)
                }

                if showsControls {
                    HStack {
                        Spacer()
                        appearanceButton
                    }
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 32)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private var wordCount: some View {
        HStack(spacing: 6) {
            if showsCopyConfirmation {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.teal)
                    .transition(.scale.combined(with: .opacity))
            }
            Text(showsCopyConfirmation ? "Copied" : wordCountLabel)
                .contentTransition(.numericText())
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .frame(height: 28)
        .glass(in: Capsule())
        .allowsHitTesting(false)
    }

    private var appearanceButton: some View {
        Button {
            panel = .appearance
        } label: {
            Image(systemName: "textformat.size")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .glass(in: Circle(), interactive: true)
        }
        .buttonStyle(.plain)
        .help("Appearance")
        .accessibilityLabel("Appearance")
        .popover(isPresented: isPresented(.appearance), arrowEdge: .top) {
            AppearancePanel(backgroundOpacity: $backgroundOpacity, fontSize: $fontSize)
        }
    }
    private var wordCountLabel: String {
        let count = note.content.split(whereSeparator: \.isWhitespace).count
        return count == 1 ? "1 word" : "\(count) words"
    }

    private var contentBinding: Binding<String> {
        Binding(
            get: { store.selectedNote.content },
            set: { store.updateSelectedContent($0) }
        )
    }

    private func isPresented(_ target: NotesPanel) -> Binding<Bool> {
        Binding(
            get: { panel == target },
            set: { isShown in
                if !isShown, panel == target { panel = nil }
            }
        )
    }

    private func perform(_ action: NoteAction) {
        panel = nil
        switch action {
        case .newNote:
            store.createNote()
        case .browseNotes:
            Task {
                try? await Task.sleep(for: .milliseconds(150))
                panel = .notes
            }
        case .copyNote:
            note.copyToPasteboard()
            confirmCopy()
        case .deleteNote:
            store.deleteNote(note.id)
        case .restoreLastDeleted:
            store.restoreLastDeleted()
        }
    }

    private func confirmCopy() {
        withAnimation(.easeOut(duration: 0.15)) { showsCopyConfirmation = true }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeOut(duration: 0.25)) { showsCopyConfirmation = false }
        }
    }
}

private extension View {
    @ViewBuilder
    func glass(in shape: some Shape, interactive: Bool = false) -> some View {
        if #available(macOS 26, *) {
            glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
                .overlay(shape.stroke(.separator, lineWidth: 0.5))
        }
    }
}

private struct ChromeButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 30, height: 24)
                .background {
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(isHovering ? 0.08 : 0))
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

/// Lets neighbouring glass shapes blend into each other on macOS 26+.
private struct GlassGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: 12) { content }
        } else {
            content
        }
    }
}

#Preview {
    NotesView(store: NotesStore())
        .frame(width: 420, height: 480)
}
