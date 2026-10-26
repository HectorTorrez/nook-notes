import AppKit

enum AccessibilityAnnouncement {
    static func post(_ message: String) {
        guard let element = NSApp.mainWindow ?? NSApp.keyWindow else { return }
        NSAccessibility.post(
            element: element,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
    }
}
