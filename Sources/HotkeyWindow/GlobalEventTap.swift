import Cocoa
import CoreGraphics
import OSLog
import Bonsplit

/// Manages a system-wide CGEvent tap for global keyboard shortcut interception.
/// Used to detect the hotkey window toggle shortcut even when cmux is not focused.
///
/// Requires macOS Accessibility permission (System Settings > Privacy & Security > Accessibility).
/// If permission is not granted, the tap creation fails silently and retries on a 1-second timer.
///
/// Adapted from ghostty's GlobalEventTap.
class GlobalEventTap {
    static let shared = GlobalEventTap()

    fileprivate static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "cmux",
        category: "GlobalEventTap"
    )

    /// The event tap mach port. Non-nil when the tap is active.
    fileprivate var eventTap: CFMachPort?

    /// Timer to retry enabling the tap if Accessibility permission is missing.
    private var enableTimer: Timer?

    private init() {}

    deinit { disable() }

    /// Enable the global event tap. Safe to call if already enabled.
    /// If permission is missing, starts a retry timer.
    func enable() {
        if eventTap != nil { return }

        if let enableTimer {
            enableTimer.invalidate()
        }

        if tryEnable() { return }

        // Permission not granted — retry every second
        enableTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            _ = self.tryEnable()
        }
    }

    /// Disable the global event tap. Safe to call if already disabled.
    func disable() {
        if let enableTimer {
            enableTimer.invalidate()
            self.enableTimer = nil
        }
        if let eventTap {
            Self.logger.debug("invalidating event tap mach port")
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
    }

    private func tryEnable() -> Bool {
        let eventMask = [CGEventType.keyDown]
            .reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }

        let trusted = AXIsProcessTrusted()
        globalTapLog("[GlobalTap] tryEnable AXIsProcessTrusted=\(trusted)")
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: globalEventTapCallback,
            userInfo: nil
        ) else {
            globalTapLog("[GlobalTap] FAILED to create tap, trusted=\(trusted)")
            return false
        }

        self.eventTap = eventTap

        if let enableTimer {
            enableTimer.invalidate()
            self.enableTimer = nil
        }

        CFRunLoopAddSource(
            CFRunLoopGetMain(),
            CFMachPortCreateRunLoopSource(nil, eventTap, 0),
            .commonModes
        )

        globalTapLog("[GlobalTap] SUCCESS - event tap enabled")
        Self.logger.info("global event tap enabled for hotkey window")
        return true
    }
}

// File-based logger for the C callback (can't use dlog from C context)
private func globalTapLog(_ msg: String) {
    let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    let line = "[\(ts)] \(msg)\n"
    let path = "/tmp/cmux-globaltap-debug.log"
    if let handle = FileHandle(forWritingAtPath: path) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        handle.closeFile()
    } else {
        FileManager.default.createFile(atPath: path, contents: line.data(using: .utf8))
    }
}

// MARK: - CGEvent Callback

/// C-compatible callback for the global event tap.
/// Checks if the key event matches the hotkey window toggle shortcut.
private func globalEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    cgEvent: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    let result = Unmanaged.passUnretained(cgEvent)

    // Re-enable tap if disabled by system timeout
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let machPort = GlobalEventTap.shared.eventTap {
            GlobalEventTap.logger.warning("event tap was disabled by system, re-enabling")
            CGEvent.tapEnable(tap: machPort, enable: true)
        }
        return result
    }

    guard type == .keyDown else { return result }

    // Skip auto-repeat events
    if cgEvent.getIntegerValueField(.keyboardEventAutorepeat) != 0 {
        return result
    }

    // Create NSEvent for matching
    guard let event: NSEvent = .init(cgEvent: cgEvent) else { return result }

    // Log all Cmd+Shift key events for debugging
    let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
    if mods.contains(.command) && mods.contains(.shift) {
        globalTapLog("[GlobalTap] CMD+SHIFT key=\(event.keyCode) chars=\(event.charactersIgnoringModifiers ?? "nil")")
    }

    // Get the configured hotkey shortcut
    let shortcut = KeyboardShortcutSettings.shortcut(for: .toggleHotkeyWindow)

    // Match the shortcut
    if globalMatchShortcut(event: event, shortcut: shortcut) {
        globalTapLog("[GlobalTap] MATCHED! dispatching toggle, isActive=\(NSApp.isActive)")
        DispatchQueue.main.async {
            guard let controller = AppDelegate.shared?.hotkeyWindowController else {
                globalTapLog("[GlobalTap] ERROR: no controller, shared=\(AppDelegate.shared != nil)")
                return
            }
            controller.toggle()
        }
        return nil // Consume the event
    }

    return result
}

// MARK: - Standalone Shortcut Matcher

/// Simplified shortcut matcher for the global event tap.
/// Handles modifier comparison and key matching including keyboard layout fallback.
private func globalMatchShortcut(event: NSEvent, shortcut: StoredShortcut) -> Bool {
    // Match modifier flags
    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        .subtracting([.numericPad, .function, .capsLock])
    guard flags == shortcut.modifierFlags else { return false }

    let shortcutKey = shortcut.key.lowercased()

    // Special key matching
    if shortcutKey == "\r" {
        return event.keyCode == 36 || event.keyCode == 76
    }

    // Try direct character matching
    if let eventChars = event.charactersIgnoringModifiers?.lowercased(),
       !eventChars.isEmpty,
       eventChars == shortcutKey {
        return true
    }

    // Keyboard layout fallback (for non-Latin input sources like Korean)
    if let layoutChar = KeyboardLayout.character(forKeyCode: event.keyCode, modifierFlags: event.modifierFlags),
       !layoutChar.isEmpty,
       layoutChar.lowercased() == shortcutKey {
        return true
    }

    // ANSI keyCode fallback for command-modified shortcuts
    if flags.contains(.command) || flags.contains(.control) {
        if let expectedKeyCode = globalMatchAnsiKeyCode(for: shortcutKey) {
            return event.keyCode == expectedKeyCode
        }
    }

    return false
}

/// Map a shortcut key string to its ANSI key code.
func globalMatchAnsiKeyCode(for key: String) -> UInt16? {
    switch key {
    case "a": return 0;   case "s": return 1;   case "d": return 2
    case "f": return 3;   case "h": return 4;   case "g": return 5
    case "z": return 6;   case "x": return 7;   case "c": return 8
    case "v": return 9;   case "b": return 11;  case "q": return 12
    case "w": return 13;  case "e": return 14;  case "r": return 15
    case "y": return 16;  case "t": return 17;  case "1": return 18
    case "2": return 19;  case "3": return 20;  case "4": return 21
    case "6": return 22;  case "5": return 23;  case "=": return 24
    case "9": return 25;  case "7": return 26;  case "-": return 27
    case "8": return 28;  case "0": return 29;  case "]": return 30
    case "o": return 31;  case "u": return 32;  case "[": return 33
    case "i": return 34;  case "p": return 35;  case "l": return 37
    case "j": return 38;  case "'": return 39;  case "k": return 40
    case ";": return 41;  case "\\": return 42; case ",": return 43
    case "/": return 44;  case "n": return 45;  case "m": return 46
    case ".": return 47;  case "`": return 50
    default: return nil
    }
}
