import SwiftUI

struct NotesView: View {
    let store: NotesStore

    @State private var panel: NotesPanel?
    @State private var notesListedAt = Date()
    @State private var showsCopyConfirmation = false
    @State private var isHovering = false
    @State private var isWorkspaceHovering = false
    @State private var isFormatBarPinned = false
    @State private var titleBarHeight: CGFloat = 40
    @State private var formatController = RichTextController()
    @AppStorage("fontSize") private var fontSize: Double = 16
    @AppStorage("backgroundOpacity") private var backgroundOpacity: Double = 0.75
    @AppStorage(Theme.accentPaletteKey) private var accentPalette: AccentPalette = Theme.defaultAccentPalette
    @AppStorage(EditorSettings.fontFamilyKey) private var fontFamily: EditorFontFamily = .system
    @AppStorage(EditorSettings.spellCheckingKey)
    private var checksSpelling = EditorSettings.checksSpellingDefault
    @AppStorage(EditorSettings.spellingCorrectionKey)
    private var correctsSpelling = EditorSettings.correctsSpellingDefault
    @AppStorage(EditorSettings.smartQuotesKey)
    private var usesSmartQuotes = EditorSettings.smartQuotesDefault
    @AppStorage(EditorSettings.smartDashesKey)
    private var usesSmartDashes = EditorSettings.smartDashesDefault
    @AppStorage(EditorSettings.textReplacementKey)
    private var usesTextReplacement = EditorSettings.textReplacementDefault
    @AppStorage(EditorSettings.linkDetectionKey)
    private var detectsLinks = EditorSettings.detectsLinksDefault
    @AppStorage(EditorSettings.formatBarOnSelectionKey)
    private var showsFormatBarOnSelection = EditorSettings.showsFormatBarOnSelectionDefault

    /// Clears the traffic lights on the leading edge of the title bar.
    private static let trafficLightsWidth: CGFloat = 86

    private var note: Note { store.selectedNote }

    private var accent: Color { accentPalette.color }

    /// Controls stay visible while one of their popovers is open so it keeps its anchor.
    private var showsControls: Bool {
        isHovering || panel != nil
    }

    /// The formatting bar shows while text is selected (when enabled) or when
    /// pinned open from the letter button.
    private var showsFormatBar: Bool {
        isFormatBarPinned || (formatController.hasSelection && showsFormatBarOnSelection)
    }

    private var editorPreferences: EditorPreferences {
        EditorPreferences(
            fontFamily: fontFamily,
            checksSpelling: checksSpelling,
            correctsSpelling: correctsSpelling,
            usesSmartQuotes: usesSmartQuotes,
            usesSmartDashes: usesSmartDashes,
            usesTextReplacement: usesTextReplacement,
            detectsLinks: detectsLinks,
            showsFormatBarOnSelection: showsFormatBarOnSelection
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            NotesTextEditor(
                noteID: note.id,
                text: note.content,
                richTextData: note.richTextData,
                fontSize: fontSize,
                preferences: editorPreferences,
                caretColor: accent,
                controller: formatController,
                onChange: { store.updateSelectedContent($0, richTextData: $1) },
                onEscape: dismissFormatBarIfNeeded
            )
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
        .background {
            WindowSizeRecorder()
                .ignoresSafeArea()
        }
        .animation(.easeOut(duration: 0.18), value: showsControls)
        .animation(.easeOut(duration: 0.18), value: showsFormatBar)
        .navigationTitle(note.title)
        .focusedSceneValue(\.notesCommandHandler, NotesCommandHandler(
            perform: perform,
            showActions: { panel = .actions }
        ))
        .focusedSceneValue(\.richTextController, formatController)
        .environment(\.themeAccent, accent)
    }

    private var header: some View {
        HStack(spacing: 8) {
            workspaceSwitcher

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

    private var workspaceSwitcher: some View {
        Button {
            panel = .workspaces
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(accent)
                Text(store.activeWorkspace.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isWorkspaceHovering ? -180 : 0))
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .frame(maxWidth: 170)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(isWorkspaceHovering ? 0.12 : 0.07))
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PointerButtonStyle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.18)) { isWorkspaceHovering = hovering }
        }
        .help("Workspaces (⇧⌘O)")
        .accessibilityLabel("Workspaces, \(store.activeWorkspace.name)")
        .popover(isPresented: isPresented(.workspaces), arrowEdge: .bottom) {
            WorkspacesPanel(store: store) {
                panel = nil
            }
        }
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
                    showNotes()
                }
                .popover(isPresented: isPresented(.notes), arrowEdge: .bottom) {
                    NotesBrowser(store: store, listedAt: notesListedAt) { id in
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
        if note.isEmpty {
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
                if showsFormatBar {
                    FormatToolbar(
                        controller: formatController,
                        backgroundOpacity: $backgroundOpacity,
                        fontSize: $fontSize,
                        onDismiss: dismissFormatBar
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    if showsControls || showsCopyConfirmation {
                        wordCount
                            .transition(.opacity)
                    }

                    if showsControls {
                        HStack {
                            Spacer()
                            textOptionsButton
                        }
                        .transition(.opacity)
                    }
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

    private var textOptionsButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { isFormatBarPinned = true }
        } label: {
            Image(systemName: "textformat")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .glass(in: Circle(), interactive: true)
        }
        .buttonStyle(PointerButtonStyle())
        .help("Text Options")
        .accessibilityLabel("Text Options")
    }

    private func dismissFormatBar() {
        isFormatBarPinned = false
        formatController.dismiss()
    }

    /// Escape clears the selection and unpins the bar, but only while it is shown
    /// so the text view keeps its default Escape behavior otherwise.
    private func dismissFormatBarIfNeeded() -> Bool {
        guard showsFormatBar else { return false }
        dismissFormatBar()
        return true
    }

    private var wordCountLabel: String {
        let count = note.content.split(whereSeparator: \.isWhitespace).count
        return count == 1 ? "1 word" : "\(count) words"
    }

    private func showNotes() {
        notesListedAt = Date()
        panel = .notes
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
        case .switchWorkspace:
            Task {
                try? await Task.sleep(for: .milliseconds(150))
                panel = .workspaces
            }
        case .browseNotes:
            Task {
                try? await Task.sleep(for: .milliseconds(150))
                showNotes()
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

    @Environment(\.themeAccent) private var accent
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isHovering ? accent : .primary)
                .frame(width: 30, height: 24)
                .background {
                    Capsule(style: .continuous)
                        .fill(isHovering ? accent.opacity(0.18) : .clear)
                }
                .contentShape(Capsule())
        }
        .buttonStyle(PointerButtonStyle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) { isHovering = hovering }
        }
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
