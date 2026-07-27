import Foundation
import CoreGraphics

/// One finger on the touchpad. Coordinates are normalized to [-1, 1]
/// (GameController convention: x → right, y → up), origin at pad center.
struct TouchpadTouch: Hashable {
    var id: Int // 0 = primary finger, 1 = secondary
    var x: Double
    var y: Double
    var isTouching: Bool
}

struct GyroSample: Hashable {
    /// Rotation rate, radians/second (x = pitch, y = yaw, z = roll).
    var rotationX: Double
    var rotationY: Double
    var rotationZ: Double
}

enum BatteryState: String {
    case discharging
    case charging
    case full
    case unknown
}

struct BatteryStatus: Hashable {
    var level: Double // 0...1
    var state: BatteryState
}

/// Discrete events emitted by the input layer and consumed by the mapping engine
/// and the virtual keyboard.
enum ControllerEvent {
    case connected(name: String)
    case disconnected
    case buttonDown(ControllerElement)
    case buttonUp(ControllerElement)
    /// Continuous values, emitted from the polling loop (~120 Hz while active).
    case leftStick(x: Double, y: Double)
    case rightStick(x: Double, y: Double)
    case leftTrigger(Double)
    case rightTrigger(Double)
    case touchpad(primary: TouchpadTouch, secondary: TouchpadTouch)
    case gyro(GyroSample)
    case battery(BatteryStatus)
}

/// Snapshot of the full controller state, used by the UI's live view.
struct ControllerSnapshot {
    var pressed: Set<ControllerElement> = []
    var leftStick: CGPoint = .zero
    var rightStick: CGPoint = .zero
    var leftTrigger: Double = 0
    var rightTrigger: Double = 0
    var primaryTouch: TouchpadTouch = TouchpadTouch(id: 0, x: 0, y: 0, isTouching: false)
    var secondaryTouch: TouchpadTouch = TouchpadTouch(id: 1, x: 0, y: 0, isTouching: false)
    var battery: BatteryStatus = BatteryStatus(level: 0, state: .unknown)
    var isConnected: Bool = false
    var controllerName: String = ""
}
