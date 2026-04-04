import Foundation
import Cocoa
import SwiftUI
import OSLog
import Bonsplit

/// Controller for the hotkey window — a dropdown/floating terminal that toggles
/// with a global keyboard shortcut.
///
/// Adapted from ghostty's QuickTerminalController for cmux's SwiftUI+AppKit architecture.
@MainActor
final class HotkeyWindowController: NSObject, NSWindowDelegate {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "cmux",
        category: "HotkeyWindow"
    )

    // MARK: - State

    /// Whether the hotkey window is currently visible.
    private(set) var visible: Bool = false

    /// The hotkey window panel.
    private var window: HotkeyWindow?

    /// The window ID used to register with AppDelegate.
    private var windowId: UUID?

    /// Timestamp of the last animateIn call (grace period for floating mode).
    private var lastAnimateInTime: Date?

    /// The previously running application when the terminal is shown.
    private var previousApp: NSRunningApplication?

    /// The active space when the hotkey window was last shown.
    private var previousActiveSpace: CGSSpace?

    /// Per-screen window frame cache.
    private let screenStateCache = HotkeyWindowScreenStateCache()

    /// Dock hide state.
    private var hiddenDock: HiddenDock?

    /// Tracks manual resize handling to prevent recursion.
    private var isHandlingResize: Bool = false

    // MARK: - Init

    override init() {
        super.init()
    }

    deinit {
        hiddenDock = nil
    }

    // MARK: - Toggle

    func toggle() {
        Self.logger.info("toggle() visible=\(self.visible)")
        if visible {
            animateOut()
        } else {
            animateIn()
        }
    }

    // MARK: - Animate In

    private func animateIn() {
        guard !visible else {
            #if DEBUG
            DebugEventLog.shared.log("hotkeyWindow.animateIn SKIP already visible")
            #endif
            return
        }
        #if DEBUG
        DebugEventLog.shared.log("hotkeyWindow.animateIn starting window=\(window != nil)")
        #endif
        visible = true
        lastAnimateInTime = Date()

        // Store previously focused app
        if !NSApp.isActive {
            if let previousApp = NSWorkspace.shared.frontmostApplication,
               previousApp.bundleIdentifier != Bundle.main.bundleIdentifier {
                self.previousApp = previousApp
            }
        }

        previousActiveSpace = CGSSpace.active()

        // Create the window lazily on first show
        if window == nil {
            createWindow()
        }

        guard let window = self.window else {
            #if DEBUG
            DebugEventLog.shared.log("hotkeyWindow.animateIn FAIL no window after createWindow")
            #endif
            return
        }

        let settings = self.currentSettings()
        guard let screen = settings.screen.screen else {
            #if DEBUG
            DebugEventLog.shared.log("hotkeyWindow.animateIn FAIL no screen")
            #endif
            return
        }
        #if DEBUG
        DebugEventLog.shared.log("hotkeyWindow.animateIn screen=\(screen.frame) position=\(settings.position) size=\(settings.size.primary)")
        #endif

        let closedFrame = screenStateCache.frame(for: screen)

        // Always float above other apps and join all spaces
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        // Full screen on the target screen
        window.alphaValue = 1
        window.setFrame(screen.frame, display: true)

        // Screen-saver level to appear above fullscreen apps
        window.level = .screenSaver

        // Show and focus without activating the app (NSPanel handles keyboard input)
        window.makeKeyAndOrderFront(nil)

#if DEBUG
        DebugEventLog.shared.log("hotkeyWindow.animateIn SHOWN frame=\(window.frame) isVisible=\(window.isVisible) isKey=\(window.isKeyWindow)")
#endif
    }

    // MARK: - Animate Out

    func animateOut() {
        guard visible else { return }
        guard let window = self.window else { return }
#if DEBUG
        DebugEventLog.shared.log("hotkeyWindow.animateOut starting")
#endif
        visible = false

        let settings = currentSettings()

        // Save window frame
        if window.frame.width > 0 && window.frame.height > 0, let screen = window.screen {
            screenStateCache.save(frame: window.frame, for: screen)
        }

        // Restore dock
        hiddenDock = nil

        // If window isn't on active space, just hide immediately
        if !window.isOnActiveSpace {
            previousApp = nil
            window.orderOut(self)
            return
        }

        guard let screen = window.screen ?? NSScreen.main else { return }

        // Restore previous app focus
        if let previousApp = self.previousApp {
            self.previousApp = nil
            if !previousApp.isTerminated {
                _ = previousApp.activate(options: [])
            }
        }

        window.level = .popUpMenu

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = settings.animationDuration
            context.timingFunction = .init(name: .easeIn)
            settings.position.setInitial(
                in: window.animator(),
                on: screen,
                size: settings.size,
                closedFrame: window.frame)
        }, completionHandler: {
            window.orderOut(self)
        })
    }

    // MARK: - NSWindowDelegate

    func windowDidBecomeKey(_ notification: Notification) {
        guard visible else { return }
        hiddenDock?.hide()
    }

    func windowDidResignKey(_ notification: Notification) {
        guard visible else { return }
        guard window?.attachedSheet == nil else { return }

        let settings = currentSettings()

        // Grace period: ignore resignKey within 1s of showing.
        // The window may lose focus immediately after appearing because
        // the main window or another app reclaims focus before the animation completes.
        if let animateTime = lastAnimateInTime,
           Date().timeIntervalSince(animateTime) < 1.0 {
#if DEBUG
            DebugEventLog.shared.log("hotkeyWindow.windowDidResignKey grace period, ignoring")
#endif
            return
        }

        // If our app is still active, we're switching to another cmux window
        if NSApp.isActive {
            self.previousApp = nil
        }

        // Always restore dock on focus loss
        hiddenDock?.restore()

        if settings.autoHide {
            switch settings.spaceBehavior {
            case .remain:
                animateOut()
            case .move:
                let currentActiveSpace = CGSSpace.active()
                if previousActiveSpace == currentActiveSpace {
                    animateOut()
                } else {
                    DispatchQueue.main.async { [self] in
                        window?.makeKeyAndOrderFront(nil)
                    }
                    previousActiveSpace = currentActiveSpace
                }
            }
        }
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window == self.window,
              visible,
              !isHandlingResize else { return }
        guard let screen = window.screen ?? NSScreen.main else { return }

        isHandlingResize = true
        defer { isHandlingResize = false }

        let position = HotkeyWindowSettings.position
        switch position {
        case .top, .bottom, .center:
            let newOrigin = position.centeredOrigin(for: window, on: screen)
            window.setFrameOrigin(newOrigin)
        case .left, .right:
            let newOrigin = position.verticallyCenteredOrigin(for: window, on: screen)
            window.setFrameOrigin(newOrigin)
        }
    }

    // MARK: - Window Creation

    private func createWindow() {
        guard let appDelegate = AppDelegate.shared else { return }

        let windowId = UUID()
        self.windowId = windowId

        let tabManager = TabManager()
        let sidebarState = SidebarState(isVisible: true)
        let sidebarSelectionState = SidebarSelectionState()
        let notificationStore = TerminalNotificationStore.shared
        let cmuxConfigStore = CmuxConfigStore()
        cmuxConfigStore.wireDirectoryTracking(tabManager: tabManager)
        cmuxConfigStore.loadAll()

        let root = ContentView(updateViewModel: appDelegate.updateViewModel, windowId: windowId)
            .environmentObject(tabManager)
            .environmentObject(notificationStore)
            .environmentObject(sidebarState)
            .environmentObject(sidebarSelectionState)
            .environmentObject(cmuxConfigStore)

        let settings = currentSettings()
        let initialSize = settings.size.calculate(
            position: settings.position,
            screenDimensions: (settings.screen.screen ?? NSScreen.main)?.visibleFrame.size ?? CGSize(width: 800, height: 600)
        )

        let panel = HotkeyWindow(contentRect: NSRect(origin: .zero, size: initialSize))
        panel.delegate = self
        panel.hasShadow = true

        // Set initial size
        settings.position.setLoaded(panel, size: settings.size)

        // Set content
        panel.initialFrame = panel.frame
        panel.contentView = MainWindowHostingView(rootView: root)
        panel.initialFrame = nil

        self.window = panel

        // Register with AppDelegate for shortcut routing
        appDelegate.registerMainWindow(
            panel,
            windowId: windowId,
            tabManager: tabManager,
            sidebarState: sidebarState,
            sidebarSelectionState: sidebarSelectionState
        )
    }

    // MARK: - Helpers

    private func currentSettings() -> (
        position: HotkeyWindowPosition,
        size: HotkeyWindowSize,
        floating: Bool,
        autoHide: Bool,
        animationDuration: Double,
        spaceBehavior: HotkeyWindowSpaceBehavior,
        screen: HotkeyWindowScreen
    ) {
        (
            position: HotkeyWindowSettings.position,
            size: HotkeyWindowSettings.size,
            floating: HotkeyWindowSettings.floating,
            autoHide: HotkeyWindowSettings.autoHide,
            animationDuration: HotkeyWindowSettings.animationDuration,
            spaceBehavior: HotkeyWindowSettings.spaceBehavior,
            screen: HotkeyWindowSettings.screen
        )
    }

    private func makeWindowKey(_ window: NSWindow, retries: UInt8 = 0) {
        guard visible else { return }
        window.makeKeyAndOrderFront(nil)
        guard !window.isKeyWindow else { return }
        guard retries > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(25)) { [self] in
            makeWindowKey(window, retries: retries - 1)
        }
    }

    // MARK: - Dock Management

    private class HiddenDock {
        let previousAutoHide: Bool
        private var hidden: Bool = false

        init() {
            previousAutoHide = Dock.autoHideEnabled
        }

        deinit { restore() }

        func hide() {
            guard !hidden else { return }
            NSApp.acquirePresentationOption(.autoHideDock)
            Dock.autoHideEnabled = true
            hidden = true
        }

        func restore() {
            guard hidden else { return }
            NSApp.releasePresentationOption(.autoHideDock)
            Dock.autoHideEnabled = previousAutoHide
            hidden = false
        }
    }
}

// MARK: - NSApplication Extension

extension NSApplication {
    func acquirePresentationOption(_ option: NSApplication.PresentationOptions.Element) {
        var options = presentationOptions
        options.insert(option)
        presentationOptions = options
    }

    func releasePresentationOption(_ option: NSApplication.PresentationOptions.Element) {
        var options = presentationOptions
        options.remove(option)
        presentationOptions = options
    }
}
