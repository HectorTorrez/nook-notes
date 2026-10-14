import AppKit
import SwiftUI

/// Records the main window's size on every resize so the next launch can reopen at the same size.
enum WindowSize {
    static let widthKey = "mainWindowWidth"
    static let heightKey = "mainWindowHeight"
    static let defaultWidth: Double = 520
    static let defaultHeight: Double = 360

    /// The size to open at, restored from the last session when one was recorded.
    static var restored: CGSize {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: widthKey) != nil,
              defaults.object(forKey: heightKey) != nil else {
            return CGSize(width: defaultWidth, height: defaultHeight)
        }
        return CGSize(width: defaults.double(forKey: widthKey), height: defaults.double(forKey: heightKey))
    }
}

struct WindowSizeRecorder: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowSizeView { WindowSizeView() }

    func updateNSView(_ nsView: WindowSizeView, context: Context) {}
}

final class WindowSizeView: NSView {
    private var resizeObserver: NSObjectProtocol?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil, let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
            self.resizeObserver = nil
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        if let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
            self.resizeObserver = nil
        }

        guard let window else { return }

        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let window = self.window else { return }
                self.recordSize(of: window)
            }
        }
    }

    private func recordSize(of window: NSWindow) {
        let size = window.frame.size
        let defaults = UserDefaults.standard
        defaults.set(Double(size.width), forKey: WindowSize.widthKey)
        defaults.set(Double(size.height), forKey: WindowSize.heightKey)
    }
}
