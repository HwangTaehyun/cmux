import Foundation
import Cocoa

/// Manages cached window state per screen for the hotkey window.
/// Tracks the last closed window frame for each screen using stable display UUIDs.
/// Ported from ghostty's QuickTerminalScreenStateCache.
class HotkeyWindowScreenStateCache {
    typealias Entries = [UUID: DisplayEntry]

    private static let maxSavedScreens = 10
    private static let screenStaleTTL: TimeInterval = 14 * 24 * 60 * 60

    private(set) var stateByDisplay: Entries = [:]

    init(stateByDisplay: Entries = [:]) {
        self.stateByDisplay = stateByDisplay
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onScreensChanged(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Save the window frame for a screen.
    func save(frame: NSRect, for screen: NSScreen) {
        guard let key = screen.displayUUID else { return }
        let entry = DisplayEntry(
            frame: frame,
            screenSize: screen.frame.size,
            scale: screen.backingScaleFactor,
            lastSeen: Date()
        )
        stateByDisplay[key] = entry
        pruneCapacity()
    }

    /// Retrieve the last closed frame for a screen, if valid.
    func frame(for screen: NSScreen) -> NSRect? {
        guard let key = screen.displayUUID, var entry = stateByDisplay[key] else { return nil }

        if !entry.isValid(for: screen) {
            stateByDisplay.removeValue(forKey: key)
            return nil
        }

        entry.lastSeen = Date()
        stateByDisplay[key] = entry
        return entry.frame
    }

    @objc private func onScreensChanged(_ note: Notification) {
        let screens = NSScreen.screens
        let now = Date()
        let currentIDs = Set(screens.compactMap { $0.displayUUID })

        for screen in screens {
            guard let key = screen.displayUUID else { continue }
            if var entry = stateByDisplay[key] {
                if !entry.isValid(for: screen) {
                    stateByDisplay.removeValue(forKey: key)
                } else {
                    entry.screenSize = screen.frame.size
                    entry.lastSeen = now
                    stateByDisplay[key] = entry
                }
            }
        }

        // TTL prune for non-present screens
        stateByDisplay = stateByDisplay.filter { key, entry in
            currentIDs.contains(key) || now.timeIntervalSince(entry.lastSeen) < Self.screenStaleTTL
        }

        pruneCapacity()
    }

    private func pruneCapacity() {
        guard stateByDisplay.count > Self.maxSavedScreens else { return }
        let toRemove = stateByDisplay
            .sorted { $0.value.lastSeen < $1.value.lastSeen }
            .prefix(stateByDisplay.count - Self.maxSavedScreens)
        for (key, _) in toRemove {
            stateByDisplay.removeValue(forKey: key)
        }
    }

    struct DisplayEntry: Codable {
        var frame: NSRect
        var screenSize: CGSize
        var scale: CGFloat
        var lastSeen: Date

        func isValid(for screen: NSScreen) -> Bool {
            guard scale == screen.backingScaleFactor else { return false }
            return screenSize.width <= screen.frame.size.width && screenSize.height <= screen.frame.size.height
        }
    }
}
