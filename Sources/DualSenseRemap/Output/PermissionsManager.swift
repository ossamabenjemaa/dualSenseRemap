import Foundation
import Combine
import AppKit
import ApplicationServices
import IOKit
import IOKit.hid

/// Privacy & Security panes the app can deep-link to.
enum PermissionPane {
    case accessibility
    case inputMonitoring
}

/// Observes the two TCC permissions the app depends on:
/// - **Accessibility** — required to post CGEvents (all output synthesis).
/// - **Input Monitoring** — required by the IOHID mute-button listener.
///
/// `refresh()` re-reads both grants; while the onboarding UI is visible call
/// `startPolling()` so the checkmarks flip live as the user toggles the
/// switches in System Settings (macOS does not notify TCC changes).
/// All `@Published` mutations happen on the main thread.
final class PermissionsManager: ObservableObject {

    static let shared = PermissionsManager()

    @Published private(set) var accessibilityGranted: Bool = false
    @Published private(set) var inputMonitoringGranted: Bool = false

    /// Polling cadence while onboarding is on screen.
    private static let pollInterval: TimeInterval = 2

    private var pollTimer: Timer?

    private init() {
        refresh()
    }

    // MARK: - State

    /// Re-reads both permission grants and publishes the result on the main
    /// thread.
    func refresh() {
        let accessibility = AXIsProcessTrusted()
        let inputMonitoring = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted

        let apply = { [weak self] in
            guard let self else { return }
            if self.accessibilityGranted != accessibility {
                self.accessibilityGranted = accessibility
            }
            if self.inputMonitoringGranted != inputMonitoring {
                self.inputMonitoringGranted = inputMonitoring
            }
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    /// Starts a 2-second polling timer (main run loop). Call while the
    /// onboarding / permissions UI is visible; idempotent.
    func startPolling() {
        let start = { [weak self] in
            guard let self else { return }
            guard self.pollTimer == nil else { return }
            self.refresh()
            let timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval,
                                             repeats: true) { [weak self] _ in
                self?.refresh()
            }
            timer.tolerance = 0.5
            self.pollTimer = timer
        }
        if Thread.isMainThread {
            start()
        } else {
            DispatchQueue.main.async(execute: start)
        }
    }

    /// Stops the polling timer.
    func stopPolling() {
        let stop = { [weak self] in
            self?.pollTimer?.invalidate()
            self?.pollTimer = nil
        }
        if Thread.isMainThread {
            stop()
        } else {
            DispatchQueue.main.async(execute: stop)
        }
    }

    // MARK: - Prompts

    /// Shows the system Accessibility consent dialog (once per TCC reset) and
    /// refreshes the published state.
    func promptAccessibility() {
        // takeUnretainedValue: the constant is an unowned global CFString —
        // taking a retained value would over-release it.
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refresh()
    }

    /// Requests Input Monitoring access (shows the system dialog when the
    /// user has not decided yet) and refreshes the published state.
    func promptInputMonitoring() {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        refresh()
    }

    // MARK: - System Settings deep links

    /// Opens System Settings directly on the relevant Privacy & Security pane.
    func openSystemSettings(pane: PermissionPane) {
        let urlString: String
        switch pane {
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .inputMonitoring:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        }
        guard let url = URL(string: urlString) else { return }
        DispatchQueue.main.async {
            NSWorkspace.shared.open(url)
        }
    }
}
