import AppKit
import SwiftUI

/// Replaces the window's opaque background with frosted glass under a gray tint.
/// `tintOpacity` runs from 0 (all glass) to 1 (solid gray).
struct GlassWindowBackground: NSViewRepresentable {
    var tintOpacity: Double
    var cornerRadius: CGFloat = 16

    func makeNSView(context: Context) -> GlassHostView {
        let host = GlassHostView()
        let glass: NSView
        if #available(macOS 26, *) {
            let view = NSGlassEffectView()
            view.style = .regular
            view.cornerRadius = cornerRadius
            glass = view
        } else {
            let view = NSVisualEffectView()
            view.material = .hudWindow
            view.blendingMode = .behindWindow
            view.state = .active
            glass = view
        }
        host.addFilling(glass)
        host.addFilling(host.tint)
        host.tint.opacity = tintOpacity
        return host
    }

    func updateNSView(_ host: GlassHostView, context: Context) {
        host.tint.opacity = tintOpacity
    }
}

final class GlassHostView: NSView {
    let tint = TintView()

    func addFilling(_ view: NSView) {
        view.frame = bounds
        view.autoresizingMask = [.width, .height]
        addSubview(view)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.invalidateShadow()
    }
}

final class TintView: NSView {
    private static let gray = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 0.14, alpha: 1)
            : NSColor(white: 0.93, alpha: 1)
    }

    var opacity: Double = 0 {
        didSet { needsDisplay = true }
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = Self.gray.withAlphaComponent(opacity).cgColor
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
