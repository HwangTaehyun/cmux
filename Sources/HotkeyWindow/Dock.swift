import Cocoa

// MARK: - Private API Declarations

@_silgen_name("CoreDockGetOrientationAndPinning")
private func CoreDockGetOrientationAndPinning(
    _ outOrientation: UnsafeMutablePointer<Int32>,
    _ outPinning: UnsafeMutablePointer<Int32>)

@_silgen_name("CoreDockGetAutoHideEnabled")
private func CoreDockGetAutoHideEnabled() -> Bool

@_silgen_name("CoreDockSetAutoHideEnabled")
private func CoreDockSetAutoHideEnabled(_ flag: Bool)

// MARK: - Dock Orientation

enum DockOrientation: Int {
    case top = 1
    case bottom = 2
    case left = 3
    case right = 4
}

// MARK: - Dock

/// Provides access to macOS Dock state via private APIs.
/// Ported from ghostty's Dock helper.
class Dock {
    /// Returns the orientation of the dock or nil if it can't be determined.
    static var orientation: DockOrientation? {
        var orientation: Int32 = 0
        var pinning: Int32 = 0
        CoreDockGetOrientationAndPinning(&orientation, &pinning)
        return .init(rawValue: Int(orientation))
    }

    /// Get or set the dock autohide state.
    static var autoHideEnabled: Bool {
        get { CoreDockGetAutoHideEnabled() }
        set { CoreDockSetAutoHideEnabled(newValue) }
    }
}
