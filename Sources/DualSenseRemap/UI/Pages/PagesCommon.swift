import Foundation
import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

// MARK: - Palette
//
// Self-contained design tokens for the Pages area. Deliberately does NOT
// reference the Shell design system (`DS`) so this module compiles even if
// the shell tokens are renamed. Values match the shared design spec.
enum VKPagesPalette {
    /// "Pulse Blue" accent — interaction & selection only.
    static let accent = Color(red: 0.18, green: 0.44, blue: 0.95)
    static let accentTint = accent.opacity(0.12)
    static let accentGlow = accent.opacity(0.45)

    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let insetBackground = Color(nsColor: .underPageBackgroundColor)
    static let separator = Color(nsColor: .separatorColor)

    static let textPrimary = Color(nsColor: .labelColor)
    static let textSecondary = Color(nsColor: .secondaryLabelColor)
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)

    static let success = Color(red: 0.18, green: 0.64, blue: 0.31)
    static let warning = Color(red: 0.82, green: 0.53, blue: 0.10)
    static let danger = Color(red: 0.84, green: 0.27, blue: 0.27)

    // PS5-style dark keyboard preview.
    static let keyboardBackground = Color(red: 0.09, green: 0.10, blue: 0.13)
    static let keyCapFill = Color.white.opacity(0.08)
    static let keyCapStroke = Color.white.opacity(0.07)

    static let cardRadius: CGFloat = 12
    static let controlRadius: CGFloat = 8

    /// 0.15 s eased state animation used across the pages.
    static let quick = Animation.easeInOut(duration: 0.15)
}

// MARK: - Card chrome

/// Standard card for the Pages area: 12 pt rounded rectangle, adaptive
/// surface, 1 px hairline border, soft shadow.
struct VKPagesCardModifier: ViewModifier {
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: VKPagesPalette.cardRadius, style: .continuous)
                    .fill(VKPagesPalette.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VKPagesPalette.cardRadius, style: .continuous)
                    .strokeBorder(VKPagesPalette.separator.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

extension View {
    /// Wraps the view in the Pages card chrome.
    func pagesCard(padding: CGFloat = 20) -> some View {
        modifier(VKPagesCardModifier(padding: padding))
    }
}

// MARK: - Section header

struct PagesSectionHeader: View {
    let title: String
    var subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(VKPagesPalette.textPrimary)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(VKPagesPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Button styles

struct PagesPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: VKPagesPalette.controlRadius, style: .continuous)
                    .fill(VKPagesPalette.accent.opacity(configuration.isPressed ? 0.75 : 1.0))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(VKPagesPalette.quick, value: configuration.isPressed)
    }
}

struct PagesSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(VKPagesPalette.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: VKPagesPalette.controlRadius, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: VKPagesPalette.controlRadius, style: .continuous)
                    .strokeBorder(VKPagesPalette.separator.opacity(0.6), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(VKPagesPalette.quick, value: configuration.isPressed)
    }
}

/// Small suggestion chip (used for Hammerspoon event names, etc.).
struct PagesChipButtonStyle: ButtonStyle {
    var isSelected: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(isSelected ? .white : VKPagesPalette.textPrimary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isSelected
                          ? VKPagesPalette.accent
                          : Color.primary.opacity(configuration.isPressed ? 0.12 : 0.06))
            )
            .overlay(
                Capsule().strokeBorder(VKPagesPalette.separator.opacity(0.5), lineWidth: 1)
            )
            .animation(VKPagesPalette.quick, value: isSelected)
    }
}

// MARK: - Key names & modifier mapping

/// Human-readable names for macOS virtual key codes (raw values used on
/// purpose so this file does not need Carbon).
enum PagesKeyNames {
    static func name(for keyCode: UInt16, characters: String?) -> String {
        switch keyCode {
        case 36: return "↩"
        case 48: return "⇥"
        case 49: return "Espace"
        case 51: return "⌫"
        case 53: return "⎋"
        case 76: return "⌤"
        case 117: return "⌦"
        case 115: return "↖"
        case 119: return "↘"
        case 116: return "⇞"
        case 121: return "⇟"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default:
            if let chars = characters, !chars.isEmpty {
                return chars.uppercased()
            }
            return "#\(keyCode)"
        }
    }

    /// Maps AppKit modifier flags to the Core `KeyModifiers` option set.
    static func modifiers(from flags: NSEvent.ModifierFlags) -> KeyModifiers {
        var mods: KeyModifiers = []
        if flags.contains(.command) { mods.insert(.command) }
        if flags.contains(.option) { mods.insert(.option) }
        if flags.contains(.control) { mods.insert(.control) }
        if flags.contains(.shift) { mods.insert(.shift) }
        return mods
    }

    /// Builds a `KeyCombo` (with a human label) from a captured key event.
    static func combo(from event: NSEvent) -> KeyCombo {
        let mods = modifiers(from: event.modifierFlags)
        let keyName = name(for: event.keyCode, characters: event.charactersIgnoringModifiers)
        return KeyCombo(keyCode: event.keyCode,
                        modifiers: mods,
                        label: mods.displaySymbols + keyName)
    }
}

// MARK: - Key recorder

/// Records a single keystroke via a local event monitor. UI shows a
/// "recording" state while active; the captured combo is delivered through
/// the completion handler on the main thread.
final class PagesKeyRecorder: ObservableObject {
    @Published private(set) var isRecording = false

    private var monitor: Any?
    private var completion: ((KeyCombo) -> Void)?

    func begin(_ handler: @escaping (KeyCombo) -> Void) {
        cancel()
        completion = handler
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            let combo = PagesKeyNames.combo(from: event)
            DispatchQueue.main.async {
                self.finish(with: combo)
            }
            return nil // consume the keystroke while recording
        }
    }

    func cancel() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        completion = nil
        isRecording = false
    }

    private func finish(with combo: KeyCombo) {
        let handler = completion
        cancel()
        handler?(combo)
    }

    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

// MARK: - Application picking & icons

struct PagesAppInfo: Equatable {
    var bundleID: String
    var name: String
    var url: URL
}

enum PagesAppPicker {
    /// Opens an NSOpenPanel rooted at /Applications and returns the selected
    /// application's bundle id + localized name. Returns nil on cancel or
    /// when the selection has no bundle identifier.
    static func pickApplication() -> PagesAppInfo? {
        let panel = NSOpenPanel()
        panel.title = "Choisir une application"
        panel.prompt = "Choisir"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.applicationBundle]

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard let bundleID = Bundle(url: url)?.bundleIdentifier else { return nil }
        var name = FileManager.default.displayName(atPath: url.path)
        if name.hasSuffix(".app") {
            name = String(name.dropLast(4))
        }
        return PagesAppInfo(bundleID: bundleID, name: name, url: url)
    }
}

/// Resolves and caches application icons / names from bundle identifiers.
/// Main-thread only (called from SwiftUI view bodies).
enum PagesAppIconResolver {
    private static var iconCache: [String: NSImage] = [:]
    private static var nameCache: [String: String] = [:]

    static func icon(forBundleID bundleID: String) -> NSImage? {
        if let cached = iconCache[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        iconCache[bundleID] = image
        return image
    }

    static func name(forBundleID bundleID: String) -> String {
        if let cached = nameCache[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return bundleID
        }
        var name = FileManager.default.displayName(atPath: url.path)
        if name.hasSuffix(".app") {
            name = String(name.dropLast(4))
        }
        nameCache[bundleID] = name
        return name
    }
}

// MARK: - SF symbols for system actions

enum PagesSystemActionSymbols {
    /// Conservative SF Symbol names (macOS 11-era) for each system action.
    static func symbol(for action: SystemAction) -> String {
        switch action {
        case .launchpad: return "square.grid.3x2"
        case .missionControl: return "square.grid.2x2"
        case .applicationWindows: return "macwindow.on.rectangle"
        case .showDesktop: return "menubar.dock.rectangle"
        case .spotlight: return "magnifyingglass"
        case .appSwitcher: return "arrow.left.arrow.right"
        case .mediaPlayPause: return "playpause.fill"
        case .mediaNext: return "forward.fill"
        case .mediaPrevious: return "backward.fill"
        case .volumeUp: return "speaker.wave.3.fill"
        case .volumeDown: return "speaker.wave.1.fill"
        case .volumeMute: return "speaker.slash.fill"
        case .brightnessUp: return "sun.max.fill"
        case .brightnessDown: return "sun.min"
        case .screenshotArea: return "camera.viewfinder"
        case .lockScreen: return "lock.fill"
        case .nextTab: return "arrow.right.square"
        case .previousTab: return "arrow.left.square"
        case .copy: return "doc.on.doc"
        case .paste: return "doc.on.clipboard"
        case .undo: return "arrow.uturn.backward"
        }
    }
}

// MARK: - Short element names for callouts

enum PagesElementNames {
    /// Compact label used in the Logi-style callout columns.
    static func short(for element: ControllerElement) -> String {
        switch element {
        case .cross: return "✕ Croix"
        case .circle: return "○ Rond"
        case .square: return "□ Carré"
        case .triangle: return "△ Triangle"
        case .l1: return "L1"
        case .r1: return "R1"
        case .l2: return "L2"
        case .r2: return "R2"
        case .touchpadClick: return "Pavé (clic)"
        case .create: return "Create"
        case .options: return "Options"
        case .ps: return "PS"
        case .mute: return "Micro"
        default: return element.displayName
        }
    }
}
