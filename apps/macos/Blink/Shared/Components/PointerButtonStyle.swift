import SwiftUI

/// A borderless button that shows the pointing-hand cursor while hovering, so
/// every control in Blink reads as clickable.
struct PointerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .pointerStyle(.link)
    }
}
