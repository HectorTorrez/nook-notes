import AppKit
import SwiftUI

/// Gives the window a compact, transparent title bar with traffic lights only,
/// reports its height, and reports whether the pointer is over the window,
/// even while the app is inactive.
struct WindowChrome: NSViewRepresentable {
    var alwaysOnTop: Bool
    var onTitleBarHeightChange: (CGFloat) -> Void
    var onHoverChange: (Bool) -> Void

    func makeNSView(context: Context) -> WindowChromeView {
        let view = WindowChromeView()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: WindowChromeView, context: Context) {
        view.onTitleBarHeightChange = onTitleBarHeightChange
        view.onHoverChange = onHoverChange
        view.alwaysOnTop = alwaysOnTop
        view.applyLevel()
    }
}

final class WindowChromeView: NSView {
    var alwaysOnTop = true
    var onTitleBarHeightChange: ((CGFloat) -> Void)?
    var onHoverChange: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?
    private var reportedTitleBarHeight: CGFloat = -1

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        // An empty toolbar gives the taller compact title bar, which vertically centers the traffic lights.
        if window.toolbar == nil {
            window.toolbar = NSToolbar(identifier: "Blink.titlebar")
        }
        window.toolbarStyle = .unifiedCompact
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.styleMask.insert(.fullSizeContentView)
        // Keep the note in place when the desktop is clicked ("Show Desktop"),
        // so a click outside the window only changes focus.
        window.collectionBehavior.insert(.stationary)

        window.setFrameAutosaveName("BlinkMainWindow")
        clampToVisibleScreen(window)
        applyLevel()

        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            self.reportTitleBarHeight()
            let location = self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
            self.onHoverChange?(self.bounds.contains(location))
        }
    }

    func applyLevel() {
        window?.level = alwaysOnTop ? .floating : .normal
    }

    private func clampToVisibleScreen(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var frame = window.frame
        frame.origin.x = min(
            max(frame.origin.x, visible.minX),
            max(visible.minX, visible.maxX - frame.width)
        )
        frame.origin.y = min(
            max(frame.origin.y, visible.minY),
            max(visible.minY, visible.maxY - frame.height)
        )
        if frame != window.frame {
            window.setFrame(frame, display: false)
        }
    }

    override func layout() {
        super.layout()
        reportTitleBarHeight()
    }

    private func reportTitleBarHeight() {
        guard let window else { return }
        let height = window.frame.height - window.contentLayoutRect.height
        guard height != reportedTitleBarHeight else { return }
        reportedTitleBarHeight = height
        let callback = onTitleBarHeightChange
        DispatchQueue.main.async { callback?(height) }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChange?(false)
    }
}
