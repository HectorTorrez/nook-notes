import SwiftUI

@main
struct BlinkApp: App {
    @State private var store = NotesStore()

    var body: some Scene {
        Window("Blink", id: "main") {
            NotesView(store: store)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 520, height: 360)
        .windowResizability(.contentMinSize)
        .commands {
            NoteCommands(store: store)
        }
    }
}
