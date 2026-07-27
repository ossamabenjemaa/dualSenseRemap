import SwiftUI
import AppKit
import Combine

// MARK: - Sidebar sections

/// The five sidebar destinations of the main window.
enum ShellSection: String, CaseIterable, Identifiable, Hashable {
    case controller
    case profiles
    case virtualKeyboard
    case hammerspoon
    case settings

    var id: String { rawValue }

    /// French sidebar title.
    var title: String {
        switch self {
        case .controller: return "Manette"
        case .profiles: return "Profils"
        case .virtualKeyboard: return "Clavier virtuel"
        case .hammerspoon: return "Hammerspoon"
        case .settings: return "Réglages"
        }
    }

    var symbol: String {
        switch self {
        case .controller: return "gamecontroller"
        case .profiles: return "square.grid.2x2"
        case .virtualKeyboard: return "keyboard"
        case .hammerspoon: return "hammer"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - Shell model

/// Shell-level UI state: the selected sidebar section.
final class ShellModel: ObservableObject {
    @Published var selection: ShellSection? = .controller
}

// MARK: - Shell view

/// The main window content: NavigationSplitView with the five-section
/// sidebar, a persistent header bar (connection, battery, mapping switch,
/// profile picker) and the routed page views. Also captures the NSWindow for
/// `AppCoordinator` and presents the first-launch onboarding sheet.
struct ShellView: View {

    @StateObject private var model = ShellModel()
    @ObservedObject private var dualSense = DualSenseManager.shared
    @ObservedObject private var profileStore = ProfileStore.shared

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .frame(minWidth: 1000, minHeight: 660)
        .background(
            ShellWindowAccessor { window in
                if let window = window {
                    AppCoordinator.shared.mainWindow = window
                }
            }
        )
        .onAppear {
            // Store the environment action so non-UI code (menu bar, URL
            // scheme, Hammerspoon) can reopen the window after it is closed.
            AppCoordinator.shared.openWindowAction = openWindow
            if !hasCompletedOnboarding {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
        }
        // "Requires Hammerspoon" notice: route to the Hammerspoon page
        // (install status + guidance) when a mapped Hammerspoon-only event
        // fired without Hammerspoon (AppDelegate brings the window up).
        .onReceive(NotificationCenter.default.publisher(
            for: ActionExecutor.hammerspoonRequiredNotification
        )) { _ in
            model.selection = .hammerspoon
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List(selection: $model.selection) {
            ForEach(ShellSection.allCases) { section in
                Label(section.title, systemImage: section.symbol)
                    .font(DS.bodyFont)
                    .tag(section)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        .tint(DS.accent)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            sidebarFooter
        }
    }

    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            Divider()
            Text("DualSense Remap \(DS.appVersion)")
                .font(DS.captionFont)
                .foregroundColor(DS.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.s2)
        }
    }

    // MARK: Detail

    private var detail: some View {
        VStack(spacing: 0) {
            ShellHeaderBar()
            Divider()
            pageContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(DS.quickAnimation, value: model.selection)
        }
        .background(DS.canvasBackground)
    }

    @ViewBuilder
    private var pageContent: some View {
        switch model.selection ?? .controller {
        case .controller:
            ControllerPageView()
        case .profiles:
            ProfilesPageView()
        case .virtualKeyboard:
            VirtualKeyboardPageView()
        case .hammerspoon:
            HammerspoonPageView()
        case .settings:
            SettingsPageView()
        }
    }
}

// MARK: - Header bar

/// Persistent header above every page: app title, connection status pill
/// (with a pairing-hint popover when disconnected), battery gauge, active
/// profile picker and the global mapping kill-switch.
struct ShellHeaderBar: View {

    @ObservedObject private var dualSense = DualSenseManager.shared
    @ObservedObject private var profileStore = ProfileStore.shared
    @ObservedObject private var mappingModel = MappingEngineToggleModel.shared

    @State private var showPairingHint = false

    var body: some View {
        HStack(spacing: DS.s4) {
            Text("DualSense Remap")
                .font(DS.titleFont)
                .foregroundColor(DS.textPrimary)

            connectionPill

            if dualSense.snapshot.isConnected {
                ShellBatteryGauge(battery: dualSense.snapshot.battery)
                    .transition(.opacity)
            }

            Spacer(minLength: DS.s4)

            profileMenu

            Toggle("Mappage", isOn: $mappingModel.isEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(DS.accent)
                .help("Active ou suspend toutes les correspondances de la manette")
        }
        .padding(.horizontal, DS.s5)
        .padding(.vertical, DS.s3)
        .animation(DS.quickAnimation, value: dualSense.snapshot.isConnected)
    }

    // MARK: Connection pill

    private var connectionPill: some View {
        Button {
            if !dualSense.snapshot.isConnected {
                showPairingHint.toggle()
            }
        } label: {
            StatusPill(
                color: dualSense.snapshot.isConnected ? DS.success : DS.warning,
                label: connectionLabel
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPairingHint, arrowEdge: .bottom) {
            pairingHintContent
        }
    }

    private var connectionLabel: String {
        guard dualSense.snapshot.isConnected else { return "Non connectée" }
        let name = dualSense.snapshot.controllerName
        return name.isEmpty ? "Connectée" : "Connectée · \(name)"
    }

    private var pairingHintContent: some View {
        VStack(alignment: .leading, spacing: DS.s3) {
            Label("Associer votre manette", systemImage: "gamecontroller")
                .font(DS.headingFont)
            Text("""
            1. Maintenez les boutons PS et Create enfoncés jusqu'à ce que \
            la barre lumineuse clignote.
            2. Ouvrez les Réglages Bluetooth de macOS et sélectionnez \
            « DualSense Wireless Controller ».

            Vous pouvez aussi simplement brancher la manette en USB-C.
            """)
                .font(DS.bodyFont)
                .foregroundColor(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Ouvrir les Réglages Bluetooth") {
                shellOpenBluetoothSettings()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(DS.s5)
        .frame(width: 320)
    }

    // MARK: Profile menu

    private var profileMenu: some View {
        Menu {
            ForEach(profileStore.profiles) { profile in
                Button {
                    profileStore.activateProfile(id: profile.id)
                } label: {
                    if profile.id == profileStore.activeProfile.id {
                        Label(profile.name, systemImage: "checkmark")
                    } else {
                        Text(profile.name)
                    }
                }
            }
        } label: {
            Label(profileStore.activeProfile.name,
                  systemImage: profileStore.activeProfile.icon)
                .font(DS.labelFont)
        }
        .fixedSize()
        .help("Profil actif")
    }
}

// MARK: - Battery gauge

/// Battery SF-symbol variant by level + tabular percent, bolt when charging.
struct ShellBatteryGauge: View {
    let battery: BatteryStatus

    var body: some View {
        HStack(spacing: DS.s1) {
            Image(systemName: symbolName)
                .foregroundColor(color)
            Text("\(percent) %")
                .font(DS.labelFont)
                .monospacedDigit()
                .foregroundColor(DS.textSecondary)
        }
        .help(helpText)
        .animation(DS.quickAnimation, value: percent)
    }

    private var percent: Int {
        Int((battery.level * 100).rounded())
    }

    private var symbolName: String {
        if battery.state == .charging || battery.state == .full {
            return "battery.100.bolt"
        }
        switch battery.level {
        case ..<0.125: return "battery.0"
        case ..<0.375: return "battery.25"
        case ..<0.625: return "battery.50"
        case ..<0.875: return "battery.75"
        default: return "battery.100"
        }
    }

    private var color: Color {
        if battery.state == .charging || battery.state == .full { return DS.success }
        if battery.level <= 0.10 { return DS.danger }
        if battery.level <= 0.20 { return DS.warning }
        return DS.textSecondary
    }

    private var helpText: String {
        switch battery.state {
        case .charging: return "Batterie : \(percent) % — en charge"
        case .full: return "Batterie chargée"
        case .discharging, .unknown: return "Batterie : \(percent) %"
        }
    }
}

// MARK: - Window accessor

/// Invisible NSView that reports the hosting NSWindow to `AppCoordinator`,
/// so the app can bring the main window back to front from non-UI code.
struct ShellWindowAccessor: NSViewRepresentable {
    var onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            onResolve(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onResolve(nsView.window)
        }
    }
}

// MARK: - Helpers

/// Opens the macOS Bluetooth settings pane (best-effort across versions).
func shellOpenBluetoothSettings() {
    let candidates = [
        "x-apple.systempreferences:com.apple.BluetoothSettings",
        "x-apple.systempreferences:com.apple.preferences.Bluetooth",
    ]
    for candidate in candidates {
        if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
            return
        }
    }
}
