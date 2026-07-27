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
    /// Profile that was active before the first auto-switch, restored when
    /// the frontmost app has no linked profile (main thread only).
    private var profileIDBeforeAutoSwitch: UUID?

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
        guard let profile = store.profile(forApp: bundleID) else {
            // No linked profile for the new frontmost app — bring back the
            // profile that was active before the auto-switch.
            revertAfterAutoSwitchIfNeeded(store: store)
            return
        }

        // Skip when this watcher already activated that profile and it is
        // still the active one.
        if profile.id == lastAutoActivatedProfileID && profile.id == store.activeProfileID {
            return
        }

        // Remember the profile to come back to. Only capture it when the
        // current profile is NOT one this watcher activated, so hopping
        // between two linked apps keeps the original base profile.
        if store.activeProfileID != lastAutoActivatedProfileID {
            profileIDBeforeAutoSwitch = store.activeProfileID
        }

        lastAutoActivatedProfileID = profile.id
        store.activateProfile(id: profile.id)
    }

    /// Re-activates the pre-auto-switch profile when the active profile is
    /// still the one this watcher activated. A manual profile change after an
    /// auto-switch wins: it breaks that condition, so nothing is reverted.
    private func revertAfterAutoSwitchIfNeeded(store: ProfileStore) {
        guard let autoID = lastAutoActivatedProfileID,
              store.activeProfileID == autoID else { return }
        lastAutoActivatedProfileID = nil
        let baseID = profileIDBeforeAutoSwitch
        profileIDBeforeAutoSwitch = nil
        if let baseID, store.profiles.contains(where: { $0.id == baseID }) {
            store.activateProfile(id: baseID)
        } else if let fallback = store.profiles.first {
            // Base profile deleted meanwhile — fall back to the store's
            // first (default) profile.
            store.activateProfile(id: fallback.id)
        }
    }
}
