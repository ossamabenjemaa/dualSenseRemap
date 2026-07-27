import Foundation
import SwiftUI
import AppKit
import Combine

// MARK: - Shared slider row

struct PagesSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var format: (Double) -> String = { String(format: "%.2f", $0) }

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(VKPagesPalette.textSecondary)
                Spacer()
                Text(format(value))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(VKPagesPalette.textTertiary)
            }
            Slider(value: $value, in: range)
        }
    }
}

// MARK: - Stick mode choice

fileprivate enum PagesStickChoice: String, CaseIterable, Identifiable {
    case pointer
    case scroll
    case arrows
    case wasd
    case volume
    case disabled

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pointer: return "Pointeur"
        case .scroll: return "Défilement"
        case .arrows: return "Flèches"
        case .wasd: return "ZQSD"
        case .volume: return "Volume / Luminosité"
        case .disabled: return "Désactivé"
        }
    }

    static func from(_ mode: StickMode) -> PagesStickChoice {
        switch mode {
        case .mousePointer: return .pointer
        case .scroll: return .scroll
        case .arrowKeys: return .arrows
        case .wasd: return .wasd
        case .volumeAndBrightness: return .volume
        case .disabled, .keyboardFocus: return .disabled
        }
    }
}

// MARK: - Sticks card

struct PagesSticksCard: View {
    @ObservedObject private var store = ProfileStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PagesSectionHeader("Sticks",
                               subtitle: "Pointeur, défilement ou touches — réglable par stick")
            stickSection(title: "Stick gauche", isLeft: true)
            Divider()
            stickSection(title: "Stick droit", isLeft: false)
        }
        .pagesCard()
    }

    @ViewBuilder
    private func stickSection(title: String, isLeft: Bool) -> some View {
        let choice = PagesStickChoice.from(mode(isLeft))
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(VKPagesPalette.textPrimary)
                Spacer()
                Picker("", selection: choiceBinding(isLeft)) {
                    ForEach(PagesStickChoice.allCases) { entry in
                        Text(entry.label).tag(entry)
                    }
                }
                .labelsHidden()
                .frame(width: 190)
            }
            if choice == .pointer || choice == .scroll {
                PagesSliderRow(title: "Sensibilité",
                               value: sensitivityBinding(isLeft),
                               range: choice == .pointer ? 100...2400 : 2...40,
                               format: { String(format: "%.0f", $0) })
                PagesSliderRow(title: "Zone morte",
                               value: deadzoneBinding(isLeft),
                               range: 0...0.4)
                HStack {
                    Text("Courbe de réponse")
                        .font(.system(size: 11))
                        .foregroundColor(VKPagesPalette.textSecondary)
                    Spacer()
                    Picker("", selection: curveBinding(isLeft)) {
                        ForEach(ResponseCurve.allCases, id: \.self) { curve in
                            Text(curve.displayName).tag(curve)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
            } else if choice == .arrows {
                PagesSliderRow(title: "Intervalle de répétition (ms)",
                               value: repeatIntervalBinding(isLeft),
                               range: 60...400,
                               format: { String(format: "%.0f", $0) })
            }
        }
        .animation(VKPagesPalette.quick, value: choice)
    }

    // MARK: Mode plumbing

    private func mode(_ isLeft: Bool) -> StickMode {
        isLeft ? store.activeProfile.leftStickMode : store.activeProfile.rightStickMode
    }

    private func setMode(_ newMode: StickMode, isLeft: Bool) {
        var profile = store.activeProfile
        if isLeft {
            profile.leftStickMode = newMode
        } else {
            profile.rightStickMode = newMode
        }
        store.updateProfile(profile)
    }

    private func tuning(_ isLeft: Bool) -> StickTuning {
        switch mode(isLeft) {
        case .mousePointer(let tuning): return tuning
        case .scroll(let tuning): return tuning
        default: return StickTuning()
        }
    }

    private func setTuning(_ newTuning: StickTuning, isLeft: Bool) {
        switch mode(isLeft) {
        case .mousePointer:
            setMode(.mousePointer(newTuning), isLeft: isLeft)
        case .scroll:
            setMode(.scroll(newTuning), isLeft: isLeft)
        default:
            break
        }
    }

    private func choiceBinding(_ isLeft: Bool) -> Binding<PagesStickChoice> {
        Binding(
            get: { PagesStickChoice.from(mode(isLeft)) },
            set: { newChoice in
                guard newChoice != PagesStickChoice.from(mode(isLeft)) else { return }
                let newMode: StickMode
                switch newChoice {
                case .pointer: newMode = .mousePointer(StickTuning())
                case .scroll: newMode = .scroll(StickTuning(sensitivity: 14))
                case .arrows: newMode = .arrowKeys(repeatIntervalMs: 160)
                case .wasd: newMode = .wasd
                case .volume: newMode = .volumeAndBrightness
                case .disabled: newMode = .disabled
                }
                setMode(newMode, isLeft: isLeft)
            }
        )
    }

    private func sensitivityBinding(_ isLeft: Bool) -> Binding<Double> {
        Binding(
            get: { tuning(isLeft).sensitivity },
            set: { newValue in
                var t = tuning(isLeft)
                t.sensitivity = newValue
                setTuning(t, isLeft: isLeft)
            }
        )
    }

    private func deadzoneBinding(_ isLeft: Bool) -> Binding<Double> {
        Binding(
            get: { tuning(isLeft).deadzone },
            set: { newValue in
                var t = tuning(isLeft)
                t.deadzone = newValue
                setTuning(t, isLeft: isLeft)
            }
        )
    }

    private func curveBinding(_ isLeft: Bool) -> Binding<ResponseCurve> {
        Binding(
            get: { tuning(isLeft).curve },
            set: { newValue in
                var t = tuning(isLeft)
                t.curve = newValue
                setTuning(t, isLeft: isLeft)
            }
        )
    }

    private func repeatIntervalBinding(_ isLeft: Bool) -> Binding<Double> {
        Binding(
            get: {
                if case .arrowKeys(let interval) = mode(isLeft) {
                    return Double(interval)
                }
                return 160
            },
            set: { newValue in
                setMode(.arrowKeys(repeatIntervalMs: Int(newValue)), isLeft: isLeft)
            }
        )
    }
}

// MARK: - Triggers card

struct PagesTriggersCard: View {
    @ObservedObject private var store = ProfileStore.shared
    @ObservedObject private var manager = DualSenseManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PagesSectionHeader("Gâchettes",
                               subtitle: "Seuil de déclenchement et effet adaptatif — appliqués immédiatement")
            HStack(alignment: .top, spacing: 16) {
                triggerColumn(isLeft: true)
                Divider()
                triggerColumn(isLeft: false)
            }
        }
        .pagesCard()
    }

    private func triggerColumn(isLeft: Bool) -> some View {
        let liveValue = isLeft ? manager.snapshot.leftTrigger : manager.snapshot.rightTrigger
        let settings = isLeft ? store.activeProfile.leftTrigger : store.activeProfile.rightTrigger
        return VStack(alignment: .leading, spacing: 8) {
            Text(isLeft ? "L2" : "R2")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(VKPagesPalette.textPrimary)
            liveBar(value: liveValue, threshold: settings.activationThreshold)
            PagesSliderRow(title: "Seuil d'activation",
                           value: thresholdBinding(isLeft),
                           range: 0.05...0.95)
            HStack {
                Text("Effet adaptatif")
                    .font(.system(size: 11))
                    .foregroundColor(VKPagesPalette.textSecondary)
                Spacer()
            }
            Picker("", selection: effectBinding(isLeft)) {
                ForEach(AdaptiveTriggerEffect.allCases, id: \.self) { effect in
                    Text(effect.displayName).tag(effect)
                }
            }
            .labelsHidden()
        }
        .frame(maxWidth: .infinity)
    }

    private func liveBar(value: Double, threshold: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(VKPagesPalette.insetBackground)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(VKPagesPalette.accent.opacity(0.85))
                    .frame(width: max(0, geo.size.width * CGFloat(min(1, max(0, value)))))
                Rectangle()
                    .fill(VKPagesPalette.warning)
                    .frame(width: 2)
                    .offset(x: geo.size.width * CGFloat(threshold) - 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .frame(height: 10)
    }

    private func thresholdBinding(_ isLeft: Bool) -> Binding<Double> {
        Binding(
            get: {
                isLeft ? store.activeProfile.leftTrigger.activationThreshold
                       : store.activeProfile.rightTrigger.activationThreshold
            },
            set: { newValue in
                var profile = store.activeProfile
                if isLeft {
                    profile.leftTrigger.activationThreshold = newValue
                } else {
                    profile.rightTrigger.activationThreshold = newValue
                }
                store.updateProfile(profile)
            }
        )
    }

    private func effectBinding(_ isLeft: Bool) -> Binding<AdaptiveTriggerEffect> {
        Binding(
            get: {
                isLeft ? store.activeProfile.leftTrigger.adaptiveEffect
                       : store.activeProfile.rightTrigger.adaptiveEffect
            },
            set: { newValue in
                var profile = store.activeProfile
                if isLeft {
                    profile.leftTrigger.adaptiveEffect = newValue
                } else {
                    profile.rightTrigger.adaptiveEffect = newValue
                }
                store.updateProfile(profile)
                // Instant feel on the physical trigger.
                DualSenseManager.shared.setAdaptiveTrigger(isLeft ? .left : .right, effect: newValue)
            }
        )
    }
}

// MARK: - Touchpad card

fileprivate enum PagesTouchpadChoice: String, CaseIterable, Identifiable {
    case trackpad
    case absolute
    case gestures
    case disabled

    var id: String { rawValue }

    var label: String {
        switch self {
        case .trackpad: return "Trackpad"
        case .absolute: return "Pointeur absolu"
        case .gestures: return "Gestes (Spaces)"
        case .disabled: return "Désactivé"
        }
    }

    static func from(_ mode: TouchpadMode) -> PagesTouchpadChoice {
        switch mode {
        case .trackpad: return .trackpad
        case .absolutePointer: return .absolute
        case .gestures: return .gestures
        case .disabled: return .disabled
        }
    }
}

struct PagesTouchpadCard: View {
    @ObservedObject private var store = ProfileStore.shared
    @ObservedObject private var manager = DualSenseManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PagesSectionHeader("Pavé tactile",
                               subtitle: "Deux doigts visualisés en direct sur la miniature")
            HStack {
                Text("Mode")
                    .font(.system(size: 11))
                    .foregroundColor(VKPagesPalette.textSecondary)
                Spacer()
                Picker("", selection: choiceBinding) {
                    ForEach(PagesTouchpadChoice.allCases) { entry in
                        Text(entry.label).tag(entry)
                    }
                }
                .labelsHidden()
                .frame(width: 190)
            }
            if let values = trackpadValues {
                PagesSliderRow(title: "Sensibilité",
                               value: trackpadSensitivityBinding,
                               range: 0.5...6,
                               format: { String(format: "%.1f", $0) })
                Toggle("Toucher pour cliquer", isOn: trackpadToggleBinding(\.tapToClick))
                    .font(.system(size: 11))
                Toggle("Défilement à deux doigts", isOn: trackpadToggleBinding(\.twoFingerScroll))
                    .font(.system(size: 11))
                Toggle("Défilement naturel", isOn: trackpadToggleBinding(\.naturalScroll))
                    .font(.system(size: 11))
                    .disabled(!values.twoFingerScroll)
            }
            padPreview
        }
        .pagesCard()
        .animation(VKPagesPalette.quick, value: PagesTouchpadChoice.from(store.activeProfile.touchpadMode))
    }

    // MARK: Live preview

    private var padPreview: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                touchDot(manager.snapshot.primaryTouch, size: geo.size, primary: true)
                touchDot(manager.snapshot.secondaryTouch, size: geo.size, primary: false)
            }
        }
        .frame(height: 88)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(VKPagesPalette.insetBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(VKPagesPalette.separator.opacity(0.6), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func touchDot(_ touch: TouchpadTouch, size: CGSize, primary: Bool) -> some View {
        if touch.isTouching {
            // Normalized [-1, 1] with +y toward the top edge of the pad.
            let x = (CGFloat(touch.x) + 1) / 2 * size.width
            let y = (1 - (CGFloat(touch.y) + 1) / 2) * size.height
            Circle()
                .fill(VKPagesPalette.accent.opacity(primary ? 0.9 : 0.55))
                .frame(width: 12, height: 12)
                .position(x: min(max(x, 6), size.width - 6),
                          y: min(max(y, 6), size.height - 6))
        }
    }

    // MARK: Bindings

    private struct TrackpadValues {
        var sensitivity: Double
        var tapToClick: Bool
        var twoFingerScroll: Bool
        var naturalScroll: Bool
    }

    private var trackpadValues: TrackpadValues? {
        if case .trackpad(let sensitivity, let tap, let scroll, let natural) = store.activeProfile.touchpadMode {
            return TrackpadValues(sensitivity: sensitivity,
                                  tapToClick: tap,
                                  twoFingerScroll: scroll,
                                  naturalScroll: natural)
        }
        return nil
    }

    private func setTouchpadMode(_ newMode: TouchpadMode) {
        var profile = store.activeProfile
        profile.touchpadMode = newMode
        store.updateProfile(profile)
    }

    private var choiceBinding: Binding<PagesTouchpadChoice> {
        Binding(
            get: { PagesTouchpadChoice.from(store.activeProfile.touchpadMode) },
            set: { newChoice in
                guard newChoice != PagesTouchpadChoice.from(store.activeProfile.touchpadMode) else { return }
                switch newChoice {
                case .trackpad: setTouchpadMode(.defaultTrackpad)
                case .absolute: setTouchpadMode(.absolutePointer)
                case .gestures: setTouchpadMode(.gestures)
                case .disabled: setTouchpadMode(.disabled)
                }
            }
        )
    }

    private var trackpadSensitivityBinding: Binding<Double> {
        Binding(
            get: { trackpadValues?.sensitivity ?? 2.4 },
            set: { newValue in
                guard var values = trackpadValues else { return }
                values.sensitivity = newValue
                setTouchpadMode(.trackpad(sensitivity: values.sensitivity,
                                          tapToClick: values.tapToClick,
                                          twoFingerScroll: values.twoFingerScroll,
                                          naturalScroll: values.naturalScroll))
            }
        )
    }

    private func trackpadToggleBinding(_ keyPath: WritableKeyPath<TrackpadValues, Bool>) -> Binding<Bool> {
        Binding(
            get: { trackpadValues?[keyPath: keyPath] ?? false },
            set: { newValue in
                guard var values = trackpadValues else { return }
                values[keyPath: keyPath] = newValue
                setTouchpadMode(.trackpad(sensitivity: values.sensitivity,
                                          tapToClick: values.tapToClick,
                                          twoFingerScroll: values.twoFingerScroll,
                                          naturalScroll: values.naturalScroll))
            }
        )
    }
}

// MARK: - Gyroscope card

fileprivate enum PagesGyroChoice: String, CaseIterable, Identifiable {
    case disabled
    case pointer
    case scroll

    var id: String { rawValue }

    var label: String {
        switch self {
        case .disabled: return "Désactivé"
        case .pointer: return "Pointeur (gyro aiming)"
        case .scroll: return "Défilement"
        }
    }

    static func from(_ mode: GyroMode) -> PagesGyroChoice {
        switch mode {
        case .disabled: return .disabled
        case .mousePointer: return .pointer
        case .scroll: return .scroll
        }
    }
}

struct PagesGyroCard: View {
    @ObservedObject private var store = ProfileStore.shared

    private var digitalElements: [ControllerElement] {
        ControllerElement.allCases.filter { $0.isDigital }
    }

    var body: some View {
        let choice = PagesGyroChoice.from(store.activeProfile.gyroMode)
        return VStack(alignment: .leading, spacing: 14) {
            PagesSectionHeader("Gyroscope",
                               subtitle: "Pilotez le pointeur ou le défilement en inclinant la manette")
            HStack {
                Text("Mode")
                    .font(.system(size: 11))
                    .foregroundColor(VKPagesPalette.textSecondary)
                Spacer()
                Picker("", selection: choiceBinding) {
                    ForEach(PagesGyroChoice.allCases) { entry in
                        Text(entry.label).tag(entry)
                    }
                }
                .labelsHidden()
                .frame(width: 190)
            }
            if choice != .disabled {
                PagesSliderRow(title: "Sensibilité",
                               value: sensitivityBinding,
                               range: 0.1...4,
                               format: { String(format: "%.1f", $0) })
            }
            if choice == .pointer {
                HStack {
                    Text("Actif en maintenant")
                        .font(.system(size: 11))
                        .foregroundColor(VKPagesPalette.textSecondary)
                    Spacer()
                    Picker("", selection: activationBinding) {
                        Text("Toujours actif").tag(ControllerElement?.none)
                        ForEach(digitalElements) { element in
                            Text(element.displayName).tag(ControllerElement?.some(element))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 190)
                }
            }
        }
        .pagesCard()
        .animation(VKPagesPalette.quick, value: choice)
    }

    // MARK: Bindings

    private func setGyroMode(_ newMode: GyroMode) {
        var profile = store.activeProfile
        profile.gyroMode = newMode
        store.updateProfile(profile)
        switch newMode {
        case .disabled:
            DualSenseManager.shared.setGyroActive(false)
        default:
            DualSenseManager.shared.setGyroActive(true)
        }
    }

    private var currentSensitivity: Double {
        switch store.activeProfile.gyroMode {
        case .mousePointer(let sensitivity, _): return sensitivity
        case .scroll(let sensitivity): return sensitivity
        case .disabled: return 1.0
        }
    }

    private var currentActivation: ControllerElement? {
        if case .mousePointer(_, let hold) = store.activeProfile.gyroMode {
            return hold
        }
        return nil
    }

    private var choiceBinding: Binding<PagesGyroChoice> {
        Binding(
            get: { PagesGyroChoice.from(store.activeProfile.gyroMode) },
            set: { newChoice in
                guard newChoice != PagesGyroChoice.from(store.activeProfile.gyroMode) else { return }
                switch newChoice {
                case .disabled:
                    setGyroMode(.disabled)
                case .pointer:
                    setGyroMode(.mousePointer(sensitivity: currentSensitivity,
                                              activationHold: currentActivation))
                case .scroll:
                    setGyroMode(.scroll(sensitivity: currentSensitivity))
                }
            }
        )
    }

    private var sensitivityBinding: Binding<Double> {
        Binding(
            get: { currentSensitivity },
            set: { newValue in
                switch store.activeProfile.gyroMode {
                case .mousePointer(_, let hold):
                    setGyroMode(.mousePointer(sensitivity: newValue, activationHold: hold))
                case .scroll:
                    setGyroMode(.scroll(sensitivity: newValue))
                case .disabled:
                    break
                }
            }
        )
    }

    private var activationBinding: Binding<ControllerElement?> {
        Binding(
            get: { currentActivation },
            set: { newValue in
                if case .mousePointer(let sensitivity, _) = store.activeProfile.gyroMode {
                    setGyroMode(.mousePointer(sensitivity: sensitivity, activationHold: newValue))
                }
            }
        )
    }
}
