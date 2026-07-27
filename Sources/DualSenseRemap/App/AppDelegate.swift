import Foundation
import AppKit
import Combine

/// Application delegate: boots the composition root, keeps the process alive
/// as a menu bar app when the last window closes, listens for the internal
/// "open main window" notification and handles the `dualsenseremap://`
/// custom URL scheme (called from the Hammerspoon Spoon).
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var openMainWindowObserver: NSObjectProtocol?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppCoordinator.shared.startServices()

        // Posted by ActionExecutor when a controller binding fires
        // `.openMappingWindow`, and reusable by any other module.
        openMainWindowObserver = NotificationCenter.default.addObserver(
            forName: ActionExecutor.openMainWindowNotification,
            object: nil,
            queue: .main
        ) { _ in
            AppCoordinator.shared.showMainWindow()
        }
    }

    /// Menu bar app: closing the main window must not quit the process.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Clicking the Dock icon (when visible) reopens the main window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            AppCoordinator.shared.showMainWindow()
        }
        return true
    }

    deinit {
        if let observer = openMainWindowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Custom URL scheme

    /// Handles `dualsenseremap://` URLs. Supported routes:
    /// - `dualsenseremap://keyboard/toggle` — toggle the virtual keyboard
    /// - `dualsenseremap://keyboard/show`
    /// - `dualsenseremap://keyboard/hide`
    /// - `dualsenseremap://profile/next` — cycle to the next profile
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleCustomURL(url)
        }
    }

    private func handleCustomURL(_ url: URL) {
        guard url.scheme?.lowercased() == "dualsenseremap" else { return }

        // `dualsenseremap://keyboard/toggle` → host "keyboard", path "/toggle".
        let host = url.host?.lowercased() ?? ""
        let path = url.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
        let route = path.isEmpty ? host : "\(host)/\(path)"

        DispatchQueue.main.async {
            switch route {
            case "keyboard/toggle":
                VirtualKeyboardController.shared.toggle()
            case "keyboard/show":
                VirtualKeyboardController.shared.show()
            case "keyboard/hide":
                VirtualKeyboardController.shared.hide()
            case "profile/next":
                ProfileStore.shared.cycleProfile()
            default:
                break // Unknown route — ignore silently.
            }
        }
    }
}
