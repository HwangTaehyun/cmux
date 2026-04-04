import Cocoa

/// NSScreen extensions for hotkey window positioning.
/// Ported from ghostty's NSScreen+Extension.
/// Note: `displayID` is already declared in GhosttyTerminalView.swift (private extension).
extension NSScreen {
    /// The stable UUID for this display, suitable for tracking across reconnects.
    var displayUUID: UUID? {
        guard let did = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 else { return nil }
        guard let cfuuid = CGDisplayCreateUUIDFromDisplayID(did)?.takeRetainedValue() else { return nil }
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
