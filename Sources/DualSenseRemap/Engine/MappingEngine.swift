import Foundation
import Combine
import CoreGraphics

/// The heart of the app: routes controller events to actions and synthesizes
/// continuous input (pointer, scroll, keys) from analog controls.
///
/// Threading model:
/// - All event processing and runtime state (`runtime`, `currentProfile`)
///   live on the private serial `engineQueue`.
/// - A 120 Hz `Timer` on `RunLoop.main` (`.common` mode) drives the
///   continuous loop; each tick hops onto `engineQueue`.
/// - `isEnabled` / `start()` / `stop()` are thread-safe entry points.
///
/// L2/R2 policy (documented by design): the digital press reported by
/// GameController for L2/R2 is IGNORED for mappings. The `.l2`/`.r2` bindings
/// are driven exclusively by the analog trigger value crossing
/// `TriggerSettings.activationThreshold` (with 0.05 hysteresis). This gives
/// the user a tunable activation point and avoids double-firing when both the
/// digital edge and the threshold would trigger.
final class MappingEngine {

    static let shared = MappingEngine()

    // MARK: - Nested types (engine-queue only unless noted)

    /// Direction the arrow-keys stick mode is currently repeating.
    enum ArrowDirection {
        case up, down, left, right
    }

    /// Per-stick continuous-mode state.
    struct StickRuntime {
        var arrowDirection: ArrowDirection?
        var nextArrowRepeat: CFAbsoluteTime = 0
        /// Key codes currently held down by the ZQSD mode.
        var heldKeyCodes: Set<UInt16> = []
        /// -1 / 0 / +1 — current volume dial direction (vertical axis).
        var volumeDirection: Int = 0
        var nextVolumeStep: CFAbsoluteTime = 0
        /// -1 / 0 / +1 — current brightness dial direction (horizontal axis).
        var brightnessDirection: Int = 0
        var nextBrightnessStep: CFAbsoluteTime = 0
    }

    /// Touchpad session state.
    struct TouchpadRuntime {
        var prevPrimary: TouchpadTouch?
        var prevSecondary: TouchpadTouch?
        var fingerCount: Int = 0
        var sessionStart: CFAbsoluteTime = 0
        var startX: Double = 0
        var startY: Double = 0
        /// Total normalized travel of the touch session (tap detection).
        var accumulatedMovement: Double = 0
        var maxFingerCount: Int = 0
        var gestureFired: Bool = false
    }

    /// Full engine runtime state. Mutated only on `engineQueue`.
    struct Runtime {
        var leftStickX: Double = 0
        var leftStickY: Double = 0
        var rightStickX: Double = 0
        var rightStickY: Double = 0
        var leftTriggerValue: Double = 0
        var rightTriggerValue: Double = 0
        var leftTriggerEngaged = false
        var rightTriggerEngaged = false
        /// Physical digital elements currently pressed (includes l2/r2 so the
        /// gyro activation-hold can use any element).
        var pressedElements: Set<ControllerElement> = []
        /// Action executed on `.down` for each element, so the matching `.up`
        /// releases the SAME action even if the profile changed mid-press.
        var activeDownActions: [ControllerElement: Action] = [:]
        var leftStickRuntime = StickRuntime()
        var rightStickRuntime = StickRuntime()
        var touchpad = TouchpadRuntime()
        var lastGyroTime: CFAbsoluteTime?
        /// Seconds elapsed between the two most recent gyro samples (clamped).
        var gyroDt: Double = 0
        var lastTickTime: CFAbsoluteTime?
        var isConnected = false
    }

    /// Tuning constants for the whole engine.
    enum Constants {
        static let tickInterval: TimeInterval = 1.0 / 120.0
        static let triggerHysteresis = 0.05
        /// Arrow-keys mode: deflection past this repeats the arrow.
        static let arrowThreshold = 0.6
        static let defaultArrowRepeatInterval = 0.15
        /// ZQSD mode: enter/leave thresholds (hysteresis avoids chatter).
        static let wasdPressThreshold = 0.5
        static let wasdReleaseThreshold = 0.35
        /// Volume/brightness dial: step on crossing this deflection.
        static let dialThreshold = 0.7
        static let dialRepeatInterval = 0.25
        /// Approximate pixels per scroll "line" for stick scrolling.
        static let pixelsPerScrollLine = 10.0
        /// Touchpad tap-to-click limits.
        static let tapMaxDuration = 0.18
        static let tapMaxMovement = 0.02
        /// Touchpad gestures: normalized displacement + time window.
        static let gestureThreshold = 0.35
        static let gestureWindow = 0.30
        /// Two-finger scroll scale relative to pointer scale.
        static let touchpadScrollScale = 0.35
        static let gyroPointerPixelsPerRadian = 600.0
        static let gyroScrollPixelsPerRadian = 150.0
        static let profileSwitchPulseMs = 90

        // Arrow key combos (macOS virtual key codes).
        static let arrowLeftCombo = KeyCombo(keyCode: 123, modifiers: [], label: "←")
        static let arrowRightCombo = KeyCombo(keyCode: 124, modifiers: [], label: "→")
        static let arrowDownCombo = KeyCombo(keyCode: 125, modifiers: [], label: "↓")
        static let arrowUpCombo = KeyCombo(keyCode: 126, modifiers: [], label: "↑")

        // Spaces switching (default macOS shortcuts: ⌃← / ⌃→).
        static let spacePreviousCombo = KeyCombo(keyCode: 123, modifiers: [.control], label: "⌃←")
        static let spaceNextCombo = KeyCombo(keyCode: 124, modifiers: [.control], label: "⌃→")

        /// ZQSD held keys: ANSI key codes of the physical W/A/S/D positions,
        /// which produce Z/Q/S/D on the French AZERTY layout.
        /// kVK_ANSI_W = 13 → Z, kVK_ANSI_A = 0 → Q, kVK_ANSI_S = 1 → S,
        /// kVK_ANSI_D = 2 → D.
        static let zqsdUpKeyCode: UInt16 = 13    // Z
        static let zqsdLeftKeyCode: UInt16 = 0   // Q
        static let zqsdDownKeyCode: UInt16 = 1   // S
        static let zqsdRightKeyCode: UInt16 = 2  // D
        static let zqsdLabels: [UInt16: String] = [13: "Z", 0: "Q", 1: "S", 2: "D"]
    }

    // MARK: - Thread-safe control surface

    private let controlLock = NSLock()
    private var enabledStorage = true
    private var startedStorage = false

    /// Global kill-switch (menu bar). When turned off, every held synthetic
    /// output (keys, in-flight actions) is released immediately.
    var isEnabled: Bool {
        get {
            controlLock.lock(); defer { controlLock.unlock() }
            return enabledStorage
        }
        set {
            controlLock.lock()
            let changed = enabledStorage != newValue
            enabledStorage = newValue
            controlLock.unlock()
            if changed && !newValue {
                engineQueue.async { [weak self] in self?.releaseEverything() }
            }
        }
    }

    var isStarted: Bool {
        controlLock.lock(); defer { controlLock.unlock() }
        return startedStorage
    }

    // MARK: - Engine state

    /// Serial queue owning all runtime state.
    let engineQueue = DispatchQueue(label: "com.dualsenseremap.engine", qos: .userInteractive)

    /// Engine-queue copy of the active profile (kept fresh via Combine).
    var currentProfile = Profile.defaultProfile()
    var hasReceivedProfile = false

    /// All mutable continuous state — engine-queue only.
    var runtime = Runtime()

    private var eventCancellable: AnyCancellable?
    private var profileCancellable: AnyCancellable?
    /// Main-thread only.
    private var continuousTimer: Timer?

    private init() {}

    // MARK: - Lifecycle

    func start() {
        controlLock.lock()
        if startedStorage {
            controlLock.unlock()
            return
        }
        startedStorage = true
        controlLock.unlock()

        // Route every controller event through the serial engine queue.
        eventCancellable = DualSenseManager.shared.events
            .receive(on: engineQueue)
            .sink { [weak self] event in
                self?.processEvent(event)
            }

        // Keep an engine-queue copy of the active profile; push feedback
        // (lightbar, adaptive triggers, haptic pulse) on activation.
        profileCancellable = Publishers.CombineLatest(ProfileStore.shared.$profiles, ProfileStore.shared.$activeProfileID)
            .map { profiles, activeID -> Profile in
                if let id = activeID, let match = profiles.first(where: { $0.id == id }) {
                    return match
                }
                return profiles.first ?? Profile.defaultProfile()
            }
            .receive(on: engineQueue)
            .sink { [weak self] profile in
                self?.profileDidChange(to: profile)
            }

        // 120 Hz continuous loop. A plain Timer in .common mode keeps firing
        // during window drags/menus; each tick hops onto the engine queue.
        // (CVDisplayLink would be a lower-jitter upgrade — see report.)
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isStarted, self.continuousTimer == nil else { return }
            let timer = Timer(timeInterval: Constants.tickInterval, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.engineQueue.async { self.tick() }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.continuousTimer = timer
        }
    }

    func stop() {
        controlLock.lock()
        guard startedStorage else {
            controlLock.unlock()
            return
        }
        startedStorage = false
        controlLock.unlock()

        eventCancellable?.cancel()
        eventCancellable = nil
        profileCancellable?.cancel()
        profileCancellable = nil

        DispatchQueue.main.async { [weak self] in
            self?.continuousTimer?.invalidate()
            self?.continuousTimer = nil
        }
        engineQueue.async { [weak self] in
            self?.releaseEverything()
        }
    }

    // MARK: - Event pipeline (engine queue)

    func processEvent(_ event: ControllerEvent) {
        let now = CFAbsoluteTimeGetCurrent()
        updateRawState(for: event, at: now)

        switch event {
        case .connected:
            runtime.isConnected = true
            // Push the active profile's feedback to the freshly connected
            // controller (lightbar + adaptive triggers, no haptic pulse).
            applyProfileFeedback(currentProfile, playSwitchPulse: false)
            return
        case .disconnected:
            runtime.isConnected = false
            releaseEverything()
            resetRuntime()
            return
        case .battery:
            return
        default:
            break
        }

        // The virtual keyboard has priority over all mappings while visible.
        // (isCurrentlyVisible is the lock-guarded mirror — this runs on the
        // engine queue, not the main thread.)
        if VirtualKeyboardController.shared.isCurrentlyVisible,
           VirtualKeyboardController.shared.handle(event) {
            // Consumed by the keyboard. Still process "release" edges so no
            // synthetic key/click stays stuck behind the keyboard overlay.
            processReleaseOnly(event, at: now)
            return
        }

        guard isEnabled else {
            processReleaseOnly(event, at: now)
            return
        }

        switch event {
        case .buttonDown(let element):
            handleButtonDown(element)
        case .buttonUp(let element):
            releaseInFlightAction(for: element)
        case .leftTrigger(let value):
            processTrigger(side: .left, value: value, allowActivation: true)
        case .rightTrigger(let value):
            processTrigger(side: .right, value: value, allowActivation: true)
        case .touchpad(let primary, let secondary):
            handleTouchpad(primary: primary, secondary: secondary, now: now, synthesize: true)
        case .gyro(let sample):
            handleGyro(sample)
        case .leftStick, .rightStick:
            break // integrated by the 120 Hz continuous loop from raw state
        case .connected, .disconnected, .battery:
            break // handled above
        }
    }

    /// Raw state bookkeeping that must run for EVERY event, even when the
    /// virtual keyboard consumes it or the engine is disabled — so nothing is
    /// stale when normal processing resumes.
    private func updateRawState(for event: ControllerEvent, at now: CFAbsoluteTime) {
        switch event {
        case .leftStick(let x, let y):
            runtime.leftStickX = x
            runtime.leftStickY = y
        case .rightStick(let x, let y):
            runtime.rightStickX = x
            runtime.rightStickY = y
        case .leftTrigger(let value):
            runtime.leftTriggerValue = value
        case .rightTrigger(let value):
            runtime.rightTriggerValue = value
        case .buttonDown(let element):
            runtime.pressedElements.insert(element)
        case .buttonUp(let element):
            runtime.pressedElements.remove(element)
        case .gyro:
            let last = runtime.lastGyroTime
            runtime.lastGyroTime = now
            runtime.gyroDt = last.map { min(max(now - $0, 0), 0.05) } ?? 0
        case .connected, .disconnected, .battery, .touchpad:
            break
        }
    }

    /// Release-only processing used while the keyboard consumes events or the
    /// engine is disabled: never starts a new action, only ends held ones and
    /// keeps touch-session tracking coherent.
    private func processReleaseOnly(_ event: ControllerEvent, at now: CFAbsoluteTime) {
        switch event {
        case .buttonUp(let element):
            releaseInFlightAction(for: element)
        case .leftTrigger(let value):
            processTrigger(side: .left, value: value, allowActivation: false)
        case .rightTrigger(let value):
            processTrigger(side: .right, value: value, allowActivation: false)
        case .touchpad(let primary, let secondary):
            handleTouchpad(primary: primary, secondary: secondary, now: now, synthesize: false)
        default:
            break
        }
    }

    // MARK: - Digital edges

    private func handleButtonDown(_ element: ControllerElement) {
        // L2/R2 mappings are driven exclusively by the analog threshold in
        // processTrigger(side:value:allowActivation:) — see class doc.
        guard element != .l2, element != .r2 else { return }
        let action = currentProfile.action(for: element)
        if case .none = action { return }
        runtime.activeDownActions[element] = action
        ActionExecutor.shared.execute(action, phase: .down)
    }

    /// Executes the `.up` phase of the action captured at `.down` time (NOT
    /// the current profile's action), so a mid-press profile switch can never
    /// leave a key or mouse button stuck.
    func releaseInFlightAction(for element: ControllerElement) {
        guard let action = runtime.activeDownActions.removeValue(forKey: element) else { return }
        ActionExecutor.shared.execute(action, phase: .up)
    }

    // MARK: - Analog triggers → synthetic L2/R2 edges

    /// Threshold + 0.05 hysteresis state machine generating the synthetic
    /// digital edges for the `.l2` / `.r2` bindings.
    func processTrigger(side: TriggerSide, value: Double, allowActivation: Bool) {
        let element: ControllerElement
        let settings: TriggerSettings
        let engaged: Bool
        switch side {
        case .left:
            element = .l2
            settings = currentProfile.leftTrigger
            engaged = runtime.leftTriggerEngaged
        case .right:
            element = .r2
            settings = currentProfile.rightTrigger
            engaged = runtime.rightTriggerEngaged
        }
        let threshold = min(max(settings.activationThreshold, 0.02), 0.98)

        if !engaged {
            guard allowActivation, value >= threshold else { return }
            setTriggerEngaged(side, true)
            let action = currentProfile.action(for: element)
            if case .none = action { return }
            runtime.activeDownActions[element] = action
            ActionExecutor.shared.execute(action, phase: .down)
        } else if value <= max(0, threshold - Constants.triggerHysteresis) {
            setTriggerEngaged(side, false)
            releaseInFlightAction(for: element)
        }
    }

    private func setTriggerEngaged(_ side: TriggerSide, _ engaged: Bool) {
        switch side {
        case .left: runtime.leftTriggerEngaged = engaged
        case .right: runtime.rightTriggerEngaged = engaged
        }
    }

    // MARK: - Profile changes & feedback push

    private func profileDidChange(to profile: Profile) {
        let previous = currentProfile
        let isInitial = !hasReceivedProfile
        hasReceivedProfile = true
        currentProfile = profile

        if isInitial {
            // Restore feedback silently at launch when already connected.
            if runtime.isConnected {
                applyProfileFeedback(profile, playSwitchPulse: false)
            }
            return
        }

        if profile.id != previous.id {
            // Real profile switch: push feedback + short haptic confirmation.
            applyProfileFeedback(profile, playSwitchPulse: true)
        } else if profile.lightbar != previous.lightbar
            || profile.leftTrigger.adaptiveEffect != previous.leftTrigger.adaptiveEffect
            || profile.rightTrigger.adaptiveEffect != previous.rightTrigger.adaptiveEffect {
            // Live edit of the active profile's feedback settings.
            applyProfileFeedback(profile, playSwitchPulse: false)
        }
    }

    /// Pushes lightbar color and adaptive trigger effects to the controller;
    /// optionally plays the profile-switch haptic pulse.
    func applyProfileFeedback(_ profile: Profile, playSwitchPulse: Bool) {
        let manager = DualSenseManager.shared
        if profile.lightbar.followsProfile {
            manager.setLightbar(red: profile.lightbar.red,
                                green: profile.lightbar.green,
                                blue: profile.lightbar.blue)
        }
        manager.setAdaptiveTrigger(.left, effect: profile.leftTrigger.adaptiveEffect)
        manager.setAdaptiveTrigger(.right, effect: profile.rightTrigger.adaptiveEffect)
        // Gyro sensors stream only while the active profile needs them
        // (saves controller battery). The tuning UI also toggles this live.
        if case .disabled = profile.gyroMode {
            manager.setGyroActive(false)
        } else {
            manager.setGyroActive(true)
        }
        if playSwitchPulse && profile.haptics.enabled {
            manager.playHapticPulse(intensity: profile.haptics.intensity,
                                    durationMs: Constants.profileSwitchPulseMs)
        }
    }

    // MARK: - Cleanup

    /// Releases every synthetic output the engine is currently holding:
    /// in-flight down actions, engaged triggers, and continuous-mode keys.
    func releaseEverything() {
        for (_, action) in runtime.activeDownActions {
            ActionExecutor.shared.execute(action, phase: .up)
        }
        runtime.activeDownActions.removeAll()
        runtime.leftTriggerEngaged = false
        runtime.rightTriggerEngaged = false
        releaseContinuousHolds()
    }

    /// Resets all continuous input state after a disconnect.
    func resetRuntime() {
        runtime.leftStickX = 0
        runtime.leftStickY = 0
        runtime.rightStickX = 0
        runtime.rightStickY = 0
        runtime.leftTriggerValue = 0
        runtime.rightTriggerValue = 0
        runtime.pressedElements.removeAll()
        runtime.touchpad = TouchpadRuntime()
        runtime.lastGyroTime = nil
        runtime.gyroDt = 0
    }

    // MARK: - Shared helpers

    /// Fires a one-shot system action (down + up) through the executor.
    func executeSystemAction(_ action: SystemAction) {
        ActionExecutor.shared.execute(.system(action), phase: .down)
        ActionExecutor.shared.execute(.system(action), phase: .up)
    }
}
