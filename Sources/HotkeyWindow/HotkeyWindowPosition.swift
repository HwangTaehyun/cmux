import Cocoa

/// Position of the hotkey window on screen.
/// Ported from ghostty's QuickTerminalPosition.
enum HotkeyWindowPosition: String, CaseIterable, Codable {
    case top
    case bottom
    case left
    case right
    case center

    /// Set the loaded state for a window. Called when the window is first loaded.
    func setLoaded(_ window: NSWindow, size: HotkeyWindowSize) {
        guard let screen = window.screen ?? NSScreen.main else { return }
        window.setFrame(.init(
            origin: window.frame.origin,
            size: size.calculate(position: self, screenDimensions: screen.visibleFrame.size)
        ), display: false)
    }

    /// Set the initial state for a window NOT yet into position (before animating in or after animating out).
    func setInitial(
        in window: NSWindow,
        on screen: NSScreen,
        size: HotkeyWindowSize,
        closedFrame: NSRect? = nil
    ) {
        window.alphaValue = 0
        window.setFrame(.init(
            origin: initialOrigin(for: window, on: screen),
            size: closedFrame?.size ?? configuredFrameSize(on: screen, size: size)
        ), display: false)
    }

    /// Set the final state for a window in this position.
    func setFinal(
        in window: NSWindow,
        on screen: NSScreen,
        size: HotkeyWindowSize,
        closedFrame: NSRect? = nil
    ) {
        window.alphaValue = 1
        window.setFrame(.init(
            origin: finalOrigin(for: window, on: screen),
            size: closedFrame?.size ?? configuredFrameSize(on: screen, size: size)
        ), display: true)
    }

    /// Get the configured frame size for initial positioning and animations.
    func configuredFrameSize(on screen: NSScreen, size: HotkeyWindowSize) -> NSSize {
        size.calculate(position: self, screenDimensions: screen.visibleFrame.size)
    }

    /// The initial point origin for this position (off-screen).
    func initialOrigin(for window: NSWindow, on screen: NSScreen) -> CGPoint {
        switch self {
        case .top:
            return .init(
                x: round(screen.visibleFrame.origin.x + (screen.visibleFrame.width - window.frame.width) / 2),
                y: screen.visibleFrame.maxY)
        case .bottom:
            return .init(
                x: round(screen.visibleFrame.origin.x + (screen.visibleFrame.width - window.frame.width) / 2),
                y: -window.frame.height)
        case .left:
            return .init(
                x: screen.visibleFrame.minX - window.frame.width,
                y: round(screen.visibleFrame.origin.y + (screen.visibleFrame.height - window.frame.height) / 2))
        case .right:
            return .init(
                x: screen.visibleFrame.maxX,
                y: round(screen.visibleFrame.origin.y + (screen.visibleFrame.height - window.frame.height) / 2))
        case .center:
            return .init(
                x: round(screen.visibleFrame.origin.x + (screen.visibleFrame.width - window.frame.width) / 2),
                y: screen.visibleFrame.height - window.frame.width)
        }
    }

    /// The final point origin for this position (on-screen).
    func finalOrigin(for window: NSWindow, on screen: NSScreen) -> CGPoint {
        switch self {
        case .top:
            return .init(
                x: round(screen.visibleFrame.origin.x + (screen.visibleFrame.width - window.frame.width) / 2),
                y: screen.visibleFrame.maxY - window.frame.height)
        case .bottom:
            return .init(
                x: round(screen.visibleFrame.origin.x + (screen.visibleFrame.width - window.frame.width) / 2),
                y: screen.visibleFrame.minY)
        case .left:
            return .init(
                x: screen.visibleFrame.minX,
                y: round(screen.visibleFrame.origin.y + (screen.visibleFrame.height - window.frame.height) / 2))
        case .right:
            return .init(
                x: screen.visibleFrame.maxX - window.frame.width,
                y: round(screen.visibleFrame.origin.y + (screen.visibleFrame.height - window.frame.height) / 2))
        case .center:
            return .init(
                x: round(screen.visibleFrame.origin.x + (screen.visibleFrame.width - window.frame.width) / 2),
                y: round(screen.visibleFrame.origin.y + (screen.visibleFrame.height - window.frame.height) / 2))
        }
    }

    /// Whether this position conflicts with the dock.
    func conflictsWithDock(on screen: NSScreen) -> Bool {
        guard screen.hasDock else { return false }
        guard let orientation = Dock.orientation else { return false }
        return switch orientation {
        case .top: self == .top || self == .left || self == .right
        case .bottom: self == .bottom || self == .left || self == .right
        case .left: self == .top || self == .bottom
        case .right: self == .top || self == .bottom
        }
    }

    /// Calculate the centered origin for a window after manual resizing.
    func centeredOrigin(for window: NSWindow, on screen: NSScreen) -> CGPoint {
        switch self {
        case .top, .bottom:
            return CGPoint(
                x: round(screen.visibleFrame.origin.x + (screen.visibleFrame.width - window.frame.width) / 2),
                y: window.frame.origin.y)
        case .center:
            return CGPoint(
                x: round(screen.visibleFrame.origin.x + (screen.visibleFrame.width - window.frame.width) / 2),
                y: round(screen.visibleFrame.origin.y + (screen.visibleFrame.height - window.frame.height) / 2))
        case .left, .right:
            return window.frame.origin
        }
    }

    /// Calculate the vertically centered origin for side-positioned windows.
    func verticallyCenteredOrigin(for window: NSWindow, on screen: NSScreen) -> CGPoint {
        switch self {
        case .left, .right:
            return CGPoint(
                x: window.frame.origin.x,
                y: round(screen.visibleFrame.origin.y + (screen.visibleFrame.height - window.frame.height) / 2))
        case .top, .bottom, .center:
            return window.frame.origin
        }
    }
}
