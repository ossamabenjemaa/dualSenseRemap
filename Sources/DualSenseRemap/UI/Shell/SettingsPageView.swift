import SwiftUI
import AppKit
import Combine
import ServiceManagement

/// The "Réglages" page routed from the sidebar. Card-based single scroll:
/// general options (launch at login via SMAppService, menu bar icon,
/// per-app auto-switching), virtual keyboard tuning, live permission health,
/// Hammerspoon status and about. All settings bind to
/// `ProfileStore.shared.settings` (autosaved by the store).
public struct SettingsPageView: View {

    @ObservedObject private var profileStore = ProfileStore.shared
    @ObservedObject private var permissions = PermissionsManager.shared

    @State private var launchAtLoginError: String?
    @State private var showLaunchAtLoginAlert = false

    @State private var spoonSnippet: String?
    @State private var spoonError: String?

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.s5) {
                generalCard
                keyboardCard
                permissionsCard
                hammerspoonCard
                aboutCard
            }
            .padding(DS.s5)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(DS.canvasBackground)
        .onAppear {
            permissions.startPolling()
        }
        .onDisappear {
            permissions.stopPolling()
        }
        .alert("Ouverture à la connexion",
               isPresented: $showLaunchAtLoginAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(launchAtLoginError ?? "Une erreur inconnue est survenue.")
        }
    }

    // MARK: - Général

    private var generalCard: some View {
        VStack(alignment: .leading, spacing: DS.s4) {
            DSSectionHeader("Général")

            Toggle("Ouvrir DualSense Remap à la connexion", isOn: launchAtLoginBinding)
                .toggleStyle(.switch)
                .tint(DS.accent)

            Divider()

            Toggle("Afficher l'icône dans la barre des menus",
                   isOn: $profileStore.settings.showMenuBarIcon)
                .toggleStyle(.switch)
                .tint(DS.accent)

            Divider()

            VStack(alignment: .leading, spacing: DS.s1) {
                Toggle("Changer de profil automatiquement selon l'application",
                       isOn: $profileStore.settings.autoSwitchProfiles)
                    .toggleStyle(.switch)
                    .tint(DS.accent)
                Text("Le profil lié à l'application au premier plan est activé automatiquement.")
                    .font(DS.captionFont)
                    .foregroundColor(DS.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { profileStore.settings.launchAtLogin },
            set: { newValue in applyLaunchAtLogin(newValue) }
        )
    }

    /// Registers/unregisters the app as a login item; shows an alert and
    /// keeps the stored value unchanged when the system call fails.
    private func applyLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            profileStore.settings.launchAtLogin = enable
        } catch {
            launchAtLoginError = "macOS a refusé la modification : \(error.localizedDescription)"
            showLaunchAtLoginAlert = true
            // Force a UI refresh so the toggle snaps back to the stored value.
            profileStore.settings.launchAtLogin = profileStore.settings.launchAtLogin
        }
    }

    // MARK: - Clavier virtuel

    private var keyboardCard: some View {
        VStack(alignment: .leading, spacing: DS.s4) {
            DSSectionHeader("Clavier virtuel")

            HStack(spacing: DS.s3) {
                Text("Taille")
                    .font(DS.bodyFont)
                Slider(value: $profileStore.settings.virtualKeyboardScale, in: 0.7...1.4)
                Text("\(Int((profileStore.settings.virtualKeyboardScale * 100).rounded())) %")
                    .font(DS.labelFont)
                    .monospacedDigit()
                    .foregroundColor(DS.textSecondary)
                    .frame(width: 44, alignment: .trailing)
            }

            Divider()

            VStack(alignment: .leading, spacing: DS.s1) {
                Toggle("Retour haptique à la frappe",
                       isOn: $profileStore.settings.keyboardHapticFeedback)
                    .toggleStyle(.switch)
                    .tint(DS.accent)
                Text("Une légère vibration de la manette confirme chaque touche.")
                    .font(DS.captionFont)
                    .foregroundColor(DS.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
    }

    // MARK: - Autorisations

    private var permissionsCard: some View {
        VStack(alignment: .leading, spacing: DS.s4) {
            DSSectionHeader("Autorisations",
                            subtitle: "Statuts mis à jour en direct — aucun redémarrage nécessaire.")

            settingsPermissionRow(
                title: "Accessibilité",
                explanation: "Simulation du clavier, de la souris et du défilement.",
                granted: permissions.accessibilityGranted,
                missingLabel: "Requise",
                missingColor: DS.danger,
                promptAction: { permissions.promptAccessibility() },
                settingsAction: { permissions.openSystemSettings(pane: .accessibility) }
            )

            Divider()

            settingsPermissionRow(
                title: "Surveillance de l'entrée",
                explanation: "Optionnelle : uniquement pour le bouton micro (mute).",
                granted: permissions.inputMonitoringGranted,
                missingLabel: "Non accordée",
                missingColor: DS.warning,
                promptAction: { permissions.promptInputMonitoring() },
                settingsAction: { permissions.openSystemSettings(pane: .inputMonitoring) }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
    }

    private func settingsPermissionRow(
        title: String,
        explanation: String,
        granted: Bool,
        missingLabel: String,
        missingColor: Color,
        promptAction: @escaping () -> Void,
        settingsAction: @escaping () -> Void
    ) -> some View {
        HStack(spacing: DS.s3) {
            VStack(alignment: .leading, spacing: DS.s1) {
                Text(title)
                    .font(DS.bodyFont)
                Text(explanation)
                    .font(DS.captionFont)
                    .foregroundColor(DS.textSecondary)
            }
            Spacer(minLength: DS.s3)
            StatusPill(color: granted ? DS.success : missingColor,
                       label: granted ? "Accordée" : missingLabel)
            if !granted {
                Button("Autoriser…", action: promptAction)
                    .buttonStyle(SecondaryButtonStyle())
                Button("Réglages…", action: settingsAction)
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .animation(DS.quickAnimation, value: granted)
    }

    // MARK: - Hammerspoon

    private var hammerspoonCard: some View {
        VStack(alignment: .leading, spacing: DS.s4) {
            DSSectionHeader("Hammerspoon",
                            subtitle: "Automatisez macOS en Lua depuis la manette.")

            HStack(spacing: DS.s3) {
                if HammerspoonBridge.shared.isInstalled {
                    StatusPill(color: DS.success, label: "Installé")
                } else {
                    StatusPill(color: DS.warning, label: "Non détecté")
                    Link("hammerspoon.org",
                         destination: URL(string: "https://www.hammerspoon.org")!)
                        .font(DS.captionFont)
                }
                Spacer()
                Button("Installer le Spoon") {
                    installSpoon()
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            if let error = spoonError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(DS.captionFont)
                    .foregroundColor(DS.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let snippet = spoonSnippet {
                VStack(alignment: .leading, spacing: DS.s2) {
                    Text("Spoon installé dans ~/.hammerspoon/Spoons. Lignes à avoir dans init.lua :")
                        .font(DS.captionFont)
                        .foregroundColor(DS.textSecondary)
                    Text(snippet)
                        .font(DS.monoFont)
                        .textSelection(.enabled)
                        .padding(DS.s3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: DS.controlRadius, style: .continuous)
                                .fill(DS.insetBackground)
                        )
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
        .animation(DS.quickAnimation, value: spoonSnippet)
    }

    private func installSpoon() {
        do {
            spoonSnippet = try HammerspoonBridge.shared.installSpoon()
            spoonError = nil
        } catch {
            spoonError = error.localizedDescription
        }
    }

    // MARK: - À propos

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: DS.s3) {
            DSSectionHeader("À propos")

            HStack(spacing: DS.s3) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 26))
                    .foregroundColor(DS.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("DualSense Remap")
                        .font(DS.headingFont)
                    Text("Version \(DS.appVersion)")
                        .font(DS.captionFont)
                        .foregroundColor(DS.textSecondary)
                }
                Spacer()
                Link("Code source",
                     destination: URL(string: "https://github.com/ossamabenjemaa/dualSenseRemap")!)
                    .font(DS.labelFont)
            }

            Divider()

            Text("Inspiré par Logi Options+, ReControl et JoyMapper.")
                .font(DS.captionFont)
                .foregroundColor(DS.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
    }
}
