# macOS DualSense (PS5) App — Verified API Cheat-Sheet

**Scope:** macOS app that fully exploits a Sony DualSense controller: GameController.framework, raw HID fallback, keyboard/mouse event synthesis, permissions, overlay UI, and headless builds/CI.
**Verification:** All symbols below were checked against Apple's documentation JSON endpoints, SDL source (`SDL_hidapi_ps5.c`, `usb_ids.h`), and the `actions/runner-images` repo, July 2026. Items I could not confirm are marked **UNVERIFIED**.

---

## 1. GameController.framework

### 1.1 Discovery & lifecycle (`GCController`)

```swift
import GameController

class GCController : NSObject, GCDevice          // macOS 10.9+

class func controllers() -> [GCController]        // currently connected
class var current: GCController?                  // most recently used (macOS 11.0+)
class func startWirelessControllerDiscovery(completionHandler: (() -> Void)?)
class func stopWirelessControllerDiscovery()
class var shouldMonitorBackgroundEvents: Bool     // macOS 11.3+ — get/set
```

Notifications (post on default `NotificationCenter`):

```swift
NSNotification.Name.GCControllerDidConnect            // macOS 10.9+
NSNotification.Name.GCControllerDidDisconnect         // macOS 10.9+
NSNotification.Name.GCControllerDidBecomeCurrent      // macOS 11.0+
NSNotification.Name.GCControllerDidStopBeingCurrent   // macOS 11.0+
```

Instance surface you will use:

```swift
var extendedGamepad: GCExtendedGamepad?     // downcast to GCDualSenseGamepad
var physicalInputProfile: GCPhysicalInputProfile  // macOS 11.0+
var motion: GCMotion?                       // non-nil for DualSense
var haptics: GCDeviceHaptics?               // macOS 11.0+
var light: GCDeviceLight?                   // macOS 11.0+
var battery: GCDeviceBattery?               // macOS 11.0+
var playerIndex: GCControllerPlayerIndex    // .unset, .player1 ... .player4 (originally .indexUnset etc. in ObjC)
var vendorName: String?
var productCategory: String?                // "DualSense" for this controller
var handlerQueue: DispatchQueue             // queue for all value handlers (default: main)
var input: GCControllerLiveInput            // macOS 14.0+ — NOTE: DualSense touchpad & adaptive triggers are NOT surfaced here (Apple forum thread 741745); use GCDualSenseGamepad/GCPhysicalInputProfile
var isAttachedToDevice: Bool
func capture() -> GCController              // snapshot
```

> **Critical for a remapper daemon:** on macOS 11.3+ `GCController.shouldMonitorBackgroundEvents` defaults to `false` — the framework stops delivering controller input when your app is not frontmost. Set it to `true` at launch. (Verified: docs state default false on 11.3+, true before; property ignored on iOS/tvOS.)

Typical connect pattern:

```swift
NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { note in
    guard let controller = note.object as? GCController,
          let ds = controller.extendedGamepad as? GCDualSenseGamepad else { return }
    configure(ds, controller: controller)
}
GCController.shouldMonitorBackgroundEvents = true
```

### 1.2 `GCDualSenseGamepad` — macOS 11.3+, iOS 14.5+

```swift
class GCDualSenseGamepad : GCExtendedGamepad
var touchpadButton: GCControllerButtonInput          // touchpad click (also isTouched)
var touchpadPrimary: GCControllerDirectionPad        // 1st finger position
var touchpadSecondary: GCControllerDirectionPad      // 2nd finger position
var leftTrigger: GCDualSenseAdaptiveTrigger          // overrides GCExtendedGamepad (L2)
var rightTrigger: GCDualSenseAdaptiveTrigger         // (R2)
```

**Every input element** (inherited from `GCExtendedGamepad`, macOS 10.9+ unless noted; DualSense physical name in parens):

```swift
var buttonA: GCControllerButtonInput                 // Cross
var buttonB: GCControllerButtonInput                 // Circle
var buttonX: GCControllerButtonInput                 // Square
var buttonY: GCControllerButtonInput                 // Triangle
var dpad: GCControllerDirectionPad                   // D-pad
var leftThumbstick: GCControllerDirectionPad
var rightThumbstick: GCControllerDirectionPad
var leftThumbstickButton: GCControllerButtonInput?   // L3 (optional in API; present on DualSense)
var rightThumbstickButton: GCControllerButtonInput?  // R3
var leftShoulder: GCControllerButtonInput            // L1
var rightShoulder: GCControllerButtonInput           // R1
var buttonMenu: GCControllerButtonInput              // Options (≡) button
var buttonOptions: GCControllerButtonInput?          // Create (share) button
var buttonHome: GCControllerButtonInput?             // PS button (macOS 11.0+/iOS 14.0+)
var valueChangedHandler: GCExtendedGamepadValueChangedHandler?
// typealias GCExtendedGamepadValueChangedHandler = (GCExtendedGamepad, GCControllerElement) -> Void
```

> Button-name mapping (Menu = Options, Options = Create, Home = PS) is the community-established mapping; Apple's docs describe them generically ("menu/options/home"). Verified behaviorally in Chiaki/SDL-adjacent projects, not spelled out in Apple docs — treat the physical mapping line as **community-verified**.

Element handler signatures:

```swift
typealias GCControllerButtonValueChangedHandler   = (GCControllerButtonInput, Float, Bool) -> Void  // (button, value 0…1, pressed)
typealias GCControllerDirectionPadValueChangedHandler = (GCControllerDirectionPad, Float, Float) -> Void // (dpad, x, y)
// on GCControllerButtonInput:
var value: Float                       // 0.0 … 1.0
var isPressed: Bool
var isTouched: Bool                    // finger resting w/o press (touchpadButton reports touch)
var valueChangedHandler:   GCControllerButtonValueChangedHandler?
var pressedChangedHandler: GCControllerButtonValueChangedHandler?
var touchedChangedHandler: GCControllerButtonTouchedChangedHandler?
// on GCControllerDirectionPad:
var xAxis: GCControllerAxisInput; var yAxis: GCControllerAxisInput
var up: GCControllerButtonInput; var down: GCControllerButtonInput
var left: GCControllerButtonInput; var right: GCControllerButtonInput
```

**Touchpad coordinate convention:** `touchpadPrimary`/`touchpadSecondary` are ordinary `GCControllerDirectionPad`s → each axis is a `Float` in **−1 … +1 with origin at the touchpad center**; x increases to the right. Standard direction-pad convention has +y up (toward the top edge of the pad). Apple's doc page for `touchpadPrimary` does not spell out orientation — the −1…+1 range comes from `GCControllerAxisInput` semantics; the "+y = top edge" detail is **community/empirically verified, UNVERIFIED in Apple docs** (verify at runtime).
There is **no** touch-ID, pressure, or raw-resolution data — only two normalized positions plus `touchpadButton.isTouched/isPressed`.

`GCPhysicalInputProfile` string access to the same elements (macOS 11.0+):

```swift
var elements: [String: GCControllerElement]; var buttons: [String: GCControllerButtonInput]
var dpads: [String: GCControllerDirectionPad]; var axes: [String: GCControllerAxisInput]
subscript(_ key: String) -> GCControllerElement? { get }
// Touchpad element names (shared with DualShock 4):
GCInputDualShockTouchpadOne: String      // = touchpadPrimary   (macOS 11.0+)
GCInputDualShockTouchpadTwo: String      // = touchpadSecondary
GCInputDualShockTouchpadButton: String   // = touchpadButton
```

### 1.3 `GCDualSenseAdaptiveTrigger` — macOS 11.3+, iOS 14.5+

```swift
class GCDualSenseAdaptiveTrigger : GCControllerButtonInput

var mode: GCDualSenseAdaptiveTrigger.Mode        // .off, .feedback, .weapon, .vibration, .slopeFeedback
var status: GCDualSenseAdaptiveTrigger.Status
var armPosition: Float                            // current arm position, 0…1
class var discretePositionCount: Int              // macOS 12.3+ — == 10

// ALL parameters are normalized Float 0…1; endPosition must be > startPosition.
func setModeOff()                                                       // macOS 11.3+
func setModeFeedbackWithStartPosition(_ startPosition: Float,
                                      resistiveStrength: Float)         // macOS 11.3+
func setModeWeaponWithStartPosition(_ startPosition: Float,
                                    endPosition: Float,
                                    resistiveStrength: Float)           // macOS 11.3+
func setModeVibrationWithStartPosition(_ startPosition: Float,
                                       amplitude: Float,
                                       frequency: Float)                // macOS 11.3+
func setModeFeedback(resistiveStrengths: GCDualSenseAdaptiveTrigger.PositionalResistiveStrengths) // macOS 12.3+/iOS 15.4+
func setModeVibration(amplitudes: GCDualSenseAdaptiveTrigger.PositionalAmplitudes,
                      frequency: Float)                                 // macOS 12.3+/iOS 15.4+
func setModeSlopeFeedback(startPosition: Float, endPosition: Float,
                          startStrength: Float, endStrength: Float)     // macOS 12.3+/iOS 15.4+
```

Nested types:

```swift
enum Mode   { case off, feedback, weapon, vibration, slopeFeedback }   // slopeFeedback added with 12.3 SDK (case availability flattened in docs — annotate 12.3+ to be safe)
enum Status { case unknown, feedbackNoLoad, feedbackLoadApplied,
              weaponReady, weaponFiring, weaponFired,
              vibrationNotVibrating, vibrationIsVibrating,
              slopeFeedbackReady, slopeFeedbackApplyingLoad, slopeFeedbackFinished }
struct PositionalResistiveStrengths {            // macOS 12.3+
    var values: (Float, Float, Float, Float, Float, Float, Float, Float, Float, Float) // 10 slots
    init(); init(values: (Float, ..., Float))
}
struct PositionalAmplitudes {                    // macOS 12.3+ — same 10-Float tuple shape
    var values: (Float, Float, Float, Float, Float, Float, Float, Float, Float, Float)
}
```

### 1.4 Lightbar, battery, player LEDs

```swift
// GCDeviceLight — macOS 11.0+
controller.light?.color = GCColor(red: 0.0, green: 0.5, blue: 1.0)   // components 0…1
class GCColor : NSObject { init(red: Float, green: Float, blue: Float); var red/green/blue: Float }
// Static color only — no pulse/animation via GameController (raw HID needed for LED animation modes).

// GCDeviceBattery — macOS 11.0+
var batteryLevel: Float                 // 0.0 … 1.0
var batteryState: GCDeviceBattery.State // .unknown, .discharging, .charging, .full

// Player LEDs (the 5 white LEDs under the touchpad): set via
controller.playerIndex = .player1       // .unset turns them off
// Arbitrary LED bit patterns are NOT exposed — raw HID only.
```

### 1.5 Motion (`GCMotion`) — macOS 10.10+ (class); DualSense support macOS 11.3+

```swift
var sensorsRequireManualActivation: Bool   // TRUE for DualSense — you must opt in
var sensorsActive: Bool                    // set true to start gyro/accel streaming
var acceleration: GCAcceleration           // total accel incl. gravity — UNITS: G  (struct: x,y,z: Double)
var rotationRate: GCRotationRate           // gyro — radians/second (x,y,z: Double)
var hasRotationRate: Bool                  // true on DualSense
var hasAttitude: Bool                      // false on DualSense (no sensor fusion) — community-verified, UNVERIFIED in docs
var hasGravityAndUserAcceleration: Bool    // false on DualSense (no gravity split) — community-verified, UNVERIFIED in docs
var attitude: GCQuaternion                 // ⚠ not populated for DualSense
var gravity: GCAcceleration; var userAcceleration: GCAcceleration   // ⚠ not populated for DualSense
var hasAttitudeAndRotationRate: Bool       // DEPRECATED — use hasAttitude/hasRotationRate
var valueChangedHandler: GCMotionValueChangedHandler?   // typealias (GCMotion) -> Void
```

Axis convention (from Apple's GCDualSenseGamepad overview): **+X → your right, +Y → up out of the USB-C port, +Z → from touchpad toward you.** Do your own sensor fusion (e.g. Madgwick/Mahony) for aim: only raw `acceleration` + `rotationRate` are available.

```swift
if let motion = controller.motion, motion.sensorsRequireManualActivation {
    motion.sensorsActive = true
}
```

### 1.6 Haptics (`GCDeviceHaptics` + CoreHaptics) — macOS 11.0+

```swift
func createEngine(withLocality locality: GCHapticsLocality) -> CHHapticEngine?
var supportedLocalities: Set<GCHapticsLocality>
let GCHapticDurationInfinite: Float

struct GCHapticsLocality {   // constants:
    static let `default`: GCHapticsLocality   // best default actuators
    static let all, handles, leftHandle, rightHandle, triggers, leftTrigger, rightTrigger: GCHapticsLocality
}
```

DualSense reports handle localities (`.leftHandle`/`.rightHandle` voice-coil actuators). `.triggers` locality is **not** how you drive DualSense trigger effects — use `GCDualSenseAdaptiveTrigger` (whether `.triggers` appears in `supportedLocalities` for DualSense on macOS: **UNVERIFIED** — check `supportedLocalities` at runtime).

CoreHaptics drive pattern:

```swift
import CoreHaptics
let engine = controller.haptics?.createEngine(withLocality: .default)
try engine?.start()
let event = CHHapticEvent(eventType: .hapticContinuous,
                          parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                                       CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)],
                          relativeTime: 0, duration: 0.25)
let pattern = try CHHapticPattern(events: [event], parameters: [])
let player = try engine?.makePlayer(with: pattern)
try player?.start(atTime: CHHapticTimeImmediate)
// engine.resetHandler / engine.stoppedHandler: reinstall & restart on controller sleep/reconnect.
```

### 1.7 What GameController does NOT expose (and the raw-HID escape hatch)

| Feature | GameController | Raw HID (IOHIDManager) |
|---|---|---|
| **Mute button** (and mute LED) | ❌ not exposed (no GCInput constant; confirmed by community, e.g. GLFW discourse) | ✅ button: input byte `buttons[2]` bit 2; LED: output `ucMicLightMode` (0 off / 1 solid / 2 pulse) |
| Raw touchpad (1920×1070, touch IDs) | ❌ only two normalized fingers | ✅ 12-bit x/y + 7-bit touch counter per finger |
| Headphone jack / speaker / mic routing & volume | ❌ | Partially: output-report volume bytes; actual audio is a **USB audio device via CoreAudio when wired** (over Bluetooth, DualSense audio is not available on macOS — **UNVERIFIED**) |
| Lightbar animation / player-LED bit patterns | ❌ (static color / playerIndex only) | ✅ |
| Low-level trigger effect bytes (beyond Apple's 5 modes) | ❌ | ✅ 11-byte effect blocks |
| Headphone-connected flag, battery 0–15 raw nibble | ❌ | ✅ status byte |
| DualSense **Edge** paddles/Fn buttons | **UNVERIFIED** whether surfaced on macOS | ✅ `buttons[2]` bits 4–7 |

**Raw HID essentials (verified against SDL `SDL_hidapi_ps5.c` and `usb_ids.h`):**

- IDs: vendor `0x054C`; DualSense `0x0CE6`; DualSense Edge `0x0DF2`.
- Match: `IOHIDManagerSetDeviceMatching(mgr, [kIOHIDVendorIDKey: 0x054C, kIOHIDProductIDKey: 0x0CE6] as CFDictionary)`; open with `IOHIDManagerOpen`, then `IOHIDDeviceRegisterInputReportCallback`; send with `IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, reportID, bytes, len)`.
- **Input, USB:** report ID `0x01`, 64 bytes. Payload after report ID: sticks LX,LY,RX,RY (0–255) at 0–3; L2,R2 analog at 4–5; seq counter 6; buttons 7–10 (`buttons[0]`: hi-nibble = ▢✕◯△, lo-nibble = dpad hat 0–8; `buttons[1]`: L1=bit0,R1=1,Create=4,Options=5,L3=6,R3=7; `buttons[2]`: PS=bit0, touchpad-click=1, **mute=2**, Edge Fn L/R=4/5, paddles L/R=6/7); gyro x/y/z int16 LE at 15–20 (**1024 LSB per deg/s**); accel x/y/z int16 at 21–26 (**8192 LSB per g**); sensor timestamp uint32 µs at 27–30; touch finger 1 at 32–35, finger 2 at 36–39 (byte0 = 7-bit counter + top bit set = **no** contact; x = `b1 | ((b2 & 0x0F) << 8)`, y = `(b2 >> 4) | (b3 << 4)`; range **1920 × 1070**); battery byte 52 (hi-nibble state: 0 discharging/1 charging/2 full; lo-nibble level 0–15); byte 53 flags (0x08 wired, 0x01 headphones).
- **Input, Bluetooth:** defaults to a 10-byte DS4-style "simple" report `0x01` (sticks + buttons only). **Enable the full `0x31` report (78 bytes)** by reading feature report `0x09` (serial number) or `0x20` (firmware info); calibration is feature `0x05`, capabilities `0x03`. In `0x31` the state payload starts 1 byte later (report ID, then a sequence byte).
- **Output:** USB report `0x02` (48-byte effects payload); Bluetooth report `0x31`, 78 bytes total, **last 4 bytes = CRC32 over `0xA2` byte followed by the report bytes** (received reports use header `0xA1`). Effects payload: enable-flag bytes 0–1; rumble right/left 2–3 (0–255; set enable bit0, plus `ucEnableBits3 |= 0x04` for improved rumble on firmware ≥ 0x0224); volumes 4–6; mic-LED mode byte 8 (enable via bit0 of byte 1); **right trigger effect bytes 10–20, left trigger 21–31** (11-byte blocks); LED control 41–46: animation, brightness, **player-LED bitmask** (5 bits, enable bit4 of byte1), lightbar **R,G,B** (enable bit2 of byte1).
- **Permission:** opening HID devices requires **Input Monitoring** TCC on macOS 10.15+; `IOHIDDeviceOpen` fails with `kIOReturnNotPrivileged` otherwise (SDL explicitly gates hidapi enumeration on this). GameController.framework itself needs **no** TCC permission.

---

## 2. Event synthesis (Quartz Event Services)

### 2.1 Keyboard

```swift
import CoreGraphics
import Carbon.HIToolbox   // kVK_* virtual key codes (kVK_ANSI_A = 0x00, kVK_Return = 0x24, kVK_Space = 0x31, kVK_Escape = 0x35 …)

init?(keyboardEventSource source: CGEventSource?, virtualKey: CGKeyCode, keyDown: Bool)  // macOS 10.4+
// modifiers: post separate events for Shift etc., or set event.flags = [.maskShift, .maskCommand, ...]

func keyboardSetUnicodeString(stringLength: Int, unicodeString: UnsafePointer<UniChar>?) // macOS 10.4+
```

Arbitrary Unicode (accents, é, emoji) — layout-independent typing:

```swift
func typeUnicode(_ s: String) {
    for chunk in s.unicodeScalars.map({ Array(String($0).utf16) }) {   // practical per-event limit ≈ 20 UniChars (UNVERIFIED in docs; keep chunks short)
        let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
        down.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
        down.post(tap: .cghidEventTap)
        let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)!
        up.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
        up.post(tap: .cghidEventTap)
    }
}
```

Caveat (from Apple docs): frameworks *may* ignore the Unicode string and re-translate from the virtual keycode — using `virtualKey: 0` with the Unicode string set is the standard, widely working approach.

### 2.2 Mouse

```swift
init?(mouseEventSource source: CGEventSource?, mouseType: CGEventType,
      mouseCursorPosition: CGPoint, mouseButton: CGMouseButton)          // macOS 10.4+
// CGEventType: .mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged,
//              .rightMouseDown/.rightMouseUp/.rightMouseDragged, .otherMouse…
// mouseButton is IGNORED except for otherMouse* types (.left/.right/.center)
// Coordinates: GLOBAL display coords, origin TOP-LEFT of main display (CG space, not AppKit space).

// Double-click: set click state on down AND up events:
event.setIntegerValueField(.mouseEventClickState, value: 2)
// Relative deltas (games/pointer-lock apps read these):
event.setIntegerValueField(.mouseEventDeltaX, value: dx)   // also .mouseEventDeltaY
```

Drag = `.leftMouseDown` → repeated `.leftMouseDragged` with new positions → `.leftMouseUp`.

### 2.3 Scroll wheel

```swift
init?(scrollWheelEvent2Source source: CGEventSource?, units: CGScrollEventUnit,
      wheelCount: UInt32, wheel1: Int32, wheel2: Int32, wheel3: Int32)   // Swift init macOS 10.13+ (C fn CGEventCreateScrollWheelEvent is older)
// units: .pixel  → smooth, trackpad-like (use for analog-stick scrolling)
//        .line   → discrete notches (~10 px per line)
// wheel1 = vertical (positive scrolls up), wheel2 = horizontal, wheelCount 1–3.
```

### 2.4 Posting

```swift
event.post(tap: .cghidEventTap)      // CGEventTapLocation: .cghidEventTap (HID system level — best for synthesis),
                                     // .cgSessionEventTap, .cgAnnotatedSessionEventTap
let src = CGEventSource(stateID: .hidSystemState)   // or .combinedSessionState / .privateState
```

### 2.5 Which permission for which operation (TCC)

| Operation | TCC pane | Check / Request API |
|---|---|---|
| **Post** CGEvents (keyboard/mouse synthesis) | **Accessibility** | `CGPreflightPostEventAccess() -> Bool` / `CGRequestPostEventAccess() -> Bool` (both macOS 10.15+); or `AXIsProcessTrustedWithOptions(_ options: CFDictionary?) -> Bool` (macOS 10.9+) with prompt |
| **Listen** to keyboard/mouse of other apps (listen-only `CGEvent.tapCreate`) | **Input Monitoring** | `CGPreflightListenEventAccess()` / `CGRequestListenEventAccess()` (macOS 10.15+) |
| **Active event tap** (modify/consume events, `CGEventTapOptions.defaultTap`) | **Accessibility** | AX check above |
| **IOHIDManager/IOHIDDevice open** (raw DualSense HID) | **Input Monitoring** | `IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) -> IOHIDAccessType`, `IOHIDRequestAccess(kIOHIDRequestTypeListenEvent) -> Bool` (both macOS 10.15+, IOKit/hid/IOHIDLib.h; types `kIOHIDRequestTypeListenEvent`, `kIOHIDRequestTypePostEvent`) |
| GameController.framework input, lightbar, haptics, triggers | **none** | — |

Accessibility prompt:

```swift
import ApplicationServices
let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
let trusted = AXIsProcessTrustedWithOptions(opts)   // shows system dialog once; user must toggle in System Settings ▸ Privacy & Security ▸ Accessibility
```

Notes for unsandboxed dev-signed apps:
- No Info.plist usage-description keys are required for Accessibility/Input Monitoring on macOS (unlike camera/mic).
- TCC grants are keyed to the app's **code-signing identity + bundle ID**. Ad-hoc (`codesign -s -`) builds get a new identity every rebuild → the grant silently breaks; sign with a stable Apple Development / Developer ID certificate during development.
- A bare CLI launched from Terminal is attributed to the **responsible process** (Terminal), so permissions may land on Terminal — ship a real `.app` bundle.
- `CGRequestPostEventAccess()` prompts and deep-links to the Accessibility pane; `CGRequestListenEventAccess()` to Input Monitoring.

### 2.6 Per-app profiles (frontmost app tracking)

```swift
import AppKit
NSWorkspace.shared.frontmostApplication          // NSRunningApplication?
// Observe on NSWorkspace's OWN notification center:
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
    let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
    switchProfile(for: app?.bundleIdentifier)    // e.g. "com.apple.Safari"
}
```

---

## 3. Overlay UI, menu bar, login item

### 3.1 Non-activating floating panel (on-screen keyboard overlay)

```swift
final class OverlayPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView], // .nonactivatingPanel: panel does NOT activate the owning app (verified doc wording)
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating                       // NSWindow.Level: .normal(0) < .floating(3) < .modalPanel(8) < .statusBar(25) < .popUpMenu(101) < .screenSaver(1000)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isMovableByWindowBackground = false
        backgroundColor = .clear; isOpaque = false; hasShadow = true
        contentView = NSHostingView(rootView: OverlayKeyboardView())   // SwiftUI content
    }
    override var canBecomeKey: Bool { false }   // NEVER steals key focus — synthesized CGEvents go to the frontmost app
    override var canBecomeMain: Bool { false }
}
panel.orderFrontRegardless()
// Optional: panel.ignoresMouseEvents = true for full click-through.
```

`level = .statusBar` keeps it above most app windows; `.fullScreenAuxiliary` lets it appear over full-screen apps.

### 3.2 MenuBarExtra — SwiftUI, macOS 13.0+

```swift
@main struct RemapApp: App {
    var body: some Scene {
        MenuBarExtra("DS Remap", systemImage: "gamecontroller") { SettingsMenu() }
            .menuBarExtraStyle(.window)      // .menu (default, pull-down) or .window (rich popover)
        // init(_ titleKey:, systemImage:, isInserted: Binding<Bool>, content:) also available
    }
}
```

### 3.3 Launch at login — `SMAppService`, macOS 13.0+ (ServiceManagement)

```swift
import ServiceManagement
class SMAppService : NSObject
class var mainApp: SMAppService                       // the app itself as login item
class func agent(plistName: String) -> Self           // bundled LaunchAgent plist
class func daemon(plistName: String) -> Self
class func loginItem(identifier: String) -> Self
func register() throws
func unregister() throws
func unregister(completionHandler: ((any Error)?) -> Void)
var status: SMAppService.Status                       // .notRegistered, .enabled, .requiresApproval, .notFound
class func openSystemSettingsLoginItems()

try? SMAppService.mainApp.register()
```

---

## 4. Building without the Xcode GUI

### 4.1 SwiftPM executable → `.app` bundle

`Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "DSRemap",
    platforms: [.macOS(.v13)],                          // 13 for MenuBarExtra/SMAppService; 12.3 if you need only trigger APIs
    targets: [.executableTarget(name: "DSRemap", path: "Sources")]
)
```

Bundle script (`swift build -c release` produces a bare binary; assemble manually):

```bash
swift build -c release --arch arm64 --arch x86_64
APP=build/DSRemap.app
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/apple/Products/Release/DSRemap "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
codesign --force --options runtime --sign "Apple Development: you@example.com" "$APP"
# NEVER ad-hoc sign if you want TCC grants to survive rebuilds (see §2.5)
```

Minimal `Info.plist` keys:

```xml
<key>CFBundleExecutable</key><string>DSRemap</string>
<key>CFBundleIdentifier</key><string>com.you.dsremap</string>
<key>CFBundleName</key><string>DSRemap</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>LSUIElement</key><true/>   <!-- see tradeoffs below -->
```

- **`LSUIElement = true`**: no Dock icon, no app menu — correct for a MenuBarExtra-only agent. Tradeoffs: the app never appears in ⌘-Tab; regular windows won't take normal app menus; toggle at runtime with `NSApp.setActivationPolicy(.regular)` if you later need a settings window in the Dock. It does **not** affect TCC or GameController.
- **GameController usage keys:** none exist/needed on macOS (`GCSupportsControllerUserInteraction` and `GCSupportedGameControllers` are iOS/tvOS keys). No Bluetooth usage string is needed for GameController on macOS (`NSBluetoothAlwaysUsageDescription` is only for CoreBluetooth).
- **`NSAppTransportSecurity`:** not needed — no networking involved.
- Sandbox note: keep the app **unsandboxed** — CGEvent posting to other apps and IOHIDManager are incompatible with the App Store sandbox for this use case (App Store distribution of a remapper is effectively not possible).
- Bare-binary alternative during development: embed the plist with `-Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Info.plist` so TCC sees a stable identity.

### 4.2 xcodegen alternative (`project.yml`)

```yaml
name: DSRemap
options:
  bundleIdPrefix: com.you
  deploymentTarget: { macOS: "13.0" }
targets:
  DSRemap:
    type: application
    platform: macOS
    sources: [Sources]
    info:
      path: Generated/Info.plist
      properties:
        LSUIElement: true
        NSHighResolutionCapable: true
    settings:
      base:
        CODE_SIGN_IDENTITY: "Apple Development"
        ENABLE_HARDENED_RUNTIME: YES
```

Then `xcodegen generate && xcodebuild -project DSRemap.xcodeproj -scheme DSRemap -configuration Release build`.

### 4.3 GitHub Actions macOS runners (verified July 2026, `actions/runner-images`)

| Label | OS on image | Arch | Xcode installed | Default Xcode |
|---|---|---|---|---|
| `macos-latest` / `macos-26` | macOS 26.4 | arm64 | 26.0.1 – 26.6 | **26.5** |
| `macos-15` (`-intel`/`-large` = x64) | macOS 15.7 | arm64 | 16.0–16.4, 26.0.1–26.3 | **16.4** |
| `macos-14` (**deprecated** — only latest 2 OS majors kept) | macOS 14.8 | arm64 | 15.0.1–15.4, 16.1, 16.2 | **15.4** |

Minimal workflow:

```yaml
name: build
on: [push]
jobs:
  build:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.4.app   # or Xcode_26.2.app on macos-15
      - name: Build
        run: swift build -c release
      - name: Bundle .app
        run: ./scripts/make_app.sh
      - uses: actions/upload-artifact@v4
        with: { name: DSRemap.app, path: build/DSRemap.app }
```

(You cannot exercise the controller, TCC prompts, or CGEvent posting on CI — build/unit-test only.)

---

## Quick "what runs where" availability matrix

| API | Min macOS |
|---|---|
| GCController, GCExtendedGamepad | 10.9 |
| GCMotion (class) | 10.10 |
| GCDeviceLight / Battery / Haptics, GCPhysicalInputProfile, GCColor, GCInputDualShockTouchpad* | 11.0 |
| GCDualSenseGamepad, GCDualSenseAdaptiveTrigger (basic modes), shouldMonitorBackgroundEvents | 11.3 |
| Positional/slope trigger modes, discretePositionCount | 12.3 |
| MenuBarExtra, SMAppService | 13.0 |
| GCControllerLiveInput (`controller.input`) — but no DualSense touchpad/triggers there | 14.0 |
| CGRequest/Preflight Post/ListenEventAccess, IOHIDCheckAccess/IOHIDRequestAccess | 10.15 |

## UNVERIFIED items (recap)
- Touchpad direction-pad **y-axis orientation** (+y = top edge): consistent with GC conventions and community reports; not stated in Apple docs.
- `hasAttitude == false` / `hasGravityAndUserAcceleration == false` on DualSense: community/behaviorally established, not in Apple docs.
- Whether `.triggers` locality appears in DualSense `supportedLocalities` on macOS.
- DualSense audio over **Bluetooth** on macOS (wired USB audio device is well established).
- ~20-UniChar practical limit of `keyboardSetUnicodeString` per event.
- DualSense **Edge** paddle exposure via GameController on macOS.
- `slopeFeedback` Mode *case* availability shown as 11.3 in docs JSON, but it is only usable with the 12.3+ `setModeSlopeFeedback` — annotate 12.3+.

**Primary sources:** Apple Developer documentation JSON for GCDualSenseGamepad, GCDualSenseAdaptiveTrigger (+Mode/Status/PositionalResistiveStrengths/discretePositionCount/setMode* pages), GCController (+shouldMonitorBackgroundEvents), GCExtendedGamepad(+ValueChangedHandler), GCControllerButtonInput/AxisInput/DirectionPad, GCMotion, GCDeviceLight/GCColor/GCDeviceBattery(+State)/GCDeviceHaptics, GCPhysicalInputProfile, GCInputDualShockTouchpadOne, CGEvent initializers (keyboard/mouse/scrollWheel2), keyboardSetUnicodeString, CGRequestPostEventAccess/CGRequestListenEventAccess, NSWindow.StyleMask.nonactivatingPanel, MenuBarExtra, SMAppService; `libsdl-org/SDL` `src/joystick/hidapi/SDL_hidapi_ps5.c` and `src/joystick/usb_ids.h`; `actions/runner-images` macos-14/15/26 READMEs; Apple Developer Forums thread 741745 (GCControllerLiveInput touchpad gap); GLFW discourse (mute button inaccessibility); SDL commit "Don't enumerate HID devices on macOS if we don't have input monitoring permissions".