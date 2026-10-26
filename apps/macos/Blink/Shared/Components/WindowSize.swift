import CoreGraphics
import Foundation

/// First-launch size for the main window. After that, AppKit's frame autosave
/// restores the exact size and position.
enum WindowSize {
    static let widthKey = "mainWindowWidth"
    static let heightKey = "mainWindowHeight"
    static let defaultWidth: Double = 520
    static let defaultHeight: Double = 360

    /// The size to open at, restored from the last pre-autosave session when
    /// one was recorded.
    static var restored: CGSize {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: widthKey) != nil,
              defaults.object(forKey: heightKey) != nil else {
            return CGSize(width: defaultWidth, height: defaultHeight)
        }
        return CGSize(
            width: defaults.double(forKey: widthKey),
            height: defaults.double(forKey: heightKey)
        )
    }
}
