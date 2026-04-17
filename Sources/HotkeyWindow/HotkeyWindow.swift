import Cocoa

/// Custom NSPanel for the hotkey window.
/// - Borderless (no title bar)
/// - Non-activating (doesn't steal app activation)
/// - Can become key/main for keyboard input
///
/// Ported from ghostty's QuickTerminalWindow.
class HotkeyWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Workaround for older macOS versions where SwiftUI corrupts the frame on first contentView set.
    var initialFrame: NSRect?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Remove title bar for a clean, borderless look
        styleMask.remove(.titled)

        // Accessibility
        identifier = .init(rawValue: "com.cmuxterm.hotkeyWindow")
        setAccessibilitySubrole(.floatingWindow)

        // Window properties
        isRestorable = false
        hasShadow = true
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        // Use cached initial frame if available (workaround for SwiftUI frame corruption)
        super.setFrame(initialFrame ?? frameRect, display: flag)
    }
}
