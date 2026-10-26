import AppKit
import SwiftUI

@main
struct BlinkApp: App {
    @State private var store = NotesStore(storage: .default)

    init() {
        // XCTest launches Blink as the test host; do not treat it as a second instance.
        guard NSClassFromString("XCTestCase") == nil,
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        let bundleID = Bundle.main.bundleIdentifier ?? "com.hectortorrez.blink"
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        guard !others.isEmpty else { return }

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Blink is already running"
            alert.informativeText = "Only one copy of Blink can use the notes file at a time."
            alert.alertStyle = .warning
            alert.runModal()
            NSApp.terminate(nil)
        }
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

        Settings {
            SettingsView()
        }
    }
}
