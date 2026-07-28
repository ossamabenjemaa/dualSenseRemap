import SwiftUI
import AppKit
import Combine

/// First-launch onboarding sheet: 4 fluid steps with progress dots and slide
/// transitions — welcome, controller pairing (live detection), permissions
/// (live status via `PermissionsManager` polling) and optional Hammerspoon
/// setup. Completion persists `hasCompletedOnboarding`.
struct OnboardingView: View {

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var controllerStatus = ControllerStatusModel.shared
    @ObservedObject private var permissions = PermissionsManager.shared

    @State private var step = 0
    @State private var movingForward = true

    // Hammerspoon step state.
    @State private var spoonSnippet: String?
    @State private var spoonError: String?
    @State private var snippetCopied = false

    private let stepCount = 4

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                currentStep
                    .id(step)
                    .transition(stepTransition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(DS.panelAnimation, value: step)
            .clipped()

            Divider()
            footer
        }
        .frame(width: 640, height: 580)
        .background(DS.canvasBackground)
    }

    // MARK: Transitions

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: movingForward ? .trailing : .leading)
                .combined(with: .opacity),
            removal: .move(edge: movingForward ? .leading : .trailing)
                .combined(with: .opacity)
        )
    }

    // MARK: Steps routing

    @ViewBuilder
    private var currentStep: some View {
        switch step {
        case 0: welcomeStep
        case 1: connectionStep
        case 2: permissionsStep
        default: hammerspoonStep
        }
    }

    // MARK: Footer (dots + navigation)

    private var footer: some View {
        HStack {
            if step > 0 {
                Button("Précédent") { goTo(step - 1) }
                    .buttonStyle(SecondaryButtonStyle())
            } else {
                // Keep the dots centered with a phantom button.
                Button("Précédent") {}
                    .buttonStyle(SecondaryButtonStyle())
                    .hidden()
            }

            Spacer()

            HStack(spacing: DS.s2) {
                ForEach(0..<stepCount, id: \.self) { index in
                    Capsule()
                        .fill(index == step ? DS.accent : DS.separator)
                        .frame(width: index == step ? 22 : 8, height: 8)
                }
            }
            .animation(DS.quickAnimation, value: step)

            Spacer()

            if step < stepCount - 1 {
                Button("Continuer") { goTo(step + 1) }
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                Button("Commencer") { finish() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, DS.s5)
        .padding(.vertical, DS.s4)
    }

    private func goTo(_ newStep: Int) {
        movingForward = newStep > step
        withAnimation(DS.panelAnimation) {
            step = newStep
        }
    }

    private func finish() {
        hasCompletedOnboarding = true
        dismiss()
    }

    // MARK: Step 1 — Welcome

    private var welcomeStep: some View {
        VStack(spacing: DS.s5) {
            Spacer(minLength: DS.s5)

            Image(systemName: "gamecontroller")
                .font(.system(size: 72, weight: .light))
                .foregroundColor(DS.accent)
                .padding(DS.s5)
                .background(Circle().fill(DS.accentTint))

            Text("Bienvenue dans DualSense Remap")
                .font(DS.heroFont)
                .multilineTextAlignment(.center)

            Text("""
            Transformez votre manette PS5 en véritable périphérique macOS : \
            pointeur au stick, clics, raccourcis clavier, défilement, profils \
            par application et clavier virtuel — le tout, depuis votre canapé.
            """)
                .font(DS.bodyFont)
                .foregroundColor(DS.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 460)

            HStack(spacing: DS.s4) {
                onboardingFeatureBadge(symbol: "cursorarrow.motionlines", text: "Souris & défilement")
                onboardingFeatureBadge(symbol: "square.grid.2x2", text: "Profils par app")
                onboardingFeatureBadge(symbol: "keyboard", text: "Clavier virtuel")
            }

            Spacer()
        }
        .padding(.horizontal, DS.s5)
    }

    private func onboardingFeatureBadge(symbol: String, text: String) -> some View {
        VStack(spacing: DS.s2) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .regular))
                .foregroundColor(DS.accent)
            Text(text)
                .font(DS.captionFont)
                .foregroundColor(DS.textSecondary)
        }
        .frame(width: 130)
        .padding(.vertical, DS.s4)
        .dsCard(padding: DS.s2)
    }

    // MARK: Step 2 — Controller connection

    private var connectionStep: some View {
        VStack(alignment: .leading, spacing: DS.s5) {
            onboardingStepTitle("Connectez votre manette",
                                subtitle: "En Bluetooth ou simplement en USB-C.")

            VStack(alignment: .leading, spacing: DS.s3) {
                Label("Association Bluetooth", systemImage: "wave.3.right")
                    .font(DS.headingFont)
                Text("""
                1. Maintenez les boutons PS et Create enfoncés jusqu'à ce que \
                la barre lumineuse clignote.
                2. Ouvrez les Réglages Bluetooth de macOS et sélectionnez \
                « DualSense Wireless Controller ».
                """)
                    .font(DS.bodyFont)
                    .foregroundColor(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Ouvrir les Réglages Bluetooth") {
                    shellOpenBluetoothSettings()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsCard()

            // Live detection card.
            HStack(spacing: DS.s3) {
                if controllerStatus.status.isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DS.success)
                        .transition(.scale.combined(with: .opacity))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manette connectée")
                            .font(DS.headingFont)
                        Text(controllerStatus.status.name.isEmpty
                             ? "DualSense"
                             : controllerStatus.status.name)
                            .font(DS.captionFont)
                            .foregroundColor(DS.textSecondary)
                    }
                } else {
                    ProgressView()
                        .controlSize(.small)
                    Text("En attente de la manette…")
                        .font(DS.bodyFont)
                        .foregroundColor(DS.textSecondary)
                }
                Spacer()
            }
            .dsCard()
            .animation(DS.quickAnimation, value: controllerStatus.status.isConnected)

            Spacer()
        }
        .padding(DS.s5)
    }

    // MARK: Step 3 — Permissions

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: DS.s5) {
            onboardingStepTitle("Autorisations macOS",
                                subtitle: "Deux autorisations pour piloter votre Mac. Aucun redémarrage nécessaire : les statuts se mettent à jour dès que vous les accordez.")

            OnboardingPermissionCard(
                title: "Accessibilité",
                requirement: "Requise",
                requirementColor: permissions.accessibilityGranted ? DS.success : DS.danger,
                explanation: "Permet de simuler le clavier, la souris et le défilement à partir de la manette.",
                granted: permissions.accessibilityGranted,
                promptTitle: "Autoriser…",
                promptAction: { permissions.promptAccessibility() },
                settingsAction: { permissions.openSystemSettings(pane: .accessibility) }
            )

            OnboardingPermissionCard(
                title: "Surveillance de l'entrée",
                requirement: "Optionnelle",
                requirementColor: permissions.inputMonitoringGranted ? DS.success : DS.warning,
                explanation: "Nécessaire uniquement pour le bouton micro (mute) de la manette.",
                granted: permissions.inputMonitoringGranted,
                promptTitle: "Autoriser…",
                promptAction: { permissions.promptInputMonitoring() },
                settingsAction: { permissions.openSystemSettings(pane: .inputMonitoring) }
            )

            Spacer()
        }
        .padding(DS.s5)
        .onAppear { permissions.startPolling() }
        .onDisappear { permissions.stopPolling() }
    }

    // MARK: Step 4 — Hammerspoon

    private var hammerspoonStep: some View {
        VStack(alignment: .leading, spacing: DS.s4) {
            onboardingStepTitle("Hammerspoon (optionnel)",
                                subtitle: "Déclenchez des scripts Lua depuis n'importe quel bouton de la manette.")

            HStack(spacing: DS.s3) {
                Image(systemName: "hammer")
                    .font(.system(size: 22))
                    .foregroundColor(DS.accent)
                if HammerspoonBridge.shared.isInstalled {
                    StatusPill(color: DS.success, label: "Hammerspoon détecté")
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        StatusPill(color: DS.warning, label: "Hammerspoon non détecté")
                        Link("Télécharger sur hammerspoon.org",
                             destination: URL(string: "https://www.hammerspoon.org")!)
                            .font(DS.captionFont)
                    }
                }
                Spacer()
                Button("Installer le Spoon") {
                    installSpoon()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .dsCard()

            if let error = spoonError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(DS.captionFont)
                    .foregroundColor(DS.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let snippet = spoonSnippet {
                VStack(alignment: .leading, spacing: DS.s2) {
                    Text("Spoon installé. Ajoutez ces lignes à votre ~/.hammerspoon/init.lua :")
                        .font(DS.captionFont)
                        .foregroundColor(DS.textSecondary)
                    HStack(alignment: .top, spacing: DS.s3) {
                        Text(snippet)
                            .font(DS.monoFont)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button(snippetCopied ? "Copié ✓" : "Copier") {
                            copySnippet(snippet)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    .padding(DS.s3)
                    .background(
                        RoundedRectangle(cornerRadius: DS.controlRadius, style: .continuous)
                            .fill(DS.insetBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.controlRadius, style: .continuous)
                            .strokeBorder(DS.separator.opacity(0.5), lineWidth: 1)
                    )
                }
                .transition(.opacity)
            }

            Spacer()
        }
        .padding(DS.s5)
        .animation(DS.quickAnimation, value: spoonSnippet)
    }

    private func installSpoon() {
        do {
            let snippet = try HammerspoonBridge.shared.installSpoon()
            spoonSnippet = snippet
            spoonError = nil
            snippetCopied = false
        } catch {
            spoonError = error.localizedDescription
        }
    }

    private func copySnippet(_ snippet: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(snippet, forType: .string)
        snippetCopied = true
    }

    // MARK: Shared pieces

    private func onboardingStepTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: DS.s1) {
            Text(title)
                .font(DS.titleFont)
            Text(subtitle)
                .font(DS.bodyFont)
                .foregroundColor(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Permission card

/// One permission row card: title + requirement pill, plain-language
/// explanation, live status and fix buttons.
struct OnboardingPermissionCard: View {
    let title: String
    let requirement: String
    let requirementColor: Color
    let explanation: String
    let granted: Bool
    let promptTitle: String
    let promptAction: () -> Void
    let settingsAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: DS.s4) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 26))
                .foregroundColor(granted ? DS.success : DS.textTertiary)
                .animation(DS.quickAnimation, value: granted)

            VStack(alignment: .leading, spacing: DS.s1) {
                HStack(spacing: DS.s2) {
                    Text(title)
                        .font(DS.headingFont)
                    StatusPill(color: requirementColor,
                               label: granted ? "Accordée" : requirement)
                }
                Text(explanation)
                    .font(DS.captionFont)
                    .foregroundColor(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: DS.s3)

            if !granted {
                VStack(alignment: .trailing, spacing: DS.s2) {
                    Button(promptTitle, action: promptAction)
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Réglages Système…", action: settingsAction)
                        .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
        .dsCard(padding: DS.s4)
        .animation(DS.quickAnimation, value: granted)
    }
}
