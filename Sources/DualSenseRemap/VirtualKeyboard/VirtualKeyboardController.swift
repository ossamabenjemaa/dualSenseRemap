import Foundation
import Combine
import AppKit
import SwiftUI
import QuartzCore

/// Borderless panel that can NEVER become key or main: the frontmost app keeps
/// keyboard focus the whole time, so synthesized CGEvents land in its focused
/// text field (see docs/research/ps5-keyboard-hammerspoon.md, A.9).
final class VKPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Public contract of the VirtualKeyboard module (see docs/ARCHITECTURE.md).
/// Owns the non-activating overlay panel and routes controller events to the
/// interaction model while visible.
final class VirtualKeyboardController: ObservableObject {

    static let shared = VirtualKeyboardController()

    @Published private(set) var isVisible: Bool = false

    /// Thread-safe mirror of `isVisible` for non-main callers (the mapping
    /// engine's serial queue reads it on every event and tick).
    var isCurrentlyVisible: Bool {
        visibleLock.lock()
        defer { visibleLock.unlock() }
        return visibleFlag
    }

    // MARK: Private state

    private let model = VKModel()
    private var panel: VKPanel?

    /// Mirror of the visibility state readable from any queue —
    /// `handle(_:)` is called synchronously from the engine queue.
    private let visibleLock = NSLock()
    private var visibleFlag = false

    private enum VKPanelMetrics {
        static let bottomMargin: CGFloat = 24
        static let slideDistance: CGFloat = 24
        static let showDuration: TimeInterval = 0.22
        static let hideDuration: TimeInterval = 0.16
        static let minScale: Double = 0.5
        static let maxScale: Double = 2.0
    }

    private init() {
        model.onDismiss = { [weak self] in self?.hide() }
    }

    // MARK: Public API

    func show() {
        runOnMain { self.showOnMain() }
    }

    func hide() {
        runOnMain { self.hideOnMain() }
    }

    func toggle() {
        runOnMain {
            if self.isVisible {
                self.hideOnMain()
            } else {
                self.showOnMain()
            }
        }
    }

    /// Consumes controller events while visible. Returns true when consumed.
    /// Called synchronously from the mapping-engine queue: the consumption
    /// decision is made here, the actual processing hops to the main thread.
    func handle(_ event: ControllerEvent) -> Bool {
        switch event {
        case .battery, .connected, .disconnected:
            return false // never the keyboard's business
        default:
            break
        }
        visibleLock.lock()
        let visible = visibleFlag
        visibleLock.unlock()
        guard visible else { return false }
        let model = self.model
        DispatchQueue.main.async {
            model.process(event)
        }
        return true
    }

    // MARK: Main-thread implementation

    private func showOnMain() {
        let panel = ensurePanel()
        let scale = clampedScale()
        model.scale = scale
        let frame = targetFrame(scale: scale)

        if isVisible {
            // Already up: just reposition (screen or scale may have changed).
            panel.setFrame(frame, display: true)
            return
        }

        model.prepareForShow()
        setVisible(true)

        // Fade + slide-in from slightly below the resting position.
        var startFrame = frame
        startFrame.origin.y -= VKPanelMetrics.slideDistance
        panel.setFrame(startFrame, display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = VKPanelMetrics.showDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(frame, display: true)
        }
    }

    private func hideOnMain() {
        guard isVisible else { return }
        model.prepareForHide()
        setVisible(false)

        guard let panel else { return }
        var endFrame = panel.frame
        endFrame.origin.y -= VKPanelMetrics.slideDistance

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = VKPanelMetrics.hideDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(endFrame, display: true)
        }, completionHandler: { [weak self] in
            guard let self, !self.isVisible else { return } // re-shown meanwhile
            panel.orderOut(nil)
        })
    }

    private func setVisible(_ visible: Bool) {
        visibleLock.lock()
        visibleFlag = visible
        visibleLock.unlock()
        isVisible = visible // main thread — safe for @Published
    }

    // MARK: Panel construction & placement

    private func ensurePanel() -> VKPanel {
        if let panel { return panel }

        let contentRect = NSRect(
            x: 0, y: 0,
            width: VKMetrics.baseWidth,
            height: VKMetrics.baseHeight
        )
        let newPanel = VKPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.becomesKeyOnlyIfNeeded = true
        newPanel.level = .statusBar
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isReleasedWhenClosed = false
        newPanel.hidesOnDeactivate = false
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.hasShadow = true
        newPanel.isMovableByWindowBackground = false
        newPanel.contentView = NSHostingView(rootView: VKPanelRootView(model: model))

        panel = newPanel
        return newPanel
    }

    private func clampedScale() -> Double {
        let raw = ProfileStore.shared.settings.virtualKeyboardScale
        guard raw.isFinite, raw > 0 else { return 1.0 }
        return min(max(raw, VKPanelMetrics.minScale), VKPanelMetrics.maxScale)
    }

    /// Bottom-center of the active screen, just above the Dock edge.
    private func targetFrame(scale: Double) -> NSRect {
        let visibleFrame: NSRect
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            visibleFrame = screen.visibleFrame
        } else {
            visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
        }
        let width = VKMetrics.baseWidth * CGFloat(scale)
        let height = VKMetrics.baseHeight * CGFloat(scale)
        let x = visibleFrame.midX - width / 2
        let y = visibleFrame.minY + VKPanelMetrics.bottomMargin
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func runOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}

/// Root SwiftUI view of the panel: renders the keyboard at its base size and
/// applies the user's keyboard scale, so the hosting view always matches the
/// panel's scaled frame.
struct VKPanelRootView: View {
    @ObservedObject var model: VKModel

    var body: some View {
        VKKeyboardView(model: model)
            .frame(width: VKMetrics.baseWidth, height: VKMetrics.baseHeight)
            .scaleEffect(model.scale, anchor: .center)
            .frame(
                width: VKMetrics.baseWidth * CGFloat(model.scale),
                height: VKMetrics.baseHeight * CGFloat(model.scale)
            )
    }
}
