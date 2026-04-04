import Foundation
import Cocoa

/// Controls how the hotkey window behaves across macOS Spaces.
/// Ported from ghostty's QuickTerminalSpaceBehavior.
enum HotkeyWindowSpaceBehavior: String, CaseIterable, Codable {
    /// The hotkey window remains on the space where it was last closed.
    case remain

    /// The hotkey window moves to the active space when shown.
    case move

    var collectionBehavior: NSWindow.CollectionBehavior {
        let commonBehavior: [NSWindow.CollectionBehavior] = [
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
        switch self {
        case .move:
            return NSWindow.CollectionBehavior([.canJoinAllSpaces] + commonBehavior)
        case .remain:
            return NSWindow.CollectionBehavior([.moveToActiveSpace] + commonBehavior)
        }
    }
}
