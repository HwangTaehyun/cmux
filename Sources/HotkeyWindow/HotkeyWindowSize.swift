import Foundation

/// Size configuration for the hotkey window.
/// Uses percentage-based sizing (0.0-1.0) for primary and optional secondary axis.
/// Ported/simplified from ghostty's QuickTerminalSize.
struct HotkeyWindowSize: Codable {
    /// Primary axis size as a percentage (0.0-1.0). For top/bottom this is height, for left/right this is width.
    var primary: CGFloat

    /// Secondary axis size as a percentage (0.0-1.0). nil means full extent of the screen.
    var secondary: CGFloat?

    init(primary: CGFloat = 0.5, secondary: CGFloat? = nil) {
        self.primary = primary
        self.secondary = secondary
    }

    /// Calculate pixel dimensions for the given position and screen size.
    func calculate(position: HotkeyWindowPosition, screenDimensions: CGSize) -> CGSize {
        switch position {
        case .left, .right:
            return CGSize(
                width: screenDimensions.width * primary,
                height: secondary.map { screenDimensions.height * $0 } ?? screenDimensions.height
            )
        case .top, .bottom:
            return CGSize(
                width: secondary.map { screenDimensions.width * $0 } ?? screenDimensions.width,
                height: screenDimensions.height * primary
            )
        case .center:
            if screenDimensions.width >= screenDimensions.height {
                // Landscape
                return CGSize(
                    width: screenDimensions.width * primary,
                    height: secondary.map { screenDimensions.height * $0 } ?? screenDimensions.height * 0.5
                )
            } else {
                // Portrait
                return CGSize(
                    width: secondary.map { screenDimensions.width * $0 } ?? screenDimensions.width * 0.5,
                    height: screenDimensions.height * primary
                )
            }
        }
    }
}
