import Foundation
import SwiftUI
import AppKit
import Combine

/// Hammerspoon integration page: install status, Spoon installation with a
/// copyable init.lua snippet, event reference with test buttons, and an
/// explanation of the bidirectional bridge.
public struct HammerspoonPageView: View {

    @State private var isInstalled = HammerspoonBridge.shared.isInstalled
    @State private var installedSnippet: String?
    @State private var installError: String?
    @State private var didCopySnippet = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statusCard
                installCard
                eventsCard
                footerCard
            }
            .padding(24)
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { refreshStatus() }
    }

    private func refreshStatus() {
        withAnimation(VKPagesPalette.quick) {
            isInstalled = HammerspoonBridge.shared.isInstalled
        }
    }

    // MARK: - Status card

    private var statusCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(isInstalled ? VKPagesPalette.success : VKPagesPalette.textTertiary)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill((isInstalled ? VKPagesPalette.success : VKPagesPalette.textTertiary).opacity(0.12))
                )
            VStack(alignment: .leading, spacing: 3) {
                Text("Hammerspoon")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(VKPagesPalette.textPrimary)
                HStack(spacing: 6) {
                    Circle()
                        .fill(isInstalled ? VKPagesPalette.success : VKPagesPalette.warning)
                        .frame(width: 7, height: 7)
                    Text(isInstalled
                         ? "Installé — les événements peuvent être déclenchés"
                         : "Non installé — téléchargez-le depuis hammerspoon.org")
                        .font(.system(size: 11))
                        .foregroundColor(VKPagesPalette.textSecondary)
                }
            }
            Spacer()
            Button("Actualiser") { refreshStatus() }
                .buttonStyle(PagesSecondaryButtonStyle())
            Button("hammerspoon.org") {
                if let url = URL(string: "https://www.hammerspoon.org") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(PagesSecondaryButtonStyle())
        }
        .pagesCard()
    }

    // MARK: - Install card

    private var installCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            PagesSectionHeader("Installer l'intégration",
                               subtitle: "Copie le Spoon « DualSenseRemap » dans ~/.hammerspoon/Spoons puis ajoutez trois lignes à votre init.lua.")
            HStack(spacing: 10) {
                Button {
                    install()
                } label: {
                    Label("Installer l'intégration", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(PagesPrimaryButtonStyle())
                if installedSnippet != nil {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(VKPagesPalette.success)
                        Text("Spoon installé")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(VKPagesPalette.success)
                    }
                }
            }
            if let error = installError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(VKPagesPalette.danger)
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(VKPagesPalette.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let snippet = installedSnippet {
                snippetBox(snippet)
            }
        }
        .pagesCard()
        .animation(VKPagesPalette.quick, value: installedSnippet)
    }

    private func install() {
        installError = nil
        do {
            let snippet = try HammerspoonBridge.shared.installSpoon()
            withAnimation(VKPagesPalette.quick) { installedSnippet = snippet }
        } catch {
            withAnimation(VKPagesPalette.quick) {
                installError = error.localizedDescription
                installedSnippet = nil
            }
        }
    }

    private func snippetBox(_ snippet: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ajoutez ces lignes à ~/.hammerspoon/init.lua puis rechargez la configuration :")
                .font(.system(size: 11))
                .foregroundColor(VKPagesPalette.textSecondary)
            HStack(alignment: .top, spacing: 10) {
                Text(snippet)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(VKPagesPalette.textPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(didCopySnippet ? "Copié !" : "Copier") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(snippet, forType: .string)
                    withAnimation(VKPagesPalette.quick) { didCopySnippet = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        withAnimation(VKPagesPalette.quick) { didCopySnippet = false }
                    }
                }
                .buttonStyle(PagesSecondaryButtonStyle())
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(VKPagesPalette.insetBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(VKPagesPalette.separator.opacity(0.6), lineWidth: 1)
            )
        }
    }

    // MARK: - Events reference

    private struct HammerspoonEvent: Identifiable {
        let name: String
        let detail: String
        var params: [String: String] = [:]
        var id: String { name }
    }

    private static let events: [HammerspoonEvent] = [
        HammerspoonEvent(name: "launchpad", detail: "Ouvrir le Launchpad"),
        HammerspoonEvent(name: "missionControl", detail: "Afficher Mission Control"),
        HammerspoonEvent(name: "showDesktop", detail: "Afficher le bureau"),
        HammerspoonEvent(name: "appSwitcher", detail: "Sélecteur d'applications"),
        HammerspoonEvent(name: "focusApp", detail: "Donner le focus à une application (paramètre « bundle »)",
                         params: ["bundle": "com.apple.Safari"]),
        HammerspoonEvent(name: "windowLeft", detail: "Fenêtre : moitié gauche de l'écran"),
        HammerspoonEvent(name: "windowRight", detail: "Fenêtre : moitié droite de l'écran"),
        HammerspoonEvent(name: "windowMax", detail: "Fenêtre : agrandir (plein écran fenêtré)"),
        HammerspoonEvent(name: "windowCenter", detail: "Fenêtre : centrer sur l'écran"),
        HammerspoonEvent(name: "mediaPlayPause", detail: "Musique : lecture / pause"),
        HammerspoonEvent(name: "mediaNext", detail: "Musique : piste suivante"),
        HammerspoonEvent(name: "mediaPrevious", detail: "Musique : piste précédente"),
        HammerspoonEvent(name: "spaceLeft", detail: "Bureau (Space) précédent"),
        HammerspoonEvent(name: "spaceRight", detail: "Bureau (Space) suivant"),
    ]

    private var eventsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            PagesSectionHeader("Événements disponibles",
                               subtitle: "Assignez-les à n'importe quel bouton depuis la page Manette (catégorie Hammerspoon).")
            VStack(spacing: 4) {
                ForEach(Self.events) { event in
                    eventRow(event)
                }
            }
        }
        .pagesCard()
    }

    private func eventRow(_ event: HammerspoonEvent) -> some View {
        HStack(spacing: 10) {
            Text(event.name)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(VKPagesPalette.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(VKPagesPalette.accentTint))
                .frame(minWidth: 118, alignment: .leading)
            Text(event.detail)
                .font(.system(size: 11))
                .foregroundColor(VKPagesPalette.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button("Tester") {
                HammerspoonBridge.shared.trigger(event.name, params: event.params)
            }
            .buttonStyle(PagesSecondaryButtonStyle())
            .disabled(!isInstalled)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }

    // MARK: - Footer

    private var footerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            PagesSectionHeader("Un pont dans les deux sens")
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "gamecontroller")
                    .font(.system(size: 12))
                    .foregroundColor(VKPagesPalette.accent)
                    .frame(width: 18)
                Text("Manette → Hammerspoon : chaque bouton peut déclencher un événement « dsr » (URL hammerspoon://dsr?event=…), que votre configuration Lua intercepte pour piloter fenêtres, Spaces, musique, etc.")
                    .font(.system(size: 11))
                    .foregroundColor(VKPagesPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "hammer")
                    .font(.system(size: 12))
                    .foregroundColor(VKPagesPalette.accent)
                    .frame(width: 18)
                Text("Hammerspoon → DualSense Remap : vos raccourcis Lua peuvent ouvrir des URLs dualsenseremap:// (par exemple pour afficher ou masquer le clavier virtuel) — l'automatisation fonctionne donc dans les deux sens.")
                    .font(.system(size: 11))
                    .foregroundColor(VKPagesPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .pagesCard()
    }
}
