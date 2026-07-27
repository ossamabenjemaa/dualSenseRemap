import Foundation

/// Response curve applied to stick deflection before it drives pointer/scroll speed.
enum ResponseCurve: String, Codable, Hashable, CaseIterable {
    case linear
    case accelerated // squared — precise near center, fast at the edge
    case aggressive  // cubed

    func apply(_ value: Double) -> Double {
        switch self {
        case .linear: return value
        case .accelerated: return value * abs(value)
        case .aggressive: return value * value * value
        }
    }

    var displayName: String {
        switch self {
        case .linear: return "Linéaire"
        case .accelerated: return "Accélérée"
        case .aggressive: return "Agressive"
        }
    }
}

struct StickTuning: Codable, Hashable {
    /// 0...1 — deflection below this is ignored.
    var deadzone: Double = 0.12
    /// Pointer: max px/s at full deflection. Scroll: max lines/s.
    var sensitivity: Double = 900
    var curve: ResponseCurve = .accelerated
    var invertY: Bool = false
}

/// What a thumbstick drives.
enum StickMode: Codable, Hashable {
    case disabled
    case mousePointer(StickTuning)
    case scroll(StickTuning)
    case arrowKeys(repeatIntervalMs: Int)
    case wasd
    case volumeAndBrightness // vertical = volume, horizontal = brightness
    case keyboardFocus       // reserved for virtual keyboard navigation

    var displayName: String {
        switch self {
        case .disabled: return "Désactivé"
        case .mousePointer: return "Pointeur souris"
        case .scroll: return "Défilement"
        case .arrowKeys: return "Flèches du clavier"
        case .wasd: return "Touches ZQSD"
        case .volumeAndBrightness: return "Volume / Luminosité"
        case .keyboardFocus: return "Navigation clavier virtuel"
        }
    }
}

/// What the touchpad surface drives.
enum TouchpadMode: Codable, Hashable {
    case disabled
    /// Relative pointer movement like a laptop trackpad:
    /// 1 finger moves the pointer, 2 fingers scroll, tap = click (optional).
    case trackpad(sensitivity: Double, tapToClick: Bool, twoFingerScroll: Bool, naturalScroll: Bool)
    /// Touchpad maps 1:1 to the screen (absolute positioning).
    case absolutePointer
    /// Horizontal swipes switch desktop spaces, vertical opens Mission Control.
    case gestures

    var displayName: String {
        switch self {
        case .disabled: return "Désactivé"
        case .trackpad: return "Trackpad"
        case .absolutePointer: return "Pointeur absolu"
        case .gestures: return "Gestes (Spaces)"
        }
    }

    static var defaultTrackpad: TouchpadMode {
        .trackpad(sensitivity: 2.4, tapToClick: true, twoFingerScroll: true, naturalScroll: true)
    }
}

/// Analog trigger behaviour.
struct TriggerSettings: Codable, Hashable {
    /// 0...1 — analog value at which the digital action fires.
    var activationThreshold: Double = 0.45
    /// Adaptive trigger resistance profile to apply on the physical trigger.
    var adaptiveEffect: AdaptiveTriggerEffect = .off
}

enum AdaptiveTriggerEffect: String, Codable, Hashable, CaseIterable {
    case off
    case light      // slight uniform resistance
    case medium
    case strong
    case clicky     // resistance then release, like a mouse click
    case vibration  // rapid feedback pulses

    var displayName: String {
        switch self {
        case .off: return "Aucun"
        case .light: return "Résistance légère"
        case .medium: return "Résistance moyenne"
        case .strong: return "Résistance forte"
        case .clicky: return "Clic (seuil)"
        case .vibration: return "Vibration"
        }
    }
}

/// Gyroscope behaviour.
enum GyroMode: Codable, Hashable {
    case disabled
    /// Pointer control by tilting the controller. `activationElement` = nil means always on.
    case mousePointer(sensitivity: Double, activationHold: ControllerElement?)
    case scroll(sensitivity: Double)

    var displayName: String {
        switch self {
        case .disabled: return "Désactivé"
        case .mousePointer: return "Pointeur (gyro aiming)"
        case .scroll: return "Défilement"
        }
    }
}

/// Lightbar configuration for a profile.
struct LightbarSettings: Codable, Hashable {
    var red: Double = 0.0
    var green: Double = 0.35
    var blue: Double = 1.0
    var followsProfile: Bool = true // each profile tints the lightbar with its color
}

/// Haptic feedback configuration.
struct HapticsSettings: Codable, Hashable {
    var enabled: Bool = true
    /// 0...1 intensity for UI feedback pulses (mapping fired, keyboard key pressed…).
    var intensity: Double = 0.6
}
