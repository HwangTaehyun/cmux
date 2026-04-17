import Cocoa

/// Which screen the hotkey window should appear on.
/// Ported from ghostty's QuickTerminalScreen.
enum HotkeyWindowScreen: String, CaseIterable, Codable {
    /// The screen with keyboard focus (NSScreen.main).
    case main

    /// The screen where the mouse cursor is.
    case mouse

    /// The primary display (with the menu bar).
    case menuBar

    var screen: NSScreen? {
        switch self {
        case .main:
            return NSScreen.main
        case .mouse:
            let mouseLoc = NSEvent.mouseLocation
            return NSScreen.screens.first(where: { $0.frame.contains(mouseLoc) })
        case .menuBar:
            return NSScreen.screens.first
        }
    }
}
