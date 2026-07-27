import Foundation
import Combine

/// Focus movement direction.
enum VKDirection: Equatable {
    case up, down, left, right
}

/// Interaction model of the virtual keyboard. All methods and all `@Published`
/// mutations run on the main thread — `VirtualKeyboardController.handle(_:)`
/// dispatches controller events here via `DispatchQueue.main.async`.
final class VKModel: ObservableObject {

    // MARK: Published state (observed by VKKeyboardView)

    @Published private(set) var pageID: VKPageID = .letters
    @Published private(set) var shift: VKShiftState = .off
    @Published private(set) var focus = VKPosition(row: 2, col: 5)
    @Published private(set) var pressedKeyID: String?
    /// Render scale applied by the hosting panel (from AppSettings).
    @Published var scale: Double = 1.0

    /// Set by VirtualKeyboardController — invoked when ○ / OK asks to close.
    var onDismiss: (() -> Void)?

    var grid: VKPage { VKLayout.page(pageID) }

    var focusedKey: VKKey {
        let grid = self.grid
        let row = min(max(focus.row, 0), grid.count - 1)
        let col = min(max(focus.col, 0), grid[row].count - 1)
        return grid[row][col]
    }

    // MARK: Timing constants

    private enum VKTiming {
        static let moveInitialDelay: TimeInterval = 0.35
        static let moveRepeatInterval: TimeInterval = 0.08
        static let activateInitialDelay: TimeInterval = 0.40
        static let activateRepeatInterval: TimeInterval = 0.09
        static let shiftDoubleTapWindow: TimeInterval = 0.35
        static let stickEngageThreshold: Double = 0.5
        static let stickReleaseThreshold: Double = 0.35
        static let pressFlashDuration: TimeInterval = 0.12
    }

    // MARK: Private interaction state

    private enum VKMoveSource: Equatable { case dpad, stick }

    private var moveDirection: VKDirection?
    private var moveSource: VKMoveSource?
    private var moveTimer: Timer?

    private var stickDirection: VKDirection?

    private var crossHeld = false
    private var activateRepeatTimer: Timer?
    private var repeatingKeyID: String?

    private var l2Held = false
    private var l2DownTime: CFAbsoluteTime = 0
    private var lastL2TapDownTime: CFAbsoluteTime = -.greatestFiniteMagnitude
    private var l2EngagedShift = false

    private var pageBeforeAccents: VKPageID = .letters
    /// Column memory: preferred horizontal center (in width units) preserved
    /// across vertical moves so ↓↓↑↑ returns to the original key.
    private var preferredCenterX: Double?
    private var pressGeneration = 0

    // MARK: Lifecycle hooks (called by VirtualKeyboardController, main thread)

    func prepareForShow() {
        cancelAllRepeats()
        pressedKeyID = nil
        crossHeld = false
        l2Held = false
        l2EngagedShift = false
        stickDirection = nil
        if shift == .once { shift = .off }
    }

    func prepareForHide() {
        cancelAllRepeats()
        pressedKeyID = nil
        crossHeld = false
        l2Held = false
        l2EngagedShift = false
        stickDirection = nil
    }

    // MARK: Event entry point (main thread)

    func process(_ event: ControllerEvent) {
        switch event {
        case .buttonDown(let element):
            handleButtonDown(element)
        case .buttonUp(let element):
            handleButtonUp(element)
        case .leftStick(let x, let y):
            handleStick(x: x, y: y)
        default:
            // Right stick, triggers, touchpad, gyro: consumed but unused in v1.
            break
        }
    }

    // MARK: Buttons

    private func handleButtonDown(_ element: ControllerElement) {
        switch element {
        case .dpadUp: beginMove(.up, source: .dpad)
        case .dpadDown: beginMove(.down, source: .dpad)
        case .dpadLeft: beginMove(.left, source: .dpad)
        case .dpadRight: beginMove(.right, source: .dpad)
        case .cross: crossDown()
        case .circle: dismiss()
        case .triangle: pressFunction(.space)
        case .square: pressFunction(.backspace)
        case .l2: l2Down()
        case .l1: pressFunction(.cursorLeft)
        case .r1: pressFunction(.cursorRight)
        case .r3: pressFunction(.layerAccents)
        case .r2: pressFunction(.done)
        case .options:
            break // consumed, no-op in v1
        default:
            break // fully modal: everything else is consumed silently
        }
    }

    private func handleButtonUp(_ element: ControllerElement) {
        switch element {
        case .dpadUp: endMove(.up, source: .dpad)
        case .dpadDown: endMove(.down, source: .dpad)
        case .dpadLeft: endMove(.left, source: .dpad)
        case .dpadRight: endMove(.right, source: .dpad)
        case .cross: crossUp()
        case .l2: l2Up()
        default:
            break
        }
    }

    // MARK: Focus movement (d-pad + left stick, shared repeat machinery)

    private func beginMove(_ direction: VKDirection, source: VKMoveSource) {
        // The d-pad has priority over the stick; a new d-pad press retargets.
        if source == .stick, moveSource == .dpad { return }
        moveTimer?.invalidate()
        moveDirection = direction
        moveSource = source
        moveFocus(direction)
        moveTimer = Timer.scheduledTimer(
            withTimeInterval: VKTiming.moveInitialDelay,
            repeats: false
        ) { [weak self] _ in
            self?.startMoveRepeat()
        }
    }

    private func startMoveRepeat() {
        moveTimer?.invalidate()
        guard moveDirection != nil else { return }
        moveTimer = Timer.scheduledTimer(
            withTimeInterval: VKTiming.moveRepeatInterval,
            repeats: true
        ) { [weak self] _ in
            guard let self, let direction = self.moveDirection else { return }
            self.moveFocus(direction)
        }
    }

    private func endMove(_ direction: VKDirection, source: VKMoveSource) {
        guard moveDirection == direction, moveSource == source else { return }
        cancelMove()
    }

    private func cancelMove() {
        moveTimer?.invalidate()
        moveTimer = nil
        moveDirection = nil
        moveSource = nil
    }

    private func moveFocus(_ direction: VKDirection) {
        let grid = self.grid
        var position = focus
        switch direction {
        case .left, .right:
            let row = grid[position.row]
            let delta = direction == .left ? -1 : 1
            position.col = (position.col + delta + row.count) % row.count
            preferredCenterX = VKLayout.center(ofCol: position.col, inRow: row)
        case .up, .down:
            let newRow = position.row + (direction == .up ? -1 : 1)
            guard newRow >= 0, newRow < grid.count else { return } // clamped
            let target = preferredCenterX
                ?? VKLayout.center(ofCol: position.col, inRow: grid[position.row])
            preferredCenterX = target
            position.row = newRow
            position.col = VKLayout.nearestCol(toCenter: target, inRow: grid[newRow])
        }
        guard position != focus else { return }
        focus = position
        cancelActivationRepeat() // never keep repeating a key focus just left
        hapticTick(base: 0.25)
    }

    // MARK: Stick with hysteresis

    private func handleStick(x: Double, y: Double) {
        if let engaged = stickDirection {
            let along = axisMagnitude(of: engaged, x: x, y: y)
            if along < VKTiming.stickReleaseThreshold {
                stickDirection = nil
                endMove(engaged, source: .stick)
                // Re-engage immediately if the other axis is already past threshold.
                if let fresh = dominantDirection(x: x, y: y) {
                    stickDirection = fresh
                    beginMove(fresh, source: .stick)
                }
            } else if let fresh = dominantDirection(x: x, y: y), fresh != engaged {
                stickDirection = fresh
                beginMove(fresh, source: .stick)
            }
        } else if let fresh = dominantDirection(x: x, y: y) {
            stickDirection = fresh
            beginMove(fresh, source: .stick)
        }
    }

    /// Dominant direction when its axis exceeds the engage threshold.
    private func dominantDirection(x: Double, y: Double) -> VKDirection? {
        if abs(x) >= abs(y) {
            guard abs(x) > VKTiming.stickEngageThreshold else { return nil }
            return x > 0 ? .right : .left
        } else {
            guard abs(y) > VKTiming.stickEngageThreshold else { return nil }
            // GameController convention: +y is up.
            return y > 0 ? .up : .down
        }
    }

    private func axisMagnitude(of direction: VKDirection, x: Double, y: Double) -> Double {
        switch direction {
        case .left: return max(0, -x)
        case .right: return max(0, x)
        case .up: return max(0, y)
        case .down: return max(0, -y)
        }
    }

    // MARK: ✕ activation + key repeat

    private func crossDown() {
        crossHeld = true
        let key = focusedKey
        activate(key)
        if key.isRepeatable {
            scheduleActivationRepeat(for: key)
        }
    }

    private func crossUp() {
        crossHeld = false
        cancelActivationRepeat()
    }

    private func scheduleActivationRepeat(for key: VKKey) {
        activateRepeatTimer?.invalidate()
        repeatingKeyID = key.id
        activateRepeatTimer = Timer.scheduledTimer(
            withTimeInterval: VKTiming.activateInitialDelay,
            repeats: false
        ) { [weak self] _ in
            self?.startActivationRepeat()
        }
    }

    private func startActivationRepeat() {
        activateRepeatTimer?.invalidate()
        guard crossHeld, repeatingKeyID != nil else { return }
        activateRepeatTimer = Timer.scheduledTimer(
            withTimeInterval: VKTiming.activateRepeatInterval,
            repeats: true
        ) { [weak self] _ in
            guard let self, self.crossHeld,
                  let id = self.repeatingKeyID,
                  self.focusedKey.id == id else {
                self?.cancelActivationRepeat()
                return
            }
            self.activate(self.focusedKey)
        }
    }

    private func cancelActivationRepeat() {
        activateRepeatTimer?.invalidate()
        activateRepeatTimer = nil
        repeatingKeyID = nil
    }

    private func cancelAllRepeats() {
        cancelMove()
        cancelActivationRepeat()
    }

    // MARK: Direct function buttons (△ □ L1 R1 R2 R3)

    /// Activates the on-grid key carrying `special` (so the UI flashes it),
    /// falling back to the bare action when the key is not on screen.
    private func pressFunction(_ special: VKSpecial) {
        if let key = functionKey(special) {
            activate(key)
        } else {
            performSpecial(special)
        }
    }

    private func functionKey(_ special: VKSpecial) -> VKKey? {
        for row in [VKLayout.functionRow, VKLayout.bottomRow] {
            if let key = row.first(where: { $0.special == special }) {
                return key
            }
        }
        return nil
    }

    // MARK: Mouse path (panel is non-activating; clicks share the same path)

    func mouseActivate(at position: VKPosition) {
        let grid = self.grid
        guard position.row >= 0, position.row < grid.count,
              position.col >= 0, position.col < grid[position.row].count else { return }
        focus = position
        preferredCenterX = VKLayout.center(ofCol: position.col, inRow: grid[position.row])
        activate(grid[position.row][position.col])
    }

    // MARK: Activation + output

    private func activate(_ key: VKKey) {
        flash(key)
        hapticTick(base: 0.5)
        switch key.kind {
        case .character(let lower, let upper):
            EventSynthesizer.typeText(shift.isActive ? upper : lower)
            clearOneShotShiftAfterLetter()
        case .symbol(let s):
            EventSynthesizer.typeText(s)
        case .special(let special):
            performSpecial(special)
        }
    }

    private func performSpecial(_ special: VKSpecial) {
        switch special {
        case .shift:
            cycleShiftFromKeyPress()
        case .backspace:
            EventSynthesizer.tap(KeyCombo(keyCode: 51, modifiers: [], label: "⌫"))
        case .space:
            EventSynthesizer.typeText(" ")
        case .enter:
            EventSynthesizer.tap(KeyCombo(keyCode: 36, modifiers: [], label: "⏎"))
        case .layerABC:
            setPage(.letters)
        case .layerSymbols:
            switch pageID {
            case .symbols1: setPage(.symbols2)
            case .symbols2: setPage(.symbols1)
            default: setPage(.symbols1)
            }
        case .layerAccents:
            toggleAccentsPage()
        case .cursorLeft:
            EventSynthesizer.tap(KeyCombo(keyCode: 123, modifiers: [], label: "←"))
        case .cursorRight:
            EventSynthesizer.tap(KeyCombo(keyCode: 124, modifiers: [], label: "→"))
        case .options:
            break // reserved (options popover is out of scope for v1)
        case .controllerHint:
            break // informational key, mirrors the PS5 L3+R3 hint
        case .done:
            dismiss() // Done: close WITHOUT sending Return
        }
    }

    private func dismiss() {
        cancelAllRepeats()
        onDismiss?()
    }

    // MARK: Pages

    private func setPage(_ id: VKPageID) {
        guard pageID != id else { return }
        pageID = id
        // One-shot shift auto-reverts on layer change.
        if shift == .once, !l2Held { shift = .off }
        clampFocusToGrid()
    }

    private func toggleAccentsPage() {
        if pageID == .accents {
            setPage(pageBeforeAccents)
        } else {
            pageBeforeAccents = pageID
            setPage(.accents)
        }
    }

    private func clampFocusToGrid() {
        let grid = self.grid
        var position = focus
        position.row = min(max(position.row, 0), grid.count - 1)
        position.col = min(max(position.col, 0), grid[position.row].count - 1)
        focus = position
    }

    // MARK: Shift state machine (L2 + on-screen ⇧ key)

    /// On-screen ⇧ key press: off → once → caps → off.
    private func cycleShiftFromKeyPress() {
        switch shift {
        case .off: shift = .once
        case .once: shift = .caps
        case .caps: shift = .off
        }
    }

    private func l2Down() {
        let now = CFAbsoluteTimeGetCurrent()
        l2Held = true
        l2DownTime = now
        if let key = functionKey(.shift) { flash(key) }

        // Double-tap within the window while one-shot is armed → caps lock.
        if shift == .once, now - lastL2TapDownTime <= VKTiming.shiftDoubleTapWindow {
            shift = .caps
            l2EngagedShift = false
            lastL2TapDownTime = -.greatestFiniteMagnitude
            return
        }

        switch shift {
        case .off:
            shift = .once
            l2EngagedShift = true
            lastL2TapDownTime = now
        case .once, .caps:
            shift = .off
            l2EngagedShift = false
            lastL2TapDownTime = -.greatestFiniteMagnitude
        }
    }

    private func l2Up() {
        let now = CFAbsoluteTimeGetCurrent()
        l2Held = false
        // Held longer than a tap → momentary shift (hardware-Shift style):
        // revert on release. A short tap leaves the one-shot armed.
        if l2EngagedShift, now - l2DownTime > VKTiming.shiftDoubleTapWindow {
            if shift == .once { shift = .off }
        }
        l2EngagedShift = false
    }

    /// One-shot shift clears after a single letter — unless L2 is physically
    /// held (momentary shift stays active until release).
    private func clearOneShotShiftAfterLetter() {
        if shift == .once, !l2Held { shift = .off }
    }

    // MARK: Press flash

    private func flash(_ key: VKKey) {
        pressGeneration += 1
        let generation = pressGeneration
        pressedKeyID = key.id
        DispatchQueue.main.asyncAfter(deadline: .now() + VKTiming.pressFlashDuration) { [weak self] in
            guard let self, self.pressGeneration == generation else { return }
            self.pressedKeyID = nil
        }
    }

    // MARK: Haptics

    /// Subtle controller tick, gated by the app setting and scaled by the
    /// active profile's haptic intensity.
    private func hapticTick(base: Double) {
        guard ProfileStore.shared.settings.keyboardHapticFeedback else { return }
        let profileScale = ProfileStore.shared.activeProfile.haptics.intensity
        let intensity = max(0, min(1, base * profileScale))
        guard intensity > 0 else { return }
        DualSenseManager.shared.playHapticPulse(intensity: intensity, durationMs: 12)
    }
}
