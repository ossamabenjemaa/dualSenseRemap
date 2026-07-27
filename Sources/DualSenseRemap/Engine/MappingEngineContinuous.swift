import Foundation
import CoreGraphics

/// Continuous input synthesis: the 120 Hz loop integrating stick modes, plus
/// event-driven touchpad and gyro processing. Everything here runs on
/// `MappingEngine.engineQueue`.
///
/// Coordinate conventions:
/// - Controller sticks/touchpad: GameController convention, x → right,
///   y → up, range −1…+1.
/// - Pointer deltas handed to `EventSynthesizer.moveMouse(dx:dy:)`: CG global
///   space, +dy moves DOWN — hence the sign flips on the y axis.
/// - Scroll deltas handed to `EventSynthesizer.scroll(dx:dy:)`: wheel
///   semantics, +dy scrolls up (reveals content above).
extension MappingEngine {

    // MARK: - 120 Hz tick

    func tick() {
        guard isStarted else { return }

        let now = CFAbsoluteTimeGetCurrent()
        let dt: Double
        if let last = runtime.lastTickTime {
            dt = min(max(now - last, 0), 0.1)
        } else {
            dt = Constants.tickInterval
        }
        runtime.lastTickTime = now

        // Pause synthesis (and drop any held direction keys) while disabled
        // or while the virtual keyboard owns the controller.
        if !isEnabled || VirtualKeyboardController.shared.isVisible {
            releaseContinuousHolds()
            return
        }

        let profile = currentProfile

        // Copy-out / copy-in avoids overlapping-access issues on `runtime`.
        var leftState = runtime.leftStickRuntime
        processStick(x: runtime.leftStickX,
                     y: runtime.leftStickY,
                     mode: profile.leftStickMode,
                     state: &leftState,
                     dt: dt,
                     now: now)
        runtime.leftStickRuntime = leftState

        var rightState = runtime.rightStickRuntime
        processStick(x: runtime.rightStickX,
                     y: runtime.rightStickY,
                     mode: profile.rightStickMode,
                     state: &rightState,
                     dt: dt,
                     now: now)
        runtime.rightStickRuntime = rightState
    }

    // MARK: - Stick modes

    func processStick(x: Double,
                      y: Double,
                      mode: StickMode,
                      state: inout StickRuntime,
                      dt: Double,
                      now: CFAbsoluteTime) {
        // Cleanup when the profile switched this stick away from a stateful mode.
        if case .wasd = mode {} else {
            Self.releaseHeldDirectionKeys(&state)
        }
        if case .arrowKeys = mode {} else {
            state.arrowDirection = nil
        }
        if case .volumeAndBrightness = mode {} else {
            state.volumeDirection = 0
            state.brightnessDirection = 0
        }

        switch mode {
        case .disabled, .keyboardFocus:
            // .keyboardFocus is consumed by the virtual keyboard itself.
            return

        case .mousePointer(let tuning):
            let deflection = Self.radialDeflection(x: x, y: y, deadzone: tuning.deadzone)
            guard deflection.magnitude > 0 else { return }
            let speed = tuning.curve.apply(deflection.magnitude) * tuning.sensitivity // px/s
            let dx = deflection.dirX * speed * dt
            var dy = -deflection.dirY * speed * dt // stick up → pointer up (CG −y)
            if tuning.invertY { dy = -dy }
            EventSynthesizer.moveMouse(dx: dx, dy: dy)

        case .scroll(let tuning):
            let deflection = Self.radialDeflection(x: x, y: y, deadzone: tuning.deadzone)
            guard deflection.magnitude > 0 else { return }
            // sensitivity is lines/s at full deflection; convert to pixels.
            let pixelsPerSecond = tuning.curve.apply(deflection.magnitude)
                * tuning.sensitivity * Constants.pixelsPerScrollLine
            var dy = deflection.dirY * pixelsPerSecond * dt // stick up → wheel up
            if tuning.invertY { dy = -dy }
            let dx = -deflection.dirX * pixelsPerSecond * dt // stick right → scroll right
            EventSynthesizer.scroll(dx: dx, dy: dy)

        case .arrowKeys(let repeatIntervalMs):
            let interval = repeatIntervalMs > 0
                ? Double(repeatIntervalMs) / 1000.0
                : Constants.defaultArrowRepeatInterval
            let magnitude = (x * x + y * y).squareRoot()
            var newDirection: ArrowDirection?
            if magnitude >= Constants.arrowThreshold {
                if abs(x) >= abs(y) {
                    newDirection = x > 0 ? .right : .left
                } else {
                    newDirection = y > 0 ? .up : .down
                }
            }
            if newDirection != state.arrowDirection {
                state.arrowDirection = newDirection
                if let direction = newDirection {
                    // Initial press fires immediately, then repeats.
                    EventSynthesizer.tap(Self.arrowCombo(direction))
                    state.nextArrowRepeat = now + interval
                }
            } else if let direction = newDirection, now >= state.nextArrowRepeat {
                EventSynthesizer.tap(Self.arrowCombo(direction))
                state.nextArrowRepeat = now + interval
            }

        case .wasd:
            // ZQSD: ANSI key codes of the physical W/A/S/D positions, which
            // type Z/Q/S/D on the French AZERTY layout. 8-way: both axes are
            // independent, diagonals hold two keys.
            Self.updateDirectionKey(code: Constants.zqsdUpKeyCode, value: y, state: &state)
            Self.updateDirectionKey(code: Constants.zqsdDownKeyCode, value: -y, state: &state)
            Self.updateDirectionKey(code: Constants.zqsdLeftKeyCode, value: -x, state: &state)
            Self.updateDirectionKey(code: Constants.zqsdRightKeyCode, value: x, state: &state)

        case .volumeAndBrightness:
            // Vertical = volume, horizontal = brightness (see StickMode doc).
            updateVolumeDial(value: y, now: now, state: &state)
            updateBrightnessDial(value: x, now: now, state: &state)
        }
    }

    /// Radial deadzone + normalization. Returns the unit direction and the
    /// deflection magnitude remapped to 0…1 past the deadzone.
    static func radialDeflection(x: Double, y: Double, deadzone: Double)
        -> (dirX: Double, dirY: Double, magnitude: Double) {
        let radius = (x * x + y * y).squareRoot()
        let dz = min(max(deadzone, 0), 0.95)
        guard radius > dz else { return (0, 0, 0) }
        let normalized = min((radius - dz) / (1 - dz), 1)
        return (x / radius, y / radius, normalized)
    }

    static func arrowCombo(_ direction: ArrowDirection) -> KeyCombo {
        switch direction {
        case .up: return Constants.arrowUpCombo
        case .down: return Constants.arrowDownCombo
        case .left: return Constants.arrowLeftCombo
        case .right: return Constants.arrowRightCombo
        }
    }

    /// Press/release hysteresis for one held direction key (ZQSD mode).
    static func updateDirectionKey(code: UInt16, value: Double, state: inout StickRuntime) {
        let label = Constants.zqsdLabels[code] ?? ""
        let held = state.heldKeyCodes.contains(code)
        if !held && value >= Constants.wasdPressThreshold {
            state.heldKeyCodes.insert(code)
            EventSynthesizer.post(KeyCombo(keyCode: code, modifiers: [], label: label), down: true)
        } else if held && value < Constants.wasdReleaseThreshold {
            state.heldKeyCodes.remove(code)
            EventSynthesizer.post(KeyCombo(keyCode: code, modifiers: [], label: label), down: false)
        }
    }

    static func releaseHeldDirectionKeys(_ state: inout StickRuntime) {
        guard !state.heldKeyCodes.isEmpty else { return }
        for code in state.heldKeyCodes {
            let label = Constants.zqsdLabels[code] ?? ""
            EventSynthesizer.post(KeyCombo(keyCode: code, modifiers: [], label: label), down: false)
        }
        state.heldKeyCodes.removeAll()
    }

    /// Discrete volume steps: first step on crossing ±0.7, then every 250 ms.
    func updateVolumeDial(value: Double, now: CFAbsoluteTime, state: inout StickRuntime) {
        let direction = value >= Constants.dialThreshold ? 1
            : (value <= -Constants.dialThreshold ? -1 : 0)
        if direction != state.volumeDirection {
            state.volumeDirection = direction
            if direction != 0 {
                executeSystemAction(direction > 0 ? .volumeUp : .volumeDown)
                state.nextVolumeStep = now + Constants.dialRepeatInterval
            }
        } else if direction != 0, now >= state.nextVolumeStep {
            executeSystemAction(direction > 0 ? .volumeUp : .volumeDown)
            state.nextVolumeStep = now + Constants.dialRepeatInterval
        }
    }

    /// Discrete brightness steps, same cadence as the volume dial.
    func updateBrightnessDial(value: Double, now: CFAbsoluteTime, state: inout StickRuntime) {
        let direction = value >= Constants.dialThreshold ? 1
            : (value <= -Constants.dialThreshold ? -1 : 0)
        if direction != state.brightnessDirection {
            state.brightnessDirection = direction
            if direction != 0 {
                executeSystemAction(direction > 0 ? .brightnessUp : .brightnessDown)
                state.nextBrightnessStep = now + Constants.dialRepeatInterval
            }
        } else if direction != 0, now >= state.nextBrightnessStep {
            executeSystemAction(direction > 0 ? .brightnessUp : .brightnessDown)
            state.nextBrightnessStep = now + Constants.dialRepeatInterval
        }
    }

    /// Drops every continuous-mode hold (both sticks) without touching
    /// discrete in-flight actions.
    func releaseContinuousHolds() {
        var left = runtime.leftStickRuntime
        Self.releaseHeldDirectionKeys(&left)
        left.arrowDirection = nil
        left.volumeDirection = 0
        left.brightnessDirection = 0
        runtime.leftStickRuntime = left

        var right = runtime.rightStickRuntime
        Self.releaseHeldDirectionKeys(&right)
        right.arrowDirection = nil
        right.volumeDirection = 0
        right.brightnessDirection = 0
        runtime.rightStickRuntime = right
    }

    // MARK: - Touchpad

    /// Event-driven touchpad processing. `synthesize == false` keeps session
    /// tracking coherent (prev positions, finger counts) without emitting any
    /// synthetic input — used while disabled or behind the virtual keyboard.
    func handleTouchpad(primary: TouchpadTouch,
                        secondary: TouchpadTouch,
                        now: CFAbsoluteTime,
                        synthesize: Bool) {
        var state = runtime.touchpad

        let fingerCount = (primary.isTouching ? 1 : 0) + (secondary.isTouching ? 1 : 0)
        let previousCount = state.fingerCount
        let countChanged = fingerCount != previousCount

        // Touch session begins.
        if previousCount == 0 && fingerCount > 0 {
            state.sessionStart = now
            state.startX = primary.x
            state.startY = primary.y
            state.accumulatedMovement = 0
            state.maxFingerCount = fingerCount
            state.gestureFired = false
        }
        state.maxFingerCount = max(state.maxFingerCount, fingerCount)

        if synthesize {
            switch currentProfile.touchpadMode {
            case .disabled:
                break

            case .trackpad(let sensitivity, let tapToClick, let twoFingerScroll, let naturalScroll):
                let bounds = CGDisplayBounds(CGMainDisplayID())
                // The first event after a touch begins (or after the finger
                // count changes) carries no meaningful delta — skip it.
                if fingerCount == 1, !countChanged,
                   let prev = state.prevPrimary, prev.isTouching, primary.isTouching {
                    let dxN = primary.x - prev.x
                    let dyN = primary.y - prev.y
                    state.accumulatedMovement += (dxN * dxN + dyN * dyN).squareRoot()
                    let dx = dxN * sensitivity * bounds.width
                    let dy = -dyN * sensitivity * bounds.width // pad up → pointer up
                    if dx != 0 || dy != 0 {
                        EventSynthesizer.moveMouse(dx: dx, dy: dy)
                    }
                } else if fingerCount == 2, twoFingerScroll, !countChanged,
                          let prevP = state.prevPrimary, prevP.isTouching,
                          let prevS = state.prevSecondary, prevS.isTouching {
                    let avgDx = ((primary.x - prevP.x) + (secondary.x - prevS.x)) / 2
                    let avgDy = ((primary.y - prevP.y) + (secondary.y - prevS.y)) / 2
                    state.accumulatedMovement += (avgDx * avgDx + avgDy * avgDy).squareRoot()
                    // Natural scrolling: content follows the fingers
                    // (fingers up → view scrolls down → negative wheel).
                    let sign: Double = naturalScroll ? -1 : 1
                    let scale = sensitivity * bounds.width * Constants.touchpadScrollScale
                    EventSynthesizer.scroll(dx: sign * avgDx * scale, dy: sign * avgDy * scale)
                }
                // Tap-to-click on release: short, nearly still touch.
                if fingerCount == 0, previousCount > 0, tapToClick {
                    let duration = now - state.sessionStart
                    if duration < Constants.tapMaxDuration
                        && state.accumulatedMovement < Constants.tapMaxMovement {
                        let button: MouseButtonAction = state.maxFingerCount >= 2 ? .rightClick : .leftClick
                        EventSynthesizer.mouseButton(button, phase: .down)
                        EventSynthesizer.mouseButton(button, phase: .up)
                    }
                }

            case .absolutePointer:
                if primary.isTouching {
                    let bounds = CGDisplayBounds(CGMainDisplayID())
                    // Map −1…+1 (y up) onto the main display (CG space, y down).
                    let px = bounds.origin.x + (primary.x + 1) / 2 * bounds.width
                    let py = bounds.origin.y + (1 - (primary.y + 1) / 2) * bounds.height
                    EventSynthesizer.moveMouse(to: CGPoint(x: px, y: py))
                }

            case .gestures:
                if fingerCount > 0, !state.gestureFired,
                   now - state.sessionStart <= Constants.gestureWindow {
                    let dx = primary.x - state.startX
                    let dy = primary.y - state.startY
                    if abs(dx) > Constants.gestureThreshold && abs(dx) >= abs(dy) {
                        state.gestureFired = true
                        // Content follows the finger: swiping left reveals the
                        // space on the right (⌃→), and vice versa.
                        EventSynthesizer.tap(dx < 0 ? Constants.spaceNextCombo
                                                    : Constants.spacePreviousCombo)
                    } else if dy > Constants.gestureThreshold {
                        state.gestureFired = true
                        executeSystemAction(.missionControl)
                    }
                }
            }
        }

        state.prevPrimary = primary
        state.prevSecondary = secondary
        state.fingerCount = fingerCount
        runtime.touchpad = state
    }

    // MARK: - Gyro

    /// Event-driven gyro processing. `runtime.gyroDt` (time between the two
    /// most recent samples, clamped) is maintained by `updateRawState`.
    func handleGyro(_ sample: GyroSample) {
        let dt = runtime.gyroDt
        guard dt > 0 else { return }

        switch currentProfile.gyroMode {
        case .disabled:
            return

        case .mousePointer(let sensitivity, let activationHold):
            // Only while the activation element (if any) is physically held.
            if let hold = activationHold, !runtime.pressedElements.contains(hold) {
                return
            }
            // GyroSample: x = pitch, y = yaw (rad/s). Yaw left / pitch up
            // move the pointer left / up (negative CG deltas).
            let scale = sensitivity * Constants.gyroPointerPixelsPerRadian * dt
            let dx = -sample.rotationY * scale
            let dy = -sample.rotationX * scale
            if abs(dx) > 0.001 || abs(dy) > 0.001 {
                EventSynthesizer.moveMouse(dx: dx, dy: dy)
            }

        case .scroll(let sensitivity):
            // Pitch up scrolls up (positive wheel delta).
            let dy = sample.rotationX * sensitivity * Constants.gyroScrollPixelsPerRadian * dt
            if abs(dy) > 0.001 {
                EventSynthesizer.scroll(dx: 0, dy: dy)
            }
        }
    }
}
