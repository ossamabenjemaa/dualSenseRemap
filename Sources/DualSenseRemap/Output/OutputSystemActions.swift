import Foundation
import AppKit

/// Virtual key codes used by the native system actions (ANSI layout codes
/// from Carbon's `Events.h`; arrows/function keys are layout-independent).
private enum OutputKeyCode {
    static let ansiC: UInt16 = 8
    static let ansiV: UInt16 = 9
    static let ansiZ: UInt16 = 6
    static let ansiQ: UInt16 = 12
    static let ansi4: UInt16 = 21
    static let space: UInt16 = 49
    static let tab: UInt16 = 48
    static let command: UInt16 = 55
    static let downArrow: UInt16 = 125
    static let upArrow: UInt16 = 126
    static let f4: UInt16 = 118
    static let f11: UInt16 = 103
}

/// Performs every `SystemAction` case natively — no Hammerspoon required.
///
/// Implementation choices (per docs/research/apple-apis.md and
/// docs/research/ps5-keyboard-hammerspoon.md):
/// - `launchpad` / `missionControl`: open the dedicated system apps in
///   `/System/Applications` — their sole purpose is toggling those overlays.
///   Fallback for Launchpad: fn+F4 key combo (Apple keyboard media row).
/// - `applicationWindows` (App Exposé): there is no public API and passing
///   arguments to Mission Control.app is a private interface — we post the
///   default shortcut ⌃↓ instead (may fail if the user rebound it).
/// - `showDesktop`: no clean public API either; we post the default fn+F11
///   shortcut rather than invoking Mission Control.app with a private
///   argument (documented degradation, may fail if the user rebound it).
/// - `appSwitcher`: a single synthesized ⌘⇥ tap — this flips to the previous
///   app but cannot keep the switcher HUD open (documented limitation; the
///   HUD needs a physically held modifier).
/// - Media / volume / brightness: `NX_KEYTYPE_*` aux-key events via
///   `EventSynthesizer.mediaKey` — identical to the hardware media keys.
enum OutputSystemActions {

    /// Executes the system action. Call on button-down only; every action is
    /// a one-shot (no press-and-hold semantics).
    static func perform(_ action: SystemAction) {
        switch action {
        case .launchpad:
            openSystemApp(atPath: "/System/Applications/Launchpad.app",
                          fallback: KeyCombo(keyCode: OutputKeyCode.f4,
                                             modifiers: [.fn],
                                             label: "fn F4"))

        case .missionControl:
            openSystemApp(atPath: "/System/Applications/Mission Control.app",
                          fallback: KeyCombo(keyCode: OutputKeyCode.upArrow,
                                             modifiers: [.control],
                                             label: "⌃↑"))

        case .applicationWindows:
            // App Exposé default shortcut: Control + Down Arrow.
            EventSynthesizer.tap(KeyCombo(keyCode: OutputKeyCode.downArrow,
                                          modifiers: [.control],
                                          label: "⌃↓"))

        case .showDesktop:
            // Default "Show Desktop" shortcut: fn+F11.
            EventSynthesizer.tap(KeyCombo(keyCode: OutputKeyCode.f11,
                                          modifiers: [.fn],
                                          label: "fn F11"))

        case .spotlight:
            EventSynthesizer.tap(KeyCombo(keyCode: OutputKeyCode.space,
                                          modifiers: [.command],
                                          label: "⌘Espace"))

        case .appSwitcher:
            performAppSwitcherTap()

        case .mediaPlayPause:
            tapMediaKey(.playPause)
        case .mediaNext:
            tapMediaKey(.next)
        case .mediaPrevious:
            tapMediaKey(.previous)
        case .volumeUp:
            tapMediaKey(.volumeUp)
        case .volumeDown:
            tapMediaKey(.volumeDown)
        case .volumeMute:
            tapMediaKey(.mute)
        case .brightnessUp:
            tapMediaKey(.brightnessUp)
        case .brightnessDown:
            tapMediaKey(.brightnessDown)

        case .screenshotArea:
            EventSynthesizer.tap(KeyCombo(keyCode: OutputKeyCode.ansi4,
                                          modifiers: [.command, .shift],
                                          label: "⇧⌘4"))

        case .lockScreen:
            EventSynthesizer.tap(KeyCombo(keyCode: OutputKeyCode.ansiQ,
                                          modifiers: [.control, .command],
                                          label: "⌃⌘Q"))

        case .nextTab:
            EventSynthesizer.tap(KeyCombo(keyCode: OutputKeyCode.tab,
                                          modifiers: [.control],
                                          label: "⌃⇥"))

        case .previousTab:
            EventSynthesizer.tap(KeyCombo(keyCode: OutputKeyCode.tab,
                                          modifiers: [.control, .shift],
                                          label: "⌃⇧⇥"))

        case .copy:
            EventSynthesizer.tap(KeyCombo(keyCode: OutputKeyCode.ansiC,
                                          modifiers: [.command],
                                          label: "⌘C"))

        case .paste:
            EventSynthesizer.tap(KeyCombo(keyCode: OutputKeyCode.ansiV,
                                          modifiers: [.command],
                                          label: "⌘V"))

        case .undo:
            EventSynthesizer.tap(KeyCombo(keyCode: OutputKeyCode.ansiZ,
                                          modifiers: [.command],
                                          label: "⌘Z"))
        }
    }

    // MARK: - Helpers

    private static func tapMediaKey(_ key: MediaKey) {
        EventSynthesizer.mediaKey(key, down: true)
        EventSynthesizer.mediaKey(key, down: false)
    }

    /// Opens a system overlay app (Launchpad / Mission Control). Falls back
    /// to a key combo when the app is missing or fails to open.
    private static func openSystemApp(atPath path: String, fallback: KeyCombo?) {
        guard FileManager.default.fileExists(atPath: path) else {
            if let fallback { EventSynthesizer.tap(fallback) }
            return
        }
        let url = URL(fileURLWithPath: path)
        DispatchQueue.main.async {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
                if error != nil, let fallback {
                    EventSynthesizer.tap(fallback)
                }
            }
        }
    }

    /// Single ⌘⇥ tap: switches to the previously active application.
    /// Posts a real Command key press around the Tab tap so the switcher
    /// recognizes the chord.
    private static func performAppSwitcherTap() {
        EventSynthesizer.post(KeyCombo(keyCode: OutputKeyCode.command,
                                       modifiers: [.command],
                                       label: "⌘"), down: true)
        EventSynthesizer.post(KeyCombo(keyCode: OutputKeyCode.tab,
                                       modifiers: [.command],
                                       label: "⌘⇥"), down: true)
        EventSynthesizer.post(KeyCombo(keyCode: OutputKeyCode.tab,
                                       modifiers: [.command],
                                       label: "⌘⇥"), down: false)
        EventSynthesizer.post(KeyCombo(keyCode: OutputKeyCode.command,
                                       modifiers: [],
                                       label: "⌘"), down: false)
    }
}
