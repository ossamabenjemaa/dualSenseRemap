import Foundation
import IOKit
import IOKit.hid
import os

/// Raw-HID listener for the DualSense mute button, which GameController does
/// not expose. Matches Sony (0x054C) DualSense (0x0CE6) and DualSense Edge
/// (0x0DF2), parses the mute bit from input reports and forwards debounced
/// edges through `onMuteChanged`. Also drives the microphone LED through the
/// documented output report.
///
/// The monitor only ever starts when Input Monitoring is ALREADY granted
/// (`IOHIDCheckAccess`); it never triggers the TCC prompt — onboarding owns
/// that. All IOHID callbacks are scheduled on the main run loop, so state
/// mutations and `onMuteChanged` happen on the main thread.
final class HIDMuteMonitor {

    /// Microphone LED modes documented in the DualSense output report
    /// (`ucMicLightMode`: 0 off, 1 solid, 2 pulse).
    enum MuteLEDMode: UInt8 {
        case off = 0
        case solid = 1
        case pulse = 2
    }

    /// Debounced mute-button edges (true = pressed). Called on the main thread.
    var onMuteChanged: ((Bool) -> Void)?

    // MARK: - Private state

    private let logger = os.Logger(subsystem: "com.dualsenseremap.app", category: "Input")
    private var manager: IOHIDManager?
    private var isRunning = false

    /// Per-device report buffer + transport info, keyed by device identity.
    private final class MonitoredDeviceContext {
        let device: IOHIDDevice
        let bufferSize = 128
        let buffer: UnsafeMutablePointer<UInt8>
        let isBluetooth: Bool

        init(device: IOHIDDevice, isBluetooth: Bool) {
            self.device = device
            self.isBluetooth = isBluetooth
            self.buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            self.buffer.initialize(repeating: 0, count: bufferSize)
        }

        deinit {
            buffer.deallocate()
        }
    }

    private var contexts: [ObjectIdentifier: MonitoredDeviceContext] = [:]

    // Mute edge detection + debounce.
    private var mutePressed = false
    private var lastEdgeTime: CFAbsoluteTime = 0
    private static let debounceInterval: CFAbsoluteTime = 0.03

    /// Sequence counter for Bluetooth output reports (upper nibble of byte 1).
    private var outputSequence: UInt8 = 0

    // MARK: - Lifecycle

    /// Starts the IOHID listener if (and only if) Input Monitoring is already
    /// granted. Never prompts. Safe to call repeatedly — it retries silently
    /// until permission appears.
    func startIfPermitted() {
        guard !isRunning else { return }
        guard IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted else { return }

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [[String: Any]] = [
            [kIOHIDVendorIDKey: 0x054C, kIOHIDProductIDKey: 0x0CE6], // DualSense
            [kIOHIDVendorIDKey: 0x054C, kIOHIDProductIDKey: 0x0DF2], // DualSense Edge
        ]
        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, HIDMuteMonitor.deviceMatchedCallback, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, HIDMuteMonitor.deviceRemovedCallback, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            logger.warning("IOHIDManagerOpen failed (\(result)) — mute button unavailable")
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            return
        }
        self.manager = manager
        isRunning = true
        logger.info("HID mute monitor started")
    }

    func stop() {
        guard isRunning, let manager = manager else { return }
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        contexts.removeAll()
        self.manager = nil
        isRunning = false
        if mutePressed {
            mutePressed = false
            onMuteChanged?(false)
        }
        logger.info("HID mute monitor stopped")
    }

    // MARK: - Mute LED (output reports)

    /// Sets the microphone LED on every attached DualSense.
    /// Payload layout per the raw-HID research: effects byte 1 bit 0 enables
    /// mic-light control, byte 8 carries the mode.
    func setMuteLED(_ mode: MuteLEDMode) {
        guard isRunning else { return }
        for context in contexts.values {
            sendMuteLED(mode, to: context)
        }
    }

    private func sendMuteLED(_ mode: MuteLEDMode, to context: MonitoredDeviceContext) {
        // 47-byte common effects payload, all other enable flags left at zero
        // so rumble/lightbar/trigger state is untouched.
        var effects = [UInt8](repeating: 0, count: 47)
        effects[1] = 0x01 // ucEnableBits2 bit 0 → mic light enable
        effects[8] = mode.rawValue // ucMicLightMode

        let result: IOReturn
        if context.isBluetooth {
            // BT output report 0x31: [seq<<4][0x10 tag][47-byte effects][pad][CRC32].
            // CRC32 runs over 0xA2, the report ID and every byte before the CRC.
            var body = [UInt8](repeating: 0, count: 77)
            body[0] = outputSequence << 4
            outputSequence = (outputSequence + 1) & 0x0F
            body[1] = 0x10
            for i in 0..<effects.count {
                body[2 + i] = effects[i]
            }
            var crcInput: [UInt8] = [0xA2, 0x31]
            crcInput.append(contentsOf: body[0..<73])
            let crc = HIDMuteMonitor.crc32(crcInput)
            body[73] = UInt8(truncatingIfNeeded: crc)
            body[74] = UInt8(truncatingIfNeeded: crc >> 8)
            body[75] = UInt8(truncatingIfNeeded: crc >> 16)
            body[76] = UInt8(truncatingIfNeeded: crc >> 24)
            result = body.withUnsafeBufferPointer { pointer in
                IOHIDDeviceSetReport(context.device, kIOHIDReportTypeOutput, 0x31, pointer.baseAddress!, pointer.count)
            }
        } else {
            // USB output report 0x02 carries the effects payload directly.
            result = effects.withUnsafeBufferPointer { pointer in
                IOHIDDeviceSetReport(context.device, kIOHIDReportTypeOutput, 0x02, pointer.baseAddress!, pointer.count)
            }
        }
        if result != kIOReturnSuccess {
            logger.warning("Mute LED output report failed (\(result))")
        }
    }

    // MARK: - C callbacks (no captures — context carries `self`)

    private static let deviceMatchedCallback: IOHIDDeviceCallback = { context, result, _, device in
        guard result == kIOReturnSuccess, let context = context else { return }
        let monitor = Unmanaged<HIDMuteMonitor>.fromOpaque(context).takeUnretainedValue()
        monitor.deviceMatched(device)
    }

    private static let deviceRemovedCallback: IOHIDDeviceCallback = { context, _, _, device in
        guard let context = context else { return }
        let monitor = Unmanaged<HIDMuteMonitor>.fromOpaque(context).takeUnretainedValue()
        monitor.deviceRemoved(device)
    }

    private static let inputReportCallback: IOHIDReportCallback = { context, result, _, _, reportID, report, reportLength in
        guard result == kIOReturnSuccess, let context = context else { return }
        let monitor = Unmanaged<HIDMuteMonitor>.fromOpaque(context).takeUnretainedValue()
        monitor.handleInputReport(reportID: reportID, report: report, length: Int(reportLength))
    }

    // MARK: - Device handling (main run loop)

    private func deviceMatched(_ device: IOHIDDevice) {
        let key = ObjectIdentifier(device)
        guard contexts[key] == nil else { return }

        let transport = (IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String) ?? ""
        let isBluetooth = transport.lowercased().contains("bluetooth")
        let deviceContext = MonitoredDeviceContext(device: device, isBluetooth: isBluetooth)
        contexts[key] = deviceContext

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(
            device,
            deviceContext.buffer,
            CFIndex(deviceContext.bufferSize),
            HIDMuteMonitor.inputReportCallback,
            context
        )

        if isBluetooth {
            requestEnhancedReporting(device)
        }
        logger.info("DualSense HID attached (transport: \(transport, privacy: .public))")
    }

    private func deviceRemoved(_ device: IOHIDDevice) {
        contexts.removeValue(forKey: ObjectIdentifier(device))
        if contexts.isEmpty && mutePressed {
            mutePressed = false
            onMuteChanged?(false)
        }
        logger.info("DualSense HID detached")
    }

    /// Over Bluetooth the DualSense boots in a 10-byte DS4-style "simple"
    /// report that carries no mute bit. Reading the calibration feature report
    /// (0x05) switches the controller to the full 0x31 input report.
    private func requestEnhancedReporting(_ device: IOHIDDevice) {
        var buffer = [UInt8](repeating: 0, count: 64)
        var length = CFIndex(buffer.count)
        let result = buffer.withUnsafeMutableBufferPointer { pointer in
            IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 0x05, pointer.baseAddress!, &length)
        }
        if result != kIOReturnSuccess {
            logger.warning("Enhanced-report handshake failed (\(result)) — BT mute may be unavailable")
        }
    }

    // MARK: - Report parsing

    private func handleInputReport(reportID: UInt32, report: UnsafeMutablePointer<UInt8>, length: Int) {
        var pressed: Bool?
        switch reportID {
        case 0x01 where length >= 32:
            // USB full report. The IOKit callback buffer is
            // [reportID][payload…] — macOS does NOT strip the report ID for
            // multi-report devices — so buttons[2] (payload byte 9) is at
            // absolute offset 10; mute is bit 2.
            pressed = (report[10] & 0x04) != 0
        case 0x01:
            // Bluetooth "simple" DS4-style report — no mute bit. The
            // enhanced-report handshake issued at attach time upgrades the
            // stream to 0x31; nothing to parse here.
            break
        case 0x31 where length >= 12:
            // Bluetooth full report: [0x31 ID][sequence byte][state payload…],
            // so buttons[2] (state byte 9) lands at absolute offset 11.
            pressed = (report[11] & 0x04) != 0
        default:
            break
        }
        guard let pressed = pressed else { return }
        updateMuteState(pressed)
    }

    /// Edge detection + debounce. The mute bit is present in every input
    /// report, so an edge swallowed by the debounce window is re-delivered by
    /// the next report and the state self-corrects.
    private func updateMuteState(_ pressed: Bool) {
        guard pressed != mutePressed else { return }
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastEdgeTime >= Self.debounceInterval else { return }
        lastEdgeTime = now
        mutePressed = pressed
        onMuteChanged?(pressed)
    }

    // MARK: - CRC32 (zlib polynomial, required by Bluetooth output reports)

    private static func crc32(_ bytes: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in bytes {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
            }
        }
        return crc ^ 0xFFFF_FFFF
    }
}
