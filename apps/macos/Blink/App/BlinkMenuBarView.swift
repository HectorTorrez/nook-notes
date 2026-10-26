import AppKit
import SwiftUI

struct BlinkMenuBarView: View {
    let store: NotesStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Show Blink") {
            showWindow()
        }

        Button("New Note") {
            showWindow()
            store.createNote()
        }

        Divider()

        SettingsLink {
            Text("Settings…")
        }

        Divider()

        Button("Quit Blink") {
            NSApp.terminate(nil)
        }
    }

    private func showWindow() {
        openWindow(id: "main")
        AppWindow.activate()
    }
}
