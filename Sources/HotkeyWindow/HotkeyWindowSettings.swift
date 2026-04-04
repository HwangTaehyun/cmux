import Foundation

/// Centralized settings for the hotkey window feature.
/// All values are stored in UserDefaults with sensible defaults.
enum HotkeyWindowSettings {
    // MARK: - UserDefaults Keys

    private static let enabledKey = "hotkeyWindow.enabled"
    private static let positionKey = "hotkeyWindow.position"
    private static let sizePrimaryKey = "hotkeyWindow.sizePrimary"
    private static let autoHideKey = "hotkeyWindow.autoHide"
    private static let floatingKey = "hotkeyWindow.floating"
    private static let animationDurationKey = "hotkeyWindow.animationDuration"
    private static let spaceBehaviorKey = "hotkeyWindow.spaceBehavior"
    private static let screenKey = "hotkeyWindow.screen"

    // MARK: - Typed Accessors

    static var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: enabledKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: enabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var position: HotkeyWindowPosition {
        get {
            guard let raw = UserDefaults.standard.string(forKey: positionKey),
                  let value = HotkeyWindowPosition(rawValue: raw) else { return .top }
            return value
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: positionKey) }
    }

    static var sizePrimary: CGFloat {
        get {
            let value = UserDefaults.standard.double(forKey: sizePrimaryKey)
            return value > 0 ? CGFloat(value) : 0.5
        }
        set { UserDefaults.standard.set(Double(newValue), forKey: sizePrimaryKey) }
    }

    static var size: HotkeyWindowSize {
        HotkeyWindowSize(primary: sizePrimary)
    }

    static var autoHide: Bool {
        get {
            if UserDefaults.standard.object(forKey: autoHideKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: autoHideKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: autoHideKey) }
    }

    static var floating: Bool {
        get { UserDefaults.standard.bool(forKey: floatingKey) }
        set { UserDefaults.standard.set(newValue, forKey: floatingKey) }
    }

    static var animationDuration: Double {
        get {
            let value = UserDefaults.standard.double(forKey: animationDurationKey)
            return value > 0 ? value : 0.2
        }
        set { UserDefaults.standard.set(newValue, forKey: animationDurationKey) }
    }

    static var spaceBehavior: HotkeyWindowSpaceBehavior {
        get {
            guard let raw = UserDefaults.standard.string(forKey: spaceBehaviorKey),
                  let value = HotkeyWindowSpaceBehavior(rawValue: raw) else { return .move }
            return value
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: spaceBehaviorKey) }
    }

    static var screen: HotkeyWindowScreen {
        get {
            guard let raw = UserDefaults.standard.string(forKey: screenKey),
                  let value = HotkeyWindowScreen(rawValue: raw) else { return .main }
            return value
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: screenKey) }
    }
}
