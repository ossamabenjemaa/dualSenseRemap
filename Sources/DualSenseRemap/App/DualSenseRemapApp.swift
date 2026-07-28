import SwiftUI
import AppKit
import Combine

/// App entry point: one main window (the Logi Options+-style shell) plus a
/// menu bar extra whose presence follows `AppSettings.showMenuBarIcon`.
@main
struct DualSenseRemapApp: App {

    /// Identifier of the main `Window` scene.
    static let mainWindowID = "main"

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @ObservedObject private var profileStore = ProfileStore.shared

    var body: some Scene {
        Window("DualSense Remap", id: Self.mainWindowID) {
            ShellView()
        }
        .defaultSize(width: 1080, height: 720)
        .windowResizability(.contentMinSize)

        MenuBarExtra(
            "DualSense Remap",
            systemImage: "gamecontroller.fill",
            isInserted: $profileStore.settings.showMenuBarIcon
        ) {
            AppMenuBarContent()
        }
    }
}

// MARK: - Menu bar content

/// Native pull-down menu shown by the menu bar extra: connection + battery
/// status, mapping kill-switch, profile picker, virtual keyboard toggle,
/// and window / quit commands.
struct AppMenuBarContent: View {

    // Scene-level UI observes the low-rate status feed, never the full
    // high-rate manager — see ControllerStatusModel for why.
    @ObservedObject private var controllerStatus = ControllerStatusModel.shared
    @ObservedObject private var profileStore = ProfileStore.shared
    @ObservedObject private var mappingModel = MappingEngineToggleModel.shared
    @ObservedObject private var keyboard = VirtualKeyboardController.shared

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // Connection status line (disabled informative row).
        Text(connectionStatusLine)

        Divider()

        Toggle("Mappage actif", isOn: $mappingModel.isEnabled)

        Menu("Profils") {
            ForEach(profileStore.profiles) { profile in
                Toggle(profile.name, isOn: profileActivationBinding(for: profile))
            }
        }

        Toggle("Clavier virtuel", isOn: virtualKeyboardBinding)

        Divider()

        Button("Ouvrir DualSense Remap") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: DualSenseRemapApp.mainWindowID)
            AppCoordinator.shared.showMainWindow()
        }

        Divider()

        Button("Quitter") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    // MARK: Helpers

    private var connectionStatusLine: String {
        let snapshot = controllerStatus.status
        guard snapshot.isConnected else {
            return "Manette non connectée"
        }
        let name = snapshot.name.isEmpty ? "DualSense" : snapshot.name
        let percent = Int((snapshot.battery.level * 100).rounded())
        switch snapshot.battery.state {
        case .charging:
            return "\(name) — \(percent) % (en charge)"
        case .full:
            return "\(name) — 100 %"
        case .discharging, .unknown:
            return "\(name) — \(percent) %"
        }
    }

    /// Checkmark-style profile row: on = active profile; selecting activates.
    private func profileActivationBinding(for profile: Profile) -> Binding<Bool> {
        Binding(
            get: { profileStore.activeProfile.id == profile.id },
            set: { isOn in
                if isOn {
                    profileStore.activateProfile(id: profile.id)
                }
            }
        )
    }

    private var virtualKeyboardBinding: Binding<Bool> {
        Binding(
            get: { keyboard.isVisible },
            set: { _ in keyboard.toggle() }
        )
    }
}
