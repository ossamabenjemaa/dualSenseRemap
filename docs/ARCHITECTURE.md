# DualSense Remap — Architecture

macOS app (SwiftUI, macOS 13+) that turns a PS5 DualSense controller into a full
macOS input device: remapping, mouse/scroll from sticks, touchpad-as-trackpad,
gyro pointing, adaptive triggers, lightbar, haptics, per-app profiles,
Hammerspoon integration, and a PS5-style AZERTY virtual keyboard.

Built as a SwiftPM executable (single target `DualSenseRemap`) bundled into a
`.app` by `Scripts/bundle.sh` / `make app`. No Xcode project required
(`project.yml` provided for XcodeGen users).

## Module map

```
Sources/DualSenseRemap/
├── Core/            Shared domain models (OWNED BY THE ARCHITECT — do not edit)
│   ├── ControllerElement.swift   All physical controls
│   ├── Action.swift              Action, KeyCombo, SystemAction, MacroStep…
│   ├── AnalogModes.swift         StickMode, TouchpadMode, TriggerSettings, GyroMode…
│   ├── Profile.swift             Profile, AppSettings, built-in profiles
│   └── ControllerEvents.swift    ControllerEvent, ControllerSnapshot, TouchpadTouch…
├── Input/           GameController + IOHID bridge to the DualSense
├── Engine/          Mapping engine, profile store, per-app watcher
├── Output/          CGEvent synthesis, system actions, Hammerspoon, permissions
├── VirtualKeyboard/ PS5-style AZERTY on-screen keyboard
├── UI/              Main window (Logi Options+-style), design system
└── App/             @main entry, composition root, menu bar, onboarding
```

Data flow:

```
DualSense ──GameController/IOHID──▶ Input.DualSenseManager
                                        │ events: PassthroughSubject<ControllerEvent, Never>
                                        │ snapshot: @Published ControllerSnapshot (UI live view)
                                        ▼
                              Engine.MappingEngine ──(keyboard visible?)──▶ VirtualKeyboardController.handle(_:)
                                        │
                                        ▼ Action / continuous values
                              Output.ActionExecutor / EventSynthesizer ──CGEvent──▶ macOS
                                        │
                                        └──▶ Output.HammerspoonBridge ──hammerspoon:// URL──▶ Hammerspoon
```

## Public contracts between modules

Each module MUST expose exactly these public entry points (internal helpers are
free). All `@Published` mutations happen on the main thread. Combine is used for
event plumbing.

### Input — `DualSenseManager`

```swift
enum TriggerSide { case left, right }

final class DualSenseManager: ObservableObject {
    static let shared: DualSenseManager
    @Published private(set) var snapshot: ControllerSnapshot
    let events: PassthroughSubject<ControllerEvent, Never>
    func start()                       // begin discovery + wireless browsing
    func stop()
    func setLightbar(red: Double, green: Double, blue: Double)
    func setAdaptiveTrigger(_ side: TriggerSide, effect: AdaptiveTriggerEffect)
    func playHapticPulse(intensity: Double, durationMs: Int)
    func setPlayerIndicatorLights(_ index: Int)
}
```

Implementation notes: GameController framework (`GCController`,
`GCDualSenseGamepad` incl. `touchpadButton`, `touchpadPrimary`,
`touchpadSecondary`, `GCDualSenseAdaptiveTrigger`, `GCDeviceLight`,
`GCDeviceBattery`, `GCMotion`, haptics engine via `GCDeviceHaptics`).
The mute button is NOT exposed by GameController — an IOHIDManager listener
(vendor 0x054C, product 0x0CE6) provides it; it degrades gracefully when Input
Monitoring permission is missing. Button edges are emitted as
`.buttonDown/.buttonUp` events; continuous values as their dedicated cases.

### Engine — `ProfileStore`, `MappingEngine`, `AppWatcher`

```swift
final class ProfileStore: ObservableObject {
    static let shared: ProfileStore
    @Published var profiles: [Profile]
    @Published var activeProfileID: UUID?
    @Published var settings: AppSettings
    var activeProfile: Profile { get }        // falls back to first / default
    func save()                               // JSON in ~/Library/Application Support/DualSenseRemap/
    func addProfile(_ profile: Profile)
    func updateProfile(_ profile: Profile)
    func deleteProfile(id: UUID)
    func activateProfile(id: UUID)
    func cycleProfile()
    func profile(forApp bundleID: String) -> Profile?
}

final class MappingEngine {
    static let shared: MappingEngine
    var isEnabled: Bool                       // global kill-switch (menu bar)
    func start()                              // subscribes to DualSenseManager.shared.events
    func stop()
}

final class AppWatcher {
    static let shared: AppWatcher
    func start()                              // NSWorkspace.didActivateApplicationNotification
}
```

MappingEngine responsibilities: route button edges to
`ActionExecutor.shared.execute(_:phase:)`; run the continuous loop (Timer or
CVDisplayLink at ~120 Hz) applying `StickMode` / `TouchpadMode` / `GyroMode`
via `EventSynthesizer`; apply trigger thresholds; while
`VirtualKeyboardController.shared.isVisible`, forward ALL events to
`VirtualKeyboardController.shared.handle(_:)` first and only execute a mapping
if it returns `false`; on profile activation, push lightbar color and adaptive
trigger effects to `DualSenseManager`.

### Output — `EventSynthesizer`, `ActionExecutor`, `HammerspoonBridge`, `PermissionsManager`

```swift
enum ActionPhase { case down, up }

enum EventSynthesizer {
    static func tap(_ combo: KeyCombo)
    static func post(_ combo: KeyCombo, down: Bool)
    static func typeText(_ text: String)          // unicode injection, layout-independent
    static func moveMouse(dx: Double, dy: Double)
    static func moveMouse(to point: CGPoint)
    static func mouseButton(_ action: MouseButtonAction, phase: ActionPhase)
    static func scroll(dx: Double, dy: Double)    // pixel-precise
    static func mediaKey(_ key: MediaKey, down: Bool)  // NX_KEYTYPE_* via NSEvent
}

final class ActionExecutor {
    static let shared: ActionExecutor
    func execute(_ action: Action, phase: ActionPhase)
}

final class HammerspoonBridge {
    static let shared: HammerspoonBridge
    var isInstalled: Bool { get }
    @discardableResult
    func trigger(_ event: String, params: [String: String]) -> Bool // false → caller falls back to native
}

final class PermissionsManager: ObservableObject {
    static let shared: PermissionsManager
    @Published private(set) var accessibilityGranted: Bool
    @Published private(set) var inputMonitoringGranted: Bool
    func refresh()
    func promptAccessibility()                  // AXIsProcessTrustedWithOptions with prompt
    func openSystemSettings(pane: PermissionPane) // enum PermissionPane { accessibility, inputMonitoring }
}
```

### VirtualKeyboard — `VirtualKeyboardController`

```swift
final class VirtualKeyboardController: ObservableObject {
    static let shared: VirtualKeyboardController
    @Published private(set) var isVisible: Bool
    func show()
    func hide()
    func toggle()
    /// Consumes controller events while visible. Returns true when consumed.
    func handle(_ event: ControllerEvent) -> Bool
}
```

PS5-style AZERTY keyboard in a **non-activating** `NSPanel`
(`.nonactivatingPanel`, level `.statusBar`, `hidesOnDeactivate = false`) so the
target app keeps keyboard focus; characters are delivered with
`EventSynthesizer.typeText`. Controller mapping mirrors the PS5 OSK: d-pad/left
stick = focus, ✕ = press, ○ = close, △ = space, □ = backspace, L2 = shift,
L1/R1 = move text cursor, R3 = accents page, R2 = validate (sends Return —
default-on module preference `sendReturnOnDone`) + close. Touchpad/gyro events
are consumed but unused while the keyboard is visible (the spec'd touchpad
fast-row-jump is not implemented in v1).

### UI + App

`App/DualSenseRemapApp.swift` is the `@main` entry (SwiftUI `App`): a main
`Window` + `MenuBarExtra`. `AppCoordinator` is the composition root that calls
`start()` on DualSenseManager, MappingEngine, AppWatcher and refreshes
PermissionsManager. UI observes the singletons listed above and never talks to
GameController/CGEvent directly.

## Directory ownership (parallel development)

| Area | Owner agent | Paths |
|---|---|---|
| Domain models | architect (done) | `Sources/DualSenseRemap/Core/**` |
| Input | dev-input | `Sources/DualSenseRemap/Input/**` |
| Engine | dev-engine | `Sources/DualSenseRemap/Engine/**` |
| Output | dev-output | `Sources/DualSenseRemap/Output/**`, `Hammerspoon/**` |
| Virtual keyboard | dev-keyboard | `Sources/DualSenseRemap/VirtualKeyboard/**` |
| UI + App | dev-ui | `Sources/DualSenseRemap/UI/**`, `Sources/DualSenseRemap/App/**` |
| Infra & docs | dev-infra | `Resources/`, `Scripts/`, `Makefile`, `project.yml`, `.github/`, `README.md`, `docs/BUILD.md`, `docs/PERMISSIONS.md`, `docs/USER_GUIDE_FR.md` |

Rules: never edit another area's files; never edit `Core/**` — if a shared type
seems missing, add a `fileprivate`/module-local helper in your own area and
flag it in your report.

## Permissions

| Capability | Permission | API |
|---|---|---|
| Post keyboard/mouse events | Accessibility | `AXIsProcessTrustedWithOptions` + `CGEvent.post` |
| Read mute button via IOHID | Input Monitoring | `IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)` |
| Controller via GameController | none | — |

The app is distributed unsandboxed (developer build); onboarding walks the user
through granting both permissions.
