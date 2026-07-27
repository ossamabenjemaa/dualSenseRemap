import Foundation

/// Every physical control on a DualSense controller that can carry a mapping.
/// Raw values are stable identifiers used in persisted profiles — never rename.
enum ControllerElement: String, Codable, CaseIterable, Hashable, Identifiable {
    // Face buttons
    case cross
    case circle
    case square
    case triangle

    // D-pad
    case dpadUp
    case dpadDown
    case dpadLeft
    case dpadRight

    // Shoulders / triggers (digital press)
    case l1
    case r1
    case l2
    case r2

    // Stick clicks
    case l3
    case r3

    // System buttons
    case create
    case options
    case ps
    case mute
    case touchpadClick

    // Analog / continuous inputs (configured through modes, not single actions)
    case leftStick
    case rightStick
    case l2Analog
    case r2Analog
    case touchpadSurface
    case gyro

    var id: String { rawValue }

    /// Digital elements accept an `Action` binding; analog elements are
    /// configured through `StickMode` / `TouchpadMode` / `GyroMode` instead.
    var isDigital: Bool {
        switch self {
        case .leftStick, .rightStick, .l2Analog, .r2Analog, .touchpadSurface, .gyro:
            return false
        default:
            return true
        }
    }

    /// Human-readable name, used across the UI.
    var displayName: String {
        switch self {
        case .cross: return "Croix (✕)"
        case .circle: return "Rond (○)"
        case .square: return "Carré (□)"
        case .triangle: return "Triangle (△)"
        case .dpadUp: return "Croix dir. Haut"
        case .dpadDown: return "Croix dir. Bas"
        case .dpadLeft: return "Croix dir. Gauche"
        case .dpadRight: return "Croix dir. Droite"
        case .l1: return "L1"
        case .r1: return "R1"
        case .l2: return "L2 (pression)"
        case .r2: return "R2 (pression)"
        case .l3: return "L3 (clic stick G)"
        case .r3: return "R3 (clic stick D)"
        case .create: return "Create"
        case .options: return "Options"
        case .ps: return "Bouton PS"
        case .mute: return "Micro (mute)"
        case .touchpadClick: return "Clic pavé tactile"
        case .leftStick: return "Stick gauche"
        case .rightStick: return "Stick droit"
        case .l2Analog: return "L2 (analogique)"
        case .r2Analog: return "R2 (analogique)"
        case .touchpadSurface: return "Surface pavé tactile"
        case .gyro: return "Gyroscope"
        }
    }
}
