import Foundation
import Combine
import CoreGraphics
import GameController
import CoreHaptics
import os

/// Which physical trigger an adaptive-trigger effect targets.
enum TriggerSide {
    case left
    case right
}

/// Bridge between the physical DualSense controller and the rest of the app.
///
/// Uses GameController.framework for everything it exposes (buttons, sticks,
/// triggers, touchpad, motion, lightbar, battery, haptics, adaptive triggers)
/// and falls back to a raw IOHID listener (`HIDMuteMonitor`) for the mute
/// button, which GameController does not surface.
///
/// Threading model: `controller.handlerQueue` is pinned to the main queue, the
/// HID monitor is scheduled on the main run loop and notification observers use
/// the main `OperationQueue` — so every `@Published` mutation and every
/// `events.send` happens on the main thread. The few callbacks that can arrive
/// on background queues (CoreHaptics engine handlers) hop through
/// `DispatchQueue.main.async` before touching state.
final class DualSenseManager: ObservableObject {

    static let shared = DualSenseManager()

    /// Live full-state view consumed by the UI.
    @Published private(set) var snapshot = ControllerSnapshot()

    /// Discrete + continuous event stream consumed by the mapping engine and
    /// the virtual keyboard.
    let events = PassthroughSubject<ControllerEvent, Never>()

    // MARK: - Private state

    private let logger = os.Logger(subsystem: "com.dualsenseremap.app", category: "Input")
    private let muteMonitor = HIDMuteMonitor()

    private var started = false
    private var observers: [NSObjectProtocol] = []
    private var activeController: GCController?

    /// Mirror of `snapshot.pressed`, used to guarantee exactly one event per edge.
    private var pressedElements: Set<ControllerElement> = []

    // Touchpad bookkeeping.
    private var primaryTouch = TouchpadTouch(id: 0, x: 0, y: 0, isTouching: false)
    private var secondaryTouch = TouchpadTouch(id: 1, x: 0, y: 0, isTouching: false)
    private var touchpadButtonTouched = false
    private var lastTouchpadMove: CFAbsoluteTime = 0
    private var touchExpiryWorkItem: DispatchWorkItem?
    /// How long a non-zero touchpad move keeps the inferred "touching" state
    /// alive when `touchpadButton.isTouched` does not report.
    private static let touchInferenceTimeout: CFAbsoluteTime = 0.25

    // Motion.
    private var gyroWanted = false

    // Feedback hardware handles + last requested values (re-applied on reconnect).
    private var adaptiveLeft: GCDualSenseAdaptiveTrigger?
    private var adaptiveRight: GCDualSenseAdaptiveTrigger?
    private var lastLeftTriggerEffect: AdaptiveTriggerEffect = .off
    private var lastRightTriggerEffect: AdaptiveTriggerEffect = .off
    private var lastLightbarColor: (red: Double, green: Double, blue: Double)?
    private var lastPlayerIndicator = 1

    // Haptics.
    private var hapticEngine: CHHapticEngine?

    // Battery.
    private var batteryTimer: Timer?
    private static let batteryPollInterval: TimeInterval = 60

    // MARK: - Lifecycle

    private init() {
        // The HID monitor only covers the mute button; everything else flows
        // through GameController. It is started lazily, and only when Input
        // Monitoring is already granted (it never prompts).
        muteMonitor.onMuteChanged = { [weak self] pressed in
            guard let self = self else { return }
            if Thread.isMainThread {
                self.setPressed(.mute, pressed)
            } else {
                DispatchQueue.main.async { self.setPressed(.mute, pressed) }
            }
        }
    }

    /// Begins controller discovery and wireless browsing. Idempotent.
    func start() {
        guard !started else { return }
        started = true

        // Without this, GameController stops delivering input while the app
        // is not frontmost (default false on macOS 11.3+) — fatal for a remapper.
        GCController.shouldMonitorBackgroundEvents = true

        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: .main
        ) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            self?.controllerDidConnect(controller)
        })
        observers.append(center.addObserver(
            forName: .GCControllerDidDisconnect, object: nil, queue: .main
        ) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            self?.controllerDidDisconnect(controller)
        })

        // Adopt controllers that were connected before we started listening.
        for controller in GCController.controllers() {
            controllerDidConnect(controller)
        }
        GCController.startWirelessControllerDiscovery(completionHandler: nil)

        let timer = Timer(timeInterval: Self.batteryPollInterval, repeats: true) { [weak self] _ in
            self?.batteryTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        batteryTimer = timer

        muteMonitor.startIfPermitted()
        logger.info("Input pipeline started (wireless discovery on)")
    }

    /// Stops discovery, detaches from the controller and resets the snapshot.
    func stop() {
        guard started else { return }
        started = false

        GCController.stopWirelessControllerDiscovery()
        for token in observers {
            NotificationCenter.default.removeObserver(token)
        }
        observers.removeAll()

        batteryTimer?.invalidate()
        batteryTimer = nil
        touchExpiryWorkItem?.cancel()
        touchExpiryWorkItem = nil
        muteMonitor.stop()

        let wasConnected = activeController != nil
        if let controller = activeController {
            detach(controller)
        }
        activeController = nil
        teardownFeedbackHandles()

        pressedElements = []
        resetTouchState()
        let publish = {
            self.snapshot = ControllerSnapshot()
            if wasConnected { self.events.send(.disconnected) }
        }
        if Thread.isMainThread { publish() } else { DispatchQueue.main.async(execute: publish) }
        logger.info("Input pipeline stopped")
    }

    // MARK: - Public feedback API

    /// Sets the lightbar color (components 0...1). Remembered and re-applied on reconnect.
    func setLightbar(red: Double, green: Double, blue: Double) {
        lastLightbarColor = (red, green, blue)
        guard let light = activeController?.light else { return }
        light.color = GCColor(
            red: Float(min(max(red, 0), 1)),
            green: Float(min(max(green, 0), 1)),
            blue: Float(min(max(blue, 0), 1))
        )
    }

    /// Applies an adaptive-trigger effect to L2 or R2 (DualSense only; no-op otherwise).
    func setAdaptiveTrigger(_ side: TriggerSide, effect: AdaptiveTriggerEffect) {
        switch side {
        case .left: lastLeftTriggerEffect = effect
        case .right: lastRightTriggerEffect = effect
        }
        let trigger: GCDualSenseAdaptiveTrigger?
        switch side {
        case .left: trigger = adaptiveLeft
        case .right: trigger = adaptiveRight
        }
        guard let trigger = trigger else { return }
        applyAdaptiveEffect(effect, to: trigger)
    }

    /// Plays a one-shot haptic pulse on the controller's voice-coil actuators.
    func playHapticPulse(intensity: Double, durationMs: Int) {
        guard let engine = ensureHapticEngine() else { return }
        let clamped = Float(min(max(intensity, 0), 1))
        let parameters = [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: clamped),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
        ]
        let event: CHHapticEvent
        if durationMs > 64 {
            let duration = Double(durationMs) / 1000.0
            event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: parameters,
                relativeTime: 0,
                duration: duration
            )
        } else {
            event = CHHapticEvent(eventType: .hapticTransient, parameters: parameters, relativeTime: 0)
        }
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            logger.error("Haptic pulse failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Lights player indicator LEDs 1–4 under the touchpad; any other value turns them off.
    func setPlayerIndicatorLights(_ index: Int) {
        lastPlayerIndicator = index
        let raw = (1...4).contains(index) ? index - 1 : -1
        activeController?.playerIndex = GCControllerPlayerIndex(rawValue: raw) ?? .indexUnset
    }

    /// Enables/disables gyroscope streaming. Sensors stay off until the first
    /// consumer opts in, to save controller battery.
    func setGyroActive(_ active: Bool) {
        let apply = {
            self.gyroWanted = active
            self.applyMotionState()
        }
        if Thread.isMainThread { apply() } else { DispatchQueue.main.async(execute: apply) }
    }

    /// Drives the microphone LED through the raw HID output report
    /// (module-internal convenience; requires Input Monitoring).
    func setMuteLED(on: Bool) {
        muteMonitor.setMuteLED(on ? .solid : .off)
    }

    // MARK: - Connection handling

    private func controllerDidConnect(_ controller: GCController) {
        let name = controller.vendorName ?? controller.productCategory ?? "?"
        logger.info("Controller connected: \(name, privacy: .public)")

        if let current = activeController {
            let newIsDualSense = controller.extendedGamepad is GCDualSenseGamepad
            let currentIsDualSense = current.extendedGamepad is GCDualSenseGamepad
            // Keep the current controller unless a real DualSense shows up
            // while a generic pad is active.
            guard newIsDualSense && !currentIsDualSense else {
                logger.info("Secondary controller ignored (one already active)")
                return
            }
            detach(current)
            teardownFeedbackHandles()
        }
        adopt(controller)
    }

    private func controllerDidDisconnect(_ controller: GCController) {
        let name = controller.vendorName ?? "?"
        logger.info("Controller disconnected: \(name, privacy: .public)")
        guard controller === activeController else { return }

        detach(controller)
        activeController = nil
        teardownFeedbackHandles()
        pressedElements = []
        resetTouchState()
        snapshot = ControllerSnapshot()
        events.send(.disconnected)

        // Fall back to any other connected controller, preferring a DualSense.
        let remaining = GCController.controllers().filter { $0 !== controller && $0.extendedGamepad != nil }
        if let next = remaining.first(where: { $0.extendedGamepad is GCDualSenseGamepad }) ?? remaining.first {
            adopt(next)
        }
    }

    private func adopt(_ controller: GCController) {
        guard let pad = controller.extendedGamepad else {
            logger.warning("Controller has no extended gamepad profile — ignored")
            return
        }
        activeController = controller
        // All element handlers fire on this queue → @Published mutations stay on main.
        controller.handlerQueue = .main

        wire(pad)
        if let dualSense = pad as? GCDualSenseGamepad {
            wireDualSenseExtras(dualSense)
        } else {
            logger.info("Non-DualSense controller: touchpad and adaptive triggers unavailable")
        }

        let name = controller.vendorName ?? controller.productCategory ?? "Manette"
        pressedElements = []
        resetTouchState()
        var fresh = ControllerSnapshot()
        fresh.isConnected = true
        fresh.controllerName = name
        snapshot = fresh
        events.send(.connected(name: name))

        setPlayerIndicatorLights(lastPlayerIndicator)
        if let color = lastLightbarColor {
            setLightbar(red: color.red, green: color.green, blue: color.blue)
        }
        if let left = adaptiveLeft { applyAdaptiveEffect(lastLeftTriggerEffect, to: left) }
        if let right = adaptiveRight { applyAdaptiveEffect(lastRightTriggerEffect, to: right) }
        applyMotionState()
        batteryTick()
        muteMonitor.startIfPermitted()
        logger.info("Adopted controller: \(name, privacy: .public)")
    }

    private func teardownFeedbackHandles() {
        if let engine = hapticEngine {
            engine.stop(completionHandler: nil)
        }
        hapticEngine = nil
        adaptiveLeft = nil
        adaptiveRight = nil
    }

    // MARK: - Element wiring

    /// Binds a digital button to a `ControllerElement`, emitting exactly one
    /// event per pressed/released edge.
    private func bind(_ button: GCControllerButtonInput?, to element: ControllerElement) {
        button?.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.setPressed(element, pressed)
        }
    }

    private func wire(_ pad: GCExtendedGamepad) {
        // Face buttons (Cross/Circle/Square/Triangle).
        bind(pad.buttonA, to: .cross)
        bind(pad.buttonB, to: .circle)
        bind(pad.buttonX, to: .square)
        bind(pad.buttonY, to: .triangle)

        // D-pad.
        bind(pad.dpad.up, to: .dpadUp)
        bind(pad.dpad.down, to: .dpadDown)
        bind(pad.dpad.left, to: .dpadLeft)
        bind(pad.dpad.right, to: .dpadRight)

        // Shoulders + trigger digital edges (isPressed threshold handled by GC).
        bind(pad.leftShoulder, to: .l1)
        bind(pad.rightShoulder, to: .r1)
        bind(pad.leftTrigger, to: .l2)
        bind(pad.rightTrigger, to: .r2)

        // Stick clicks.
        bind(pad.leftThumbstickButton, to: .l3)
        bind(pad.rightThumbstickButton, to: .r3)

        // System buttons: Menu = Options, Options = Create, Home = PS.
        bind(pad.buttonOptions, to: .create)
        bind(pad.buttonMenu, to: .options)
        bind(pad.buttonHome, to: .ps)

        // Continuous: thumbsticks.
        pad.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
            guard let self = self else { return }
            let dx = Double(x), dy = Double(y)
            self.snapshot.leftStick = CGPoint(x: dx, y: dy)
            self.events.send(.leftStick(x: dx, y: dy))
        }
        pad.rightThumbstick.valueChangedHandler = { [weak self] _, x, y in
            guard let self = self else { return }
            let dx = Double(x), dy = Double(y)
            self.snapshot.rightStick = CGPoint(x: dx, y: dy)
            self.events.send(.rightStick(x: dx, y: dy))
        }

        // Continuous: analog triggers.
        pad.leftTrigger.valueChangedHandler = { [weak self] _, value, _ in
            guard let self = self else { return }
            let v = Double(value)
            self.snapshot.leftTrigger = v
            self.events.send(.leftTrigger(v))
        }
        pad.rightTrigger.valueChangedHandler = { [weak self] _, value, _ in
            guard let self = self else { return }
            let v = Double(value)
            self.snapshot.rightTrigger = v
            self.events.send(.rightTrigger(v))
        }
    }

    private func wireDualSenseExtras(_ dualSense: GCDualSenseGamepad) {
        adaptiveLeft = dualSense.leftTrigger
        adaptiveRight = dualSense.rightTrigger

        // Touchpad click (physical press).
        bind(dualSense.touchpadButton, to: .touchpadClick)

        // Finger-resting state — touchpadButton reports touch without press.
        dualSense.touchpadButton.touchedChangedHandler = { [weak self] _, _, touched in
            guard let self = self else { return }
            self.touchpadButtonTouched = touched
            if !touched {
                // Kill the movement-based inference so release is immediate.
                self.lastTouchpadMove = 0
            }
            self.refreshTouchState()
        }

        // Finger positions, normalized -1...1 with origin at pad center.
        // touchpadPrimary reports even without a physical click.
        dualSense.touchpadPrimary.valueChangedHandler = { [weak self] _, x, y in
            self?.touchpadValueChanged(primary: true, x: Double(x), y: Double(y))
        }
        dualSense.touchpadSecondary.valueChangedHandler = { [weak self] _, x, y in
            self?.touchpadValueChanged(primary: false, x: Double(x), y: Double(y))
        }
    }

    private func detach(_ controller: GCController) {
        touchExpiryWorkItem?.cancel()
        touchExpiryWorkItem = nil
        guard let pad = controller.extendedGamepad else { return }

        let buttons: [GCControllerButtonInput?] = [
            pad.buttonA, pad.buttonB, pad.buttonX, pad.buttonY,
            pad.dpad.up, pad.dpad.down, pad.dpad.left, pad.dpad.right,
            pad.leftShoulder, pad.rightShoulder,
            pad.leftTrigger, pad.rightTrigger,
            pad.leftThumbstickButton, pad.rightThumbstickButton,
            pad.buttonOptions, pad.buttonMenu, pad.buttonHome,
        ]
        for button in buttons {
            button?.pressedChangedHandler = nil
            button?.valueChangedHandler = nil
            button?.touchedChangedHandler = nil
        }
        pad.leftThumbstick.valueChangedHandler = nil
        pad.rightThumbstick.valueChangedHandler = nil

        if let dualSense = pad as? GCDualSenseGamepad {
            dualSense.touchpadButton.pressedChangedHandler = nil
            dualSense.touchpadButton.touchedChangedHandler = nil
            dualSense.touchpadPrimary.valueChangedHandler = nil
            dualSense.touchpadSecondary.valueChangedHandler = nil
        }

        controller.motion?.valueChangedHandler = nil
        if let motion = controller.motion, motion.sensorsRequireManualActivation {
            motion.sensorsActive = false
        }
    }

    // MARK: - Event plumbing (main thread)

    /// Updates the pressed set and emits `.buttonDown`/`.buttonUp` exactly once per edge.
    private func setPressed(_ element: ControllerElement, _ pressed: Bool) {
        if pressed {
            guard !pressedElements.contains(element) else { return }
            pressedElements.insert(element)
            snapshot.pressed = pressedElements
            events.send(.buttonDown(element))
        } else {
            guard pressedElements.contains(element) else { return }
            pressedElements.remove(element)
            snapshot.pressed = pressedElements
            events.send(.buttonUp(element))
        }
    }

    private func touchpadValueChanged(primary: Bool, x: Double, y: Double) {
        // A snap back to exactly (0, 0) is what GC reports on finger lift —
        // it must not count as touch evidence for the inference fallback.
        if x != 0 || y != 0 {
            lastTouchpadMove = CFAbsoluteTimeGetCurrent()
            scheduleTouchExpiry()
        }
        if primary {
            primaryTouch.x = x
            primaryTouch.y = y
        } else {
            secondaryTouch.x = x
            secondaryTouch.y = y
        }
        refreshTouchState()
    }

    private func refreshTouchState() {
        let movedRecently = (CFAbsoluteTimeGetCurrent() - lastTouchpadMove) < Self.touchInferenceTimeout
        let anyTouch = touchpadButtonTouched || movedRecently
        primaryTouch.isTouching = anyTouch
        secondaryTouch.isTouching = anyTouch && (secondaryTouch.x != 0 || secondaryTouch.y != 0)

        guard primaryTouch != snapshot.primaryTouch || secondaryTouch != snapshot.secondaryTouch else {
            return
        }
        snapshot.primaryTouch = primaryTouch
        snapshot.secondaryTouch = secondaryTouch
        events.send(.touchpad(primary: primaryTouch, secondary: secondaryTouch))
    }

    /// Re-evaluates the inferred touch state shortly after the last movement,
    /// so a motionless-then-lifted finger is eventually reported as released
    /// even if `touchedChangedHandler` never fires.
    private func scheduleTouchExpiry() {
        touchExpiryWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.refreshTouchState()
        }
        touchExpiryWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.touchInferenceTimeout + 0.02, execute: item)
    }

    private func resetTouchState() {
        primaryTouch = TouchpadTouch(id: 0, x: 0, y: 0, isTouching: false)
        secondaryTouch = TouchpadTouch(id: 1, x: 0, y: 0, isTouching: false)
        touchpadButtonTouched = false
        lastTouchpadMove = 0
    }

    // MARK: - Motion

    private func applyMotionState() {
        guard let motion = activeController?.motion else { return }
        if gyroWanted {
            motion.valueChangedHandler = { [weak self] sensed in
                guard let self = self else { return }
                let rate = sensed.rotationRate
                self.events.send(.gyro(GyroSample(
                    rotationX: rate.x,
                    rotationY: rate.y,
                    rotationZ: rate.z
                )))
            }
            // DualSense requires manual sensor activation.
            if motion.sensorsRequireManualActivation {
                motion.sensorsActive = true
            }
            logger.info("Gyroscope streaming enabled")
        } else {
            motion.valueChangedHandler = nil
            if motion.sensorsRequireManualActivation {
                motion.sensorsActive = false
            }
        }
    }

    // MARK: - Battery

    private func batteryTick() {
        // Opportunistically pick up a freshly granted Input Monitoring
        // permission without ever prompting.
        muteMonitor.startIfPermitted()

        guard let battery = activeController?.battery else { return }
        let level = Double(min(max(battery.batteryLevel, 0), 1))
        let state: BatteryState
        switch battery.batteryState {
        case .discharging: state = .discharging
        case .charging: state = .charging
        case .full: state = .full
        case .unknown: state = .unknown
        @unknown default: state = .unknown
        }
        let status = BatteryStatus(level: level, state: state)
        guard status != snapshot.battery else { return }
        let publish = {
            self.snapshot.battery = status
            self.events.send(.battery(status))
        }
        if Thread.isMainThread { publish() } else { DispatchQueue.main.async(execute: publish) }
    }

    // MARK: - Adaptive triggers

    private func applyAdaptiveEffect(_ effect: AdaptiveTriggerEffect, to trigger: GCDualSenseAdaptiveTrigger) {
        switch effect {
        case .off:
            trigger.setModeOff()
        case .light:
            trigger.setModeFeedbackWithStartPosition(0.0, resistiveStrength: 0.3)
        case .medium:
            trigger.setModeFeedbackWithStartPosition(0.0, resistiveStrength: 0.6)
        case .strong:
            trigger.setModeFeedbackWithStartPosition(0.0, resistiveStrength: 1.0)
        case .clicky:
            // Resistance ramps up then releases past the end position — mouse-click feel.
            trigger.setModeWeaponWithStartPosition(0.2, endPosition: 0.6, resistiveStrength: 0.9)
        case .vibration:
            trigger.setModeVibrationWithStartPosition(0.1, amplitude: 0.65, frequency: 0.55)
        }
    }

    // MARK: - Haptics

    private func ensureHapticEngine() -> CHHapticEngine? {
        if let engine = hapticEngine { return engine }
        guard let haptics = activeController?.haptics,
              let engine = haptics.createEngine(withLocality: .default) else {
            return nil
        }
        engine.stoppedHandler = { [weak self] reason in
            // Arrives on a CoreHaptics internal queue — hop to main.
            DispatchQueue.main.async {
                self?.logger.info("Haptic engine stopped (reason \(reason.rawValue))")
                self?.hapticEngine = nil
            }
        }
        engine.resetHandler = { [weak self, weak engine] in
            // Server recovered from a reset: restart so cached players keep working.
            do {
                try engine?.start()
            } catch {
                DispatchQueue.main.async { self?.hapticEngine = nil }
            }
        }
        do {
            try engine.start()
        } catch {
            logger.error("Haptic engine start failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        hapticEngine = engine
        return engine
    }
}
