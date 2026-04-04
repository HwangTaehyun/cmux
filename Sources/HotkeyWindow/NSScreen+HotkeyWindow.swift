import Cocoa

/// NSScreen extensions for hotkey window positioning.
/// Ported from ghostty's NSScreen+Extension.
extension NSScreen {
    /// The unique CoreGraphics display ID for this screen.
    var displayID: UInt32? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32
    }

    /// The stable UUID for this display, suitable for tracking across reconnects.
    var displayUUID: UUID? {
        guard let displayID = displayID else { return nil }
        guard let cfuuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else { return nil }
        let uuidString = CFUUIDCreateString(nil, cfuuid) as String? ?? ""
        return UUID(uuidString: uuidString)
    }

    /// Returns true if the given screen has a visible (always-on) dock.
    var hasDock: Bool {
        if let dockAutohide = UserDefaults.standard.persistentDomain(forName: "com.apple.dock")?["autohide"] as? Bool {
            if dockAutohide { return false }
        }

        // If visible width is less than full width, dock is on the side
        if visibleFrame.width < frame.width {
            return true
        }

        // Check if visible height is less than full height minus menu/notch
        let menuHeight = NSApp.mainMenu?.menuBarHeight ?? 0
        let notchInset: CGFloat = safeAreaInsets.top
        let boundaryAreaPadding = 5.0

        return visibleFrame.height < (frame.height - max(menuHeight, notchInset) - boundaryAreaPadding)
    }

    /// Returns true if the screen has a visible notch.
    var hasNotch: Bool {
        safeAreaInsets.top > 0
    }
}
