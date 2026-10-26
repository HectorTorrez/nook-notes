import AppKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            AppearanceSettingsView()
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
            EditorSettingsView()
                .tabItem { Label("Editor", systemImage: "textformat") }
            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500, height: 400)
    }
}

private struct AppearanceSettingsView: View {
    @AppStorage(Theme.accentPaletteKey) private var accentPalette: AccentPalette = Theme.defaultAccentPalette
    @AppStorage("fontSize") private var fontSize: Double = 16
    @AppStorage("backgroundOpacity") private var backgroundOpacity: Double = 0.75
    @AppStorage("alwaysOnTop") private var alwaysOnTop = true
    @AppStorage(EditorSettings.fontFamilyKey) private var fontFamily: EditorFontFamily = .system
    @State private var launchesAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Section("Accent") {
                AccentSwatches(selection: $accentPalette)
                    .padding(.vertical, 2)
            }

            Section("Text") {
                TextSizeSlider(fontSize: $fontSize)

                Picker("Font", selection: $fontFamily) {
                    ForEach(EditorFontFamily.allCases) { family in
                        Text(family.title).tag(family)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Window") {
                Toggle("Float above other apps", isOn: $alwaysOnTop)
                Toggle("Launch at login", isOn: $launchesAtLogin)
                    .onChange(of: launchesAtLogin) { _, enabled in
                        do {
                            try LaunchAtLogin.set(enabled)
                        } catch {
                            launchesAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
                Text("Global shortcut: ⌃⌥B")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Section("Background") {
                HStack {
                    Text("Opacity")
                    Spacer()
                    Text("\(Int(backgroundOpacity * 100))%")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                Slider(value: $backgroundOpacity, in: 0...1)
                    .controlSize(.small)
                    .accessibilityLabel("Background opacity")
                HStack {
                    Text("Glass")
                    Spacer()
                    Text("Solid")
                }
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct EditorSettingsView: View {
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

    var body: some View {
        Form {
            Section("Spelling") {
                Toggle("Check spelling as you type", isOn: $checksSpelling)
                Toggle("Correct spelling automatically", isOn: $correctsSpelling)
                    .disabled(!checksSpelling)
            }

            Section("Substitutions") {
                Toggle("Smart quotes", isOn: $usesSmartQuotes)
                Toggle("Smart dashes", isOn: $usesSmartDashes)
                Toggle("Text replacement", isOn: $usesTextReplacement)
            }

            Section("Links") {
                Toggle("Detect web links automatically", isOn: $detectsLinks)
            }

            Section("Formatting") {
                Toggle("Show formatting bar when text is selected", isOn: $showsFormatBarOnSelection)
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutSettingsView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.3.0"
    }

    private var notesURL: URL {
        NotesFileStorage.default.url
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text("Blink")
                    .font(.system(size: 20, weight: .semibold))
                Text("Version \(version)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Text("A tiny, glassy, floating notes window for macOS.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                Text("Notes are stored in a single JSON file.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(notesURL.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)

                HStack(spacing: 8) {
                    Button("Reveal in Finder") {
                        revealNotesFile()
                    }
                    Button("Copy Path") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(notesURL.path, forType: .string)
                    }
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func revealNotesFile() {
        if FileManager.default.fileExists(atPath: notesURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([notesURL])
        } else {
            NSWorkspace.shared.open(notesURL.deletingLastPathComponent())
        }
    }
}
