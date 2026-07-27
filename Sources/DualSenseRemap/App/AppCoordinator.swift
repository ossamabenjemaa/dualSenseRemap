import Foundation
import AppKit
import Combine
import SwiftUI

/// Composition root: starts every long-lived service exactly once and owns the
/// plumbing needed to bring the main window back on screen from non-UI code
/// (menu bar, URL scheme, Hammerspoon, `.openMappingWindow` action).
final class AppCoordinator {

    static let shared = AppCoordinator()

    private init() {}

    // MARK: - Main window plumbing

    /// Weak reference to the main NSWindow, captured by `ShellWindowAccessor`
    /// inside `ShellView`. Nil when the window has never been shown or has
    /// been released after closing.
    weak var mainWindow: NSWindow?

    /// `openWindow` environment action, stored from `ShellView.onAppear`.
    /// Used as a fallback when the weak window reference is gone (SwiftUI
    /// released the window after the user closed it).
    var openWindowAction: OpenWindowAction?

    // MARK: - Services

    private var servicesStarted = false

    /// Starts all engine services. Idempotent — safe to call again.
    func startServices() {
        guard !servicesStarted else { return }
        servicesStarted = true

        PermissionsManager.shared.refresh()
        // The engine must subscribe BEFORE the input layer starts:
        // DualSenseManager.start() adopts already-connected controllers
        // synchronously and emits `.connected` immediately — an unsubscribed
        // engine would miss it and never push profile feedback.
        MappingEngine.shared.start()
        DualSenseManager.shared.start()
        AppWatcher.shared.start()
    }

    // MARK: - Window management

    /// Activates the app and brings the main window to the front, reopening
    /// it through the stored `openWindow` action when it has been closed.
    func showMainWindow() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            if let window = self.resolveMainWindow() {
                window.makeKeyAndOrderFront(nil)
            } else if let openWindow = self.openWindowAction {
                openWindow(id: DualSenseRemapApp.mainWindowID)
            }
        }
    }

    /// Best-effort lookup of the main window: the captured weak reference
    /// first, then a scan of `NSApp.windows` by identifier / title.
    private func resolveMainWindow() -> NSWindow? {
        if let window = mainWindow {
            return window
        }
        return NSApp.windows.first { window in
            if let identifier = window.identifier?.rawValue,
               identifier.contains(DualSenseRemapApp.mainWindowID) {
                return true
            }
            return window.title == "DualSense Remap"
        }
    }
}

// MARK: - MappingEngineToggleModel

/// ObservableObject wrapper around `MappingEngine.shared.isEnabled` (a plain
/// thread-safe `var`), so SwiftUI toggles in the shell header and the menu
/// bar can bind to the global kill-switch and stay in sync with each other.
final class MappingEngineToggleModel: ObservableObject {

    static let shared = MappingEngineToggleModel()

    @Published var isEnabled: Bool {
        didSet {
            // Push to the engine only on real change (avoids feedback loops).
            if MappingEngine.shared.isEnabled != isEnabled {
                MappingEngine.shared.isEnabled = isEnabled
            }
        }
    }

    private init() {
        isEnabled = MappingEngine.shared.isEnabled
    }

    /// Re-reads the engine state (in case something else flipped the switch).
    func refreshFromEngine() {
        let engineValue = MappingEngine.shared.isEnabled
        DispatchQueue.main.async {
            if self.isEnabled != engineValue {
                self.isEnabled = engineValue
            }
        }
    }
}
