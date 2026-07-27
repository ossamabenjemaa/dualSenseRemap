import Foundation

/// A complete controller configuration. Profiles are persisted as JSON and can
/// auto-activate when one of their linked applications comes to the foreground.
struct Profile: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var icon: String = "gamecontroller" // SF Symbol name
    /// Bundle identifiers of apps that auto-activate this profile.
    var linkedAppBundleIDs: [String] = []

    /// Digital bindings.
    var mappings: [ControllerElement: Action] = [:]

    /// Analog configuration.
    var leftStickMode: StickMode = .mousePointer(StickTuning())
    var rightStickMode: StickMode = .scroll(StickTuning(sensitivity: 14))
    var leftTrigger: TriggerSettings = TriggerSettings()
    var rightTrigger: TriggerSettings = TriggerSettings()
    var touchpadMode: TouchpadMode = .defaultTrackpad
    var gyroMode: GyroMode = .disabled

    /// Feedback.
    var lightbar: LightbarSettings = LightbarSettings()
    var haptics: HapticsSettings = HapticsSettings()

    func action(for element: ControllerElement) -> Action {
        mappings[element] ?? .none
    }
}

extension Profile {
    /// The built-in default profile: couch navigation of macOS.
    static func defaultProfile() -> Profile {
        var p = Profile(name: "Défaut")
        p.icon = "macwindow"
        p.mappings = [
            .cross: .mouse(.leftClick),
            .circle: .mouse(.rightClick),
            .square: .system(.missionControl),
            .triangle: .toggleVirtualKeyboard,
            .dpadUp: .keyCombo(KeyCombo(keyCode: 126, modifiers: [], label: "↑")),
            .dpadDown: .keyCombo(KeyCombo(keyCode: 125, modifiers: [], label: "↓")),
            .dpadLeft: .keyCombo(KeyCombo(keyCode: 123, modifiers: [], label: "←")),
            .dpadRight: .keyCombo(KeyCombo(keyCode: 124, modifiers: [], label: "→")),
            .l1: .system(.previousTab),
            .r1: .system(.nextTab),
            .l2: .system(.appSwitcher),
            .r2: .mouse(.leftClick),
            .l3: .system(.spotlight),
            .r3: .system(.launchpad),
            .create: .system(.screenshotArea),
            .options: .openMappingWindow,
            .ps: .system(.launchpad),
            .mute: .system(.volumeMute),
            .touchpadClick: .mouse(.leftClick),
        ]
        return p
    }

    /// Media-oriented profile, auto-linked to common players.
    static func mediaProfile() -> Profile {
        var p = Profile(name: "Multimédia")
        p.icon = "play.rectangle"
        p.linkedAppBundleIDs = [
            "com.spotify.client",
            "com.apple.TV",
            "com.apple.Music",
            "com.colliderli.iina",
            "org.videolan.vlc",
        ]
        p.mappings = [
            .cross: .system(.mediaPlayPause),
            .circle: .keyCombo(KeyCombo(keyCode: 53, modifiers: [], label: "⎋")),
            .square: .system(.mediaPrevious),
            .triangle: .system(.mediaNext),
            .dpadUp: .system(.volumeUp),
            .dpadDown: .system(.volumeDown),
            .dpadLeft: .keyCombo(KeyCombo(keyCode: 123, modifiers: [], label: "←")),
            .dpadRight: .keyCombo(KeyCombo(keyCode: 124, modifiers: [], label: "→")),
            .l1: .system(.mediaPrevious),
            .r1: .system(.mediaNext),
            .mute: .system(.volumeMute),
            .touchpadClick: .mouse(.leftClick),
            .options: .openMappingWindow,
            .ps: .toggleVirtualKeyboard,
        ]
        return p
    }
}

/// App-wide settings, persisted alongside profiles.
struct AppSettings: Codable, Hashable {
    var autoSwitchProfiles: Bool = true
    var launchAtLogin: Bool = false
    var showMenuBarIcon: Bool = true
    var hammerspoonEnabled: Bool = true
    /// Virtual keyboard: haptic pulse on key press.
    var keyboardHapticFeedback: Bool = true
    var virtualKeyboardScale: Double = 1.0
}
