import Foundation
import AppKit

/// Watches the frontmost application and auto-activates the profile linked to
/// it (when `AppSettings.autoSwitchProfiles` is on).
///
/// Uses `NSWorkspace.didActivateApplicationNotification` on NSWorkspace's own
/// notification center, delivered on the main queue — so every
/// `ProfileStore` mutation it triggers already happens on the main thread.
final class AppWatcher {

    static let shared = AppWatcher()

    /// Observation token for the workspace notification (main thread only).
    private var observationToken: NSObjectProtocol?
    /// Last profile auto-activated by this watcher, to avoid redundant
    /// switches when the same app keeps regaining focus.
    private var lastAutoActivatedProfileID: UUID?

    private init() {}

    deinit {
        if let token = observationToken {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
    }

    func start() {
        guard observationToken == nil else { return }
        observationToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.handleFrontmostChange(bundleID: app?.bundleIdentifier)
        }
    }

    // MARK: - Private

    /// Runs on the main thread (observer queue is `.main`).
    private func handleFrontmostChange(bundleID: String?) {
        guard let bundleID, !bundleID.isEmpty else { return }

        // Never react to our own app coming to the foreground.
        if let ownBundleID = Bundle.main.bundleIdentifier, ownBundleID == bundleID {
            return
        }

        let store = ProfileStore.shared
        guard store.settings.autoSwitchProfiles else { return }
        guard let profile = store.profile(forApp: bundleID) else { return }

        // Skip when this watcher already activated that profile and it is
        // still the active one.
        if profile.id == lastAutoActivatedProfileID && profile.id == store.activeProfileID {
            return
        }

        lastAutoActivatedProfileID = profile.id
        store.activateProfile(id: profile.id)
    }
}
