import Foundation
import AppKit
import CoreGraphics

// MARK: - Shared output types

/// Phase of a digital action: button pressed (`.down`) or released (`.up`).
/// Part of the Output module public contract (see docs/ARCHITECTURE.md).
enum ActionPhase {
    case down
    case up
}

/// Media / system aux keys posted through `NSEvent` `.systemDefined` events.
/// Raw values are the `NX_KEYTYPE_*` constants from
/// `IOKit/hidsystem/ev_keymap.h` (SOUND_UP=0, SOUND_DOWN=1, BRIGHTNESS_UP=2,
/// BRIGHTNESS_DOWN=3, MUTE=7, PLAY=16, NEXT=17, PREVIOUS=18).
enum MediaKey: Int, CaseIterable, Hashable {
    case volumeUp = 0        // NX_KEYTYPE_SOUND_UP
    case volumeDown = 1      // NX_KEYTYPE_SOUND_DOWN
    case brightnessUp = 2    // NX_KEYTYPE_BRIGHTNESS_UP
    case brightnessDown = 3  // NX_KEYTYPE_BRIGHTNESS_DOWN
    case mute = 7            // NX_KEYTYPE_MUTE
    case playPause = 16      // NX_KEYTYPE_PLAY
    case next = 17           // NX_KEYTYPE_NEXT
    case previous = 18       // NX_KEYTYPE_PREVIOUS
}

// MARK: - Internal synthesis state

/// Mutable state shared by the static `EventSynthesizer` functions.
/// Guarded by a lock — the mapping engine's continuous loop and the action
/// executor may call in from different queues.
private final class OutputSynthesizerState {
    let lock = NSLock()

    /// Left button held because of a plain `leftClick` press (down → up).
    var physicalLeftHeld = false
    /// Left button held because of the `dragToggle` latch.
    var dragLockActive = false
    /// Fractional scroll remainders, accumulated across calls so slow analog
    /// scrolling still produces motion.
    var scrollRemainderX: Double = 0
    var scrollRemainderY: Double = 0

    var syntheticLeftDown: Bool { physicalLeftHeld || dragLockActive }
}

// MARK: - EventSynthesizer

/// Low-level CGEvent synthesis: keyboard, unicode text, mouse, scroll and
/// media keys. Requires the Accessibility permission (see `PermissionsManager`).
///
/// Coordinate convention: all mouse positions are **CG global display
/// coordinates** — origin at the top-left corner of the primary display,
/// y increasing downwards (the opposite of AppKit's `NSScreen` frames).
enum EventSynthesizer {

    /// Single event source for every synthesized event, in the HID system
    /// state so events are indistinguishable from hardware input.
    private static let source = CGEventSource(stateID: .hidSystemState)

    private static let state = OutputSynthesizerState()

    /// Max UTF-16 code units per unicode keyboard event; longer strings are
    /// truncated by the system, so `typeText` chunks at this size.
    private static let unicodeChunkLimit = 20

    // MARK: Keyboard

    /// Posts a full press (down + up) of the combo.
    static func tap(_ combo: KeyCombo) {
        post(combo, down: true)
        post(combo, down: false)
    }

    /// Posts one keyboard event for the combo (`down` or `up`), with the
    /// modifier flags applied directly on the event.
    static func post(_ combo: KeyCombo, down: Bool) {
        guard let event = CGEvent(keyboardEventSource: source,
                                  virtualKey: CGKeyCode(combo.keyCode),
                                  keyDown: down) else { return }
        event.flags = cgFlags(for: combo.modifiers)
        event.post(tap: .cghidEventTap)
    }

    /// Types arbitrary unicode text, independent of the active keyboard
    /// layout: accents, œ, €, emoji all arrive as literal characters.
    ///
    /// The string is chunked into events of at most 20 UTF-16 code units
    /// (surrogate pairs are never split across chunks) with a 1 ms pause
    /// between chunks so slow receivers keep up.
    ///
    /// Note: this call sleeps between chunks — invoke it from a background
    /// queue for long strings (ActionExecutor does).
    static func typeText(_ text: String) {
        guard !text.isEmpty else { return }

        var chunk: [UniChar] = []
        chunk.reserveCapacity(unicodeChunkLimit)
        var isFirstChunk = true

        func flush() {
            guard !chunk.isEmpty else { return }
            if !isFirstChunk {
                usleep(1000) // 1 ms between chunks
            }
            isFirstChunk = false
            if let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                down.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
                down.post(tap: .cghidEventTap)
            }
            if let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                up.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
                up.post(tap: .cghidEventTap)
            }
            chunk.removeAll(keepingCapacity: true)
        }

        for scalar in text.unicodeScalars {
            let units = Array(String(scalar).utf16)
            // Never split a scalar (surrogate pair) across two events.
            if chunk.count + units.count > unicodeChunkLimit {
                flush()
            }
            chunk.append(contentsOf: units)
        }
        flush()
    }

    // MARK: Mouse movement

    /// Moves the pointer by a relative delta (CG coordinates: +dy = down),
    /// clamped to the union of all screens. Posts `.leftMouseDragged` while
    /// the synthetic left button is down so drags work.
    static func moveMouse(dx: Double, dy: Double) {
        let current = currentMouseLocation()
        let target = clampToScreens(CGPoint(x: current.x + dx, y: current.y + dy))
        postMove(to: target, dx: dx, dy: dy)
    }

    /// Moves the pointer to an absolute CG global position (clamped).
    static func moveMouse(to point: CGPoint) {
        let current = currentMouseLocation()
        let target = clampToScreens(point)
        postMove(to: target, dx: Double(target.x - current.x), dy: Double(target.y - current.y))
    }

    private static func postMove(to target: CGPoint, dx: Double, dy: Double) {
        state.lock.lock()
        let dragging = state.syntheticLeftDown
        state.lock.unlock()

        let type: CGEventType = dragging ? .leftMouseDragged : .mouseMoved
        guard let event = CGEvent(mouseEventSource: source,
                                  mouseType: type,
                                  mouseCursorPosition: target,
                                  mouseButton: .left) else { return }
        // Relative deltas: pointer-lock apps and games read these fields.
        event.setIntegerValueField(.mouseEventDeltaX, value: Int64(dx.rounded()))
        event.setIntegerValueField(.mouseEventDeltaY, value: Int64(dy.rounded()))
        event.post(tap: .cghidEventTap)
    }

    // MARK: Mouse buttons

    /// Posts mouse button events at the current pointer location.
    ///
    /// Semantics:
    /// - `leftClick` / `rightClick` / `middleClick`: down on `.down`, up on `.up`.
    /// - `doubleClick`: full down+up pair with click state 2, on `.down` only.
    /// - `dragToggle`: latches/unlatches a persistent left-button-down state,
    ///   on `.down` only (subsequent `moveMouse` calls post drag events).
    static func mouseButton(_ action: MouseButtonAction, phase: ActionPhase) {
        let location = currentMouseLocation()

        switch action {
        case .leftClick:
            if phase == .down {
                state.lock.lock()
                state.physicalLeftHeld = true
                state.lock.unlock()
                postButton(.leftMouseDown, at: location, button: .left, clickState: 1)
            } else {
                state.lock.lock()
                state.physicalLeftHeld = false
                let stillLatched = state.dragLockActive
                state.lock.unlock()
                // If the drag latch is active, keep the button virtually down.
                if !stillLatched {
                    postButton(.leftMouseUp, at: location, button: .left, clickState: 1)
                }
            }

        case .rightClick:
            postButton(phase == .down ? .rightMouseDown : .rightMouseUp,
                       at: location, button: .right, clickState: 1)

        case .middleClick:
            postButton(phase == .down ? .otherMouseDown : .otherMouseUp,
                       at: location, button: .center, clickState: 1, buttonNumber: 2)

        case .doubleClick:
            guard phase == .down else { return }
            postButton(.leftMouseDown, at: location, button: .left, clickState: 2)
            postButton(.leftMouseUp, at: location, button: .left, clickState: 2)

        case .dragToggle:
            guard phase == .down else { return }
            state.lock.lock()
            let wasActive = state.dragLockActive
            state.dragLockActive = !wasActive
            let physicallyHeld = state.physicalLeftHeld
            state.lock.unlock()
            if wasActive {
                // Release the latch (unless a plain left click is still held).
                if !physicallyHeld {
                    postButton(.leftMouseUp, at: location, button: .left, clickState: 1)
                }
            } else {
                postButton(.leftMouseDown, at: location, button: .left, clickState: 1)
            }
        }
    }

    private static func postButton(_ type: CGEventType,
                                   at location: CGPoint,
                                   button: CGMouseButton,
                                   clickState: Int64,
                                   buttonNumber: Int64? = nil) {
        guard let event = CGEvent(mouseEventSource: source,
                                  mouseType: type,
                                  mouseCursorPosition: location,
                                  mouseButton: button) else { return }
        event.setIntegerValueField(.mouseEventClickState, value: clickState)
        if let buttonNumber {
            event.setIntegerValueField(.mouseEventButtonNumber, value: buttonNumber)
        }
        event.post(tap: .cghidEventTap)
    }

    // MARK: Scroll

    /// Pixel-precise scroll. `dy > 0` scrolls up, `dx > 0` scrolls right
    /// content-wise (wheel semantics: wheel1 = vertical, wheel2 = horizontal).
    /// Fractional deltas below one pixel are accumulated across calls.
    static func scroll(dx: Double, dy: Double) {
        state.lock.lock()
        state.scrollRemainderX += dx
        state.scrollRemainderY += dy
        let ix = Int32(state.scrollRemainderX)
        let iy = Int32(state.scrollRemainderY)
        state.scrollRemainderX -= Double(ix)
        state.scrollRemainderY -= Double(iy)
        state.lock.unlock()

        guard ix != 0 || iy != 0 else { return }
        guard let event = CGEvent(scrollWheelEvent2Source: source,
                                  units: .pixel,
                                  wheelCount: 2,
                                  wheel1: iy,
                                  wheel2: ix,
                                  wheel3: 0) else { return }
        event.post(tap: .cghidEventTap)
    }

    // MARK: Media keys

    /// Posts an `NX_KEYTYPE_*` aux-key event (volume, brightness, playback)
    /// via an `NSEvent` of type `.systemDefined`, subtype 8 — the same events
    /// the physical media keys on Apple keyboards produce.
    static func mediaKey(_ key: MediaKey, down: Bool) {
        let flagBits: Int = down ? 0x0A00 : 0x0B00
        let data1 = (key.rawValue << 16) | flagBits
        guard let nsEvent = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(flagBits)),
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        ), let cgEvent = nsEvent.cgEvent else { return }
        cgEvent.post(tap: .cghidEventTap)
    }

    // MARK: Helpers

    /// Translates the app's `KeyModifiers` option set to `CGEventFlags`.
    private static func cgFlags(for modifiers: KeyModifiers) -> CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        if modifiers.contains(.fn) { flags.insert(.maskSecondaryFn) }
        return flags
    }

    /// Current pointer position in CG global coordinates (top-left origin).
    private static func currentMouseLocation() -> CGPoint {
        if let location = CGEvent(source: nil)?.location {
            return location
        }
        // Fallback: convert AppKit's bottom-left-origin global position.
        let appKitLocation = NSEvent.mouseLocation
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: appKitLocation.x, y: primaryHeight - appKitLocation.y)
    }

    /// Union of all screens, converted from AppKit space (bottom-left origin,
    /// y up) to CG global space (top-left origin of the primary screen,
    /// y down). The primary screen is `NSScreen.screens.first` — its AppKit
    /// frame origin is (0, 0), so `cgY = primaryHeight - appKitMaxY`.
    private static func screensUnionCG() -> CGRect {
        let screens = NSScreen.screens
        guard let primary = screens.first else {
            return CGDisplayBounds(CGMainDisplayID())
        }
        let primaryHeight = primary.frame.height
        var union = CGRect.null
        for screen in screens {
            let frame = screen.frame
            let cgRect = CGRect(x: frame.origin.x,
                                y: primaryHeight - frame.maxY,
                                width: frame.width,
                                height: frame.height)
            union = union.union(cgRect)
        }
        return union.isNull ? CGDisplayBounds(CGMainDisplayID()) : union
    }

    /// Clamps a CG-space point inside the visible screen union (keeping the
    /// pointer one pixel inside the far edges so it stays on screen).
    private static func clampToScreens(_ point: CGPoint) -> CGPoint {
        let bounds = screensUnionCG()
        guard !bounds.isEmpty else { return point }
        let x = min(max(point.x, bounds.minX), bounds.maxX - 1)
        let y = min(max(point.y, bounds.minY), bounds.maxY - 1)
        return CGPoint(x: x, y: y)
    }
}
