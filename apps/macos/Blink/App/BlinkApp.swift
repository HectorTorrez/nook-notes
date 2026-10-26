import AppKit
import SwiftUI

@main
struct BlinkApp: App {
    @State private var store = NotesStore(storage: .default)
    private let hotKey = GlobalHotKey()

    init() {
        // XCTest launches Blink as the test host; do not treat it as a second instance.
        guard NSClassFromString("XCTestCase") == nil,
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        let bundleID = Bundle.main.bundleIdentifier ?? "com.hectortorrez.blink"
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }

        if !others.isEmpty {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Blink is already running"
                alert.informativeText = "Only one copy of Blink can use the notes file at a time."
                alert.alertStyle = .warning
                alert.runModal()
                NSApp.terminate(nil)
            }
            return
        }

        hotKey.action = { AppWindow.toggle() }
        hotKey.register()
    }

    var body: some Scene {
        Window("Blink", id: "main") {
            NotesView(store: store)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(WindowSize.restored)
        .windowResizability(.contentMinSize)
        .commands {
            NoteCommands(store: store)
        }

        MenuBarExtra("Blink", systemImage: "note.text") {
            BlinkMenuBarView(store: store)
        }

        Settings {
            SettingsView()
        }
    }
}
