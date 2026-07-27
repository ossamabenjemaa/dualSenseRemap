import Foundation

/// Modifier keys for key combos. Codable via raw value.
struct KeyModifiers: OptionSet, Codable, Hashable {
    let rawValue: UInt8

    static let command = KeyModifiers(rawValue: 1 << 0)
    static let option  = KeyModifiers(rawValue: 1 << 1)
    static let control = KeyModifiers(rawValue: 1 << 2)
    static let shift   = KeyModifiers(rawValue: 1 << 3)
    static let fn      = KeyModifiers(rawValue: 1 << 4)

    var displaySymbols: String {
        var s = ""
        if contains(.control) { s += "⌃" }
        if contains(.option)  { s += "⌥" }
        if contains(.shift)   { s += "⇧" }
        if contains(.command) { s += "⌘" }
        if contains(.fn)      { s += "fn" }
        return s
    }
}

/// A keyboard shortcut: macOS virtual key code + modifiers.
/// `label` is the display string captured at recording time (e.g. "⌘C"),
/// so the UI never has to reverse-map key codes through the active layout.
struct KeyCombo: Codable, Hashable {
    var keyCode: UInt16
    var modifiers: KeyModifiers
    var label: String

    var displayName: String {
        label.isEmpty ? "\(modifiers.displaySymbols)#\(keyCode)" : label
    }
}

enum MouseButtonAction: String, Codable, Hashable, CaseIterable {
    case leftClick
    case rightClick
    case middleClick
    case doubleClick
    case dragToggle // press once to start dragging, again to release

    var displayName: String {
        switch self {
        case .leftClick: return "Clic gauche"
        case .rightClick: return "Clic droit"
        case .middleClick: return "Clic molette"
        case .doubleClick: return "Double-clic"
        case .dragToggle: return "Glisser (verrouillé)"
        }
    }
}

/// Built-in macOS system actions the app can perform natively (no Hammerspoon required).
enum SystemAction: String, Codable, Hashable, CaseIterable {
    case launchpad
    case missionControl
    case applicationWindows
    case showDesktop
    case spotlight
    case appSwitcher
    case mediaPlayPause
    case mediaNext
    case mediaPrevious
    case volumeUp
    case volumeDown
    case volumeMute
    case brightnessUp
    case brightnessDown
    case screenshotArea
    case lockScreen
    case nextTab
    case previousTab
    case copy
    case paste
    case undo

    var displayName: String {
        switch self {
        case .launchpad: return "Launchpad"
        case .missionControl: return "Mission Control"
        case .applicationWindows: return "Fenêtres de l'app"
        case .showDesktop: return "Afficher le bureau"
        case .spotlight: return "Spotlight"
        case .appSwitcher: return "Sélecteur d'apps (⌘⇥)"
        case .mediaPlayPause: return "Lecture / Pause"
        case .mediaNext: return "Piste suivante"
        case .mediaPrevious: return "Piste précédente"
        case .volumeUp: return "Volume +"
        case .volumeDown: return "Volume −"
        case .volumeMute: return "Volume muet"
        case .brightnessUp: return "Luminosité +"
        case .brightnessDown: return "Luminosité −"
        case .screenshotArea: return "Capture d'écran (zone)"
        case .lockScreen: return "Verrouiller l'écran"
        case .nextTab: return "Onglet suivant"
        case .previousTab: return "Onglet précédent"
        case .copy: return "Copier"
        case .paste: return "Coller"
        case .undo: return "Annuler"
        }
    }
}

/// One step of a recorded macro.
enum MacroStep: Codable, Hashable {
    case keyCombo(KeyCombo)
    case text(String)
    case wait(milliseconds: Int)
}

/// Everything a digital control can be bound to.
enum Action: Codable, Hashable {
    case none
    case keyCombo(KeyCombo)
    case typeText(String)
    case mouse(MouseButtonAction)
    case system(SystemAction)
    case hammerspoon(event: String)
    case shellCommand(String)
    case openApp(bundleID: String, name: String)
    case openURL(String)
    case macro(name: String, steps: [MacroStep])
    case toggleVirtualKeyboard
    case cycleProfile
    case openMappingWindow

    var displayName: String {
        switch self {
        case .none: return "Aucune action"
        case .keyCombo(let combo): return combo.displayName
        case .typeText(let text): return "Taper « \(text) »"
        case .mouse(let button): return button.displayName
        case .system(let action): return action.displayName
        case .hammerspoon(let event): return "Hammerspoon : \(event)"
        case .shellCommand(let cmd): return "Shell : \(cmd.prefix(30))"
        case .openApp(_, let name): return "Ouvrir \(name)"
        case .openURL(let url): return "Ouvrir \(url.prefix(30))"
        case .macro(let name, _): return "Macro : \(name)"
        case .toggleVirtualKeyboard: return "Clavier virtuel"
        case .cycleProfile: return "Profil suivant"
        case .openMappingWindow: return "Ouvrir DualSense Remap"
        }
    }

    /// Short category label for the mapping editor.
    var categoryName: String {
        switch self {
        case .none: return "—"
        case .keyCombo, .typeText: return "Clavier"
        case .mouse: return "Souris"
        case .system: return "Système"
        case .hammerspoon: return "Hammerspoon"
        case .shellCommand, .openApp, .openURL: return "Apps & commandes"
        case .macro: return "Macros"
        case .toggleVirtualKeyboard, .cycleProfile, .openMappingWindow: return "DualSense Remap"
        }
    }
}
