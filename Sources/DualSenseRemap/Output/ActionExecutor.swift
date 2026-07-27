import Foundation
import AppKit

/// Executes every `Action` case in response to controller button edges.
///
/// Threading model: `execute(_:phase:)` is cheap and non-blocking for the
/// caller (the mapping engine's event path). Anything that sleeps or spawns a
/// process (typeText, macros, shell commands) is dispatched to a background
/// queue; anything that touches AppKit/`@Published` state hops to the main
/// queue.
final class ActionExecutor {

    static let shared = ActionExecutor()

    /// Notification posted (with `NSApp` activation) by `.openMappingWindow`;
    /// the App layer observes it and brings up the main window.
    static let openMainWindowNotification = Notification.Name("DualSenseRemap.openMainWindow")

    /// Hammerspoon event names that have a documented native equivalent.
    /// When `HammerspoonBridge.trigger` returns `false` (Hammerspoon absent)
    /// these degrade gracefully to the matching `SystemAction`.
    private static let hammerspoonNativeFallbacks: [String: SystemAction] = [
        "launchpad": .launchpad,
        "openLaunchpad": .launchpad, // legacy Spoon action name
        "missionControl": .missionControl,
        "showDesktop": .showDesktop,
    ]

    /// Serial queue for blocking work (unicode typing, macros).
    private let workQueue = DispatchQueue(label: "com.dualsenseremap.output.actionexecutor",
                                          qos: .userInitiated)

    /// Shell processes still running (retained until termination so ARC does
    /// not reap them mid-flight).
    private let processLock = NSLock()
    private var runningProcesses: Set<Process> = []

    private init() {}

    /// Executes `action` for the given phase. Discrete actions fire on
    /// `.down`; key combos and mouse buttons track both phases so holds and
    /// drags feel like real hardware.
    func execute(_ action: Action, phase: ActionPhase) {
        switch action {
        case .none:
            break

        case .keyCombo(let combo):
            EventSynthesizer.post(combo, down: phase == .down)

        case .typeText(let text):
            guard phase == .down else { return }
            workQueue.async {
                EventSynthesizer.typeText(text)
            }

        case .mouse(let buttonAction):
            // The synthesizer owns doubleClick / dragToggle semantics
            // (both act on .down only and ignore .up).
            EventSynthesizer.mouseButton(buttonAction, phase: phase)

        case .system(let systemAction):
            guard phase == .down else { return }
            OutputSystemActions.perform(systemAction)

        case .hammerspoon(let event):
            guard phase == .down else { return }
            executeHammerspoonEvent(event)

        case .shellCommand(let command):
            guard phase == .down else { return }
            runShellCommand(command)

        case .openApp(let bundleID, _):
            guard phase == .down else { return }
            DispatchQueue.main.async {
                guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                    return
                }
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                NSWorkspace.shared.openApplication(at: url,
                                                   configuration: configuration,
                                                   completionHandler: nil)
            }

        case .openURL(let urlString):
            guard phase == .down, let url = URL(string: urlString) else { return }
            DispatchQueue.main.async {
                NSWorkspace.shared.open(url)
            }

        case .macro(_, let steps):
            guard phase == .down else { return }
            workQueue.async {
                for step in steps {
                    switch step {
                    case .keyCombo(let combo):
                        EventSynthesizer.tap(combo)
                    case .text(let text):
                        EventSynthesizer.typeText(text)
                    case .wait(let milliseconds):
                        if milliseconds > 0 {
                            usleep(useconds_t(milliseconds) * 1000)
                        }
                    }
                }
            }

        case .toggleVirtualKeyboard:
            guard phase == .down else { return }
            DispatchQueue.main.async {
                VirtualKeyboardController.shared.toggle()
            }

        case .cycleProfile:
            guard phase == .down else { return }
            DispatchQueue.main.async {
                ProfileStore.shared.cycleProfile()
            }

        case .openMappingWindow:
            guard phase == .down else { return }
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                NotificationCenter.default.post(name: Self.openMainWindowNotification, object: nil)
            }
        }
    }

    // MARK: - Hammerspoon dispatch

    private func executeHammerspoonEvent(_ event: String) {
        let hammerspoonEnabled = ProfileStore.shared.settings.hammerspoonEnabled
        let delivered = hammerspoonEnabled
            ? HammerspoonBridge.shared.trigger(event, params: [:])
            : false
        if !delivered, let fallback = Self.hammerspoonNativeFallbacks[event] {
            OutputSystemActions.perform(fallback)
        }
    }

    // MARK: - Shell commands

    /// Runs a shell command through `/bin/zsh -lc`, fully detached from the
    /// caller thread. The process is force-terminated after 10 seconds.
    private func runShellCommand(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        workQueue.async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", trimmed]
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { [weak self] finished in
                guard let self else { return }
                self.processLock.lock()
                self.runningProcesses.remove(finished)
                self.processLock.unlock()
            }

            do {
                try process.run()
            } catch {
                return // command not runnable — nothing else to do
            }

            guard let self else { return }
            self.processLock.lock()
            self.runningProcesses.insert(process)
            self.processLock.unlock()

            // 10 s timeout: terminate, then SIGKILL if it ignores SIGTERM.
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 10) {
                guard process.isRunning else { return }
                process.terminate()
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                    if process.isRunning {
                        kill(process.processIdentifier, SIGKILL)
                    }
                }
            }
        }
    }
}
