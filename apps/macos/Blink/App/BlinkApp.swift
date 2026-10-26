import SwiftUI

@main
struct BlinkApp: App {
    @State private var store = NotesStore(storage: .default)

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
