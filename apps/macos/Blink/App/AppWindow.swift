import AppKit

/// Small bridge for showing, hiding, and finding the single main window from
/// the menu bar extra and the global hotkey.
@MainActor
enum AppWindow {
    static weak var storedWindow: NSWindow?

    static var main: NSWindow? {
        if let storedWindow {
            return storedWindow
        }
        return NSApp.windows.first { $0.identifier?.rawValue == "main" }
            ?? NSApp.windows.first { $0.canBecomeMain && !($0 is NSPanel) }
    }

    static func show() {
        activate()
        guard let window = main else { return }
        window.makeKeyAndOrderFront(nil)
    }

    static func toggle() {
        if NSApp.isActive,
           let window = main,
           window.isVisible,
           window.isKeyWindow {
            window.orderOut(nil)
        } else {
            show()
        }
    }

    static func activate() {
        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
