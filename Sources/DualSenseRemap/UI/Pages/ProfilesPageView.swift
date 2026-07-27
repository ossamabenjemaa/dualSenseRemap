import Foundation
import SwiftUI
import AppKit
import Combine

/// Profile management page: responsive grid of profile cards with inline
/// rename, SF-symbol icon picker, linked applications, lightbar color and
/// activation controls.
public struct ProfilesPageView: View {

    @ObservedObject private var store = ProfileStore.shared

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 310), spacing: 16)],
                          alignment: .leading, spacing: 16) {
                    ForEach(store.profiles) { profile in
                        PagesProfileCard(profile: profile)
                    }
                }
                footer
            }
            .padding(24)
            .frame(maxWidth: 1120)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            PagesSectionHeader("Profils",
                               subtitle: "Créez des configurations complètes et liez-les à vos applications — le bon profil s'active tout seul.")
            Button {
                var profile = Profile(name: "Nouveau profil")
                profile.icon = "gamecontroller"
                store.addProfile(profile)
            } label: {
                Label("Nouveau profil", systemImage: "plus")
            }
            .buttonStyle(PagesPrimaryButtonStyle())
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Changement automatique de profil selon l'application au premier plan",
                   isOn: $store.settings.autoSwitchProfiles)
                .font(.system(size: 12))
            Text("Quand une application liée passe au premier plan, son profil est activé automatiquement ; le profil précédent revient dès qu'une application non liée reprend le premier plan. La couleur de la barre lumineuse suit le profil actif.")
                .font(.system(size: 11))
                .foregroundColor(VKPagesPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .pagesCard(padding: 16)
    }
}

// MARK: - Profile card

struct PagesProfileCard: View {
    let profile: Profile

    @ObservedObject private var store = ProfileStore.shared
    @State private var showIconPicker = false
    @State private var showDeleteConfirm = false
    @State private var showLinkedApps = false

    private static let iconChoices = [
        "gamecontroller", "macwindow", "play.rectangle", "keyboard",
        "music.note", "film", "paintbrush", "photo",
        "safari", "globe", "terminal", "gearshape",
        "star.fill", "bolt.fill", "tv", "display",
        "book", "envelope", "headphones", "scissors",
    ]

    private var storedProfile: Profile {
        store.profiles.first(where: { $0.id == profile.id }) ?? profile
    }

    private var isActive: Bool {
        store.activeProfileID == profile.id
    }

    private var canDelete: Bool {
        store.profiles.count > 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            topRow
            linkedAppsRow
            lightbarRow
        }
        .pagesCard(padding: 16)
        .overlay(
            RoundedRectangle(cornerRadius: VKPagesPalette.cardRadius, style: .continuous)
                .strokeBorder(isActive ? VKPagesPalette.accent.opacity(0.7) : Color.clear,
                              lineWidth: 1.5)
        )
        .animation(VKPagesPalette.quick, value: isActive)
        .contextMenu {
            Button("Activer") { store.activateProfile(id: profile.id) }
            Button("Dupliquer") { duplicate() }
            Button("Supprimer") { showDeleteConfirm = true }
                .disabled(!canDelete)
        }
        .confirmationDialog("Supprimer le profil « \(storedProfile.name) » ?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                store.deleteProfile(id: profile.id)
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Les affectations de ce profil seront définitivement perdues.")
        }
        .sheet(isPresented: $showLinkedApps) {
            PagesLinkedAppsSheet(profileID: profile.id)
        }
    }

    // MARK: Rows

    private var topRow: some View {
        HStack(spacing: 10) {
            Button {
                showIconPicker = true
            } label: {
                Image(systemName: storedProfile.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(VKPagesPalette.accent)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(VKPagesPalette.accentTint)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .help("Changer l'icône")
            .popover(isPresented: $showIconPicker, arrowEdge: .bottom) {
                iconPicker
            }

            TextField("Nom du profil", text: nameBinding)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 14, weight: .semibold))

            Spacer(minLength: 0)

            if isActive {
                HStack(spacing: 4) {
                    Circle().fill(VKPagesPalette.success).frame(width: 7, height: 7)
                    Text("Actif")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(VKPagesPalette.success)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(VKPagesPalette.success.opacity(0.12)))
            } else {
                Button("Activer") { store.activateProfile(id: profile.id) }
                    .buttonStyle(PagesSecondaryButtonStyle())
            }

            Menu {
                Button("Dupliquer") { duplicate() }
                Button("Supprimer") { showDeleteConfirm = true }
                    .disabled(!canDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 13))
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .frame(width: 24)
        }
    }

    private var iconPicker: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 34), spacing: 6)], spacing: 6) {
            ForEach(Self.iconChoices, id: \.self) { symbol in
                Button {
                    update { $0.icon = symbol }
                    showIconPicker = false
                } label: {
                    Image(systemName: symbol)
                        .font(.system(size: 13))
                        .foregroundColor(storedProfile.icon == symbol
                                         ? VKPagesPalette.accent
                                         : VKPagesPalette.textPrimary)
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(storedProfile.icon == symbol
                                      ? VKPagesPalette.accentTint
                                      : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(10)
        .frame(width: 210)
    }

    private var linkedAppsRow: some View {
        HStack(spacing: 8) {
            Text("Applications liées")
                .font(.system(size: 11))
                .foregroundColor(VKPagesPalette.textSecondary)
            if storedProfile.linkedAppBundleIDs.isEmpty {
                Text("Aucune")
                    .font(.system(size: 11))
                    .foregroundColor(VKPagesPalette.textTertiary)
            } else {
                HStack(spacing: 3) {
                    ForEach(storedProfile.linkedAppBundleIDs.prefix(6), id: \.self) { bundleID in
                        linkedAppIcon(bundleID)
                    }
                    if storedProfile.linkedAppBundleIDs.count > 6 {
                        Text("+\(storedProfile.linkedAppBundleIDs.count - 6)")
                            .font(.system(size: 10))
                            .foregroundColor(VKPagesPalette.textTertiary)
                    }
                }
            }
            Spacer(minLength: 0)
            Button("Modifier…") { showLinkedApps = true }
                .buttonStyle(PagesSecondaryButtonStyle())
        }
    }

    @ViewBuilder
    private func linkedAppIcon(_ bundleID: String) -> some View {
        if let icon = PagesAppIconResolver.icon(forBundleID: bundleID) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 18, height: 18)
                .help(PagesAppIconResolver.name(forBundleID: bundleID))
        } else {
            Image(systemName: "app.dashed")
                .font(.system(size: 12))
                .foregroundColor(VKPagesPalette.textTertiary)
                .help(bundleID)
        }
    }

    private var lightbarRow: some View {
        HStack {
            Text("Barre lumineuse")
                .font(.system(size: 11))
                .foregroundColor(VKPagesPalette.textSecondary)
            Spacer()
            ColorPicker("", selection: lightbarBinding, supportsOpacity: false)
                .labelsHidden()
        }
    }

    // MARK: Mutations

    private func update(_ transform: (inout Profile) -> Void) {
        var updated = storedProfile
        transform(&updated)
        store.updateProfile(updated)
    }

    private func duplicate() {
        var copy = storedProfile
        copy.id = UUID()
        copy.name = storedProfile.name + " (copie)"
        store.addProfile(copy)
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { storedProfile.name },
            set: { newValue in update { $0.name = newValue } }
        )
    }

    private var lightbarBinding: Binding<Color> {
        Binding(
            get: {
                let lightbar = storedProfile.lightbar
                return Color(red: lightbar.red, green: lightbar.green, blue: lightbar.blue)
            },
            set: { newColor in
                guard let rgb = NSColor(newColor).usingColorSpace(.sRGB) else { return }
                let red = Double(rgb.redComponent)
                let green = Double(rgb.greenComponent)
                let blue = Double(rgb.blueComponent)
                update { $0.lightbar.red = red; $0.lightbar.green = green; $0.lightbar.blue = blue }
                if isActive {
                    DualSenseManager.shared.setLightbar(red: red, green: green, blue: blue)
                }
            }
        )
    }
}

// MARK: - Linked applications sheet

struct PagesLinkedAppsSheet: View {
    let profileID: UUID

    @ObservedObject private var store = ProfileStore.shared
    @Environment(\.dismiss) private var dismiss

    private var profile: Profile {
        store.profiles.first(where: { $0.id == profileID }) ?? store.activeProfile
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Applications liées — \(profile.name)")
                .font(.system(size: 15, weight: .semibold))

            if profile.linkedAppBundleIDs.isEmpty {
                Text("Aucune application liée pour l'instant.")
                    .font(.system(size: 12))
                    .foregroundColor(VKPagesPalette.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(profile.linkedAppBundleIDs, id: \.self) { bundleID in
                            appRow(bundleID)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }

            Button {
                if let app = PagesAppPicker.pickApplication() {
                    addBundleID(app.bundleID)
                }
            } label: {
                Label("Ajouter une application…", systemImage: "plus")
            }
            .buttonStyle(PagesSecondaryButtonStyle())

            Text("Quand l'une de ces applications passe au premier plan, ce profil s'active automatiquement (si le changement automatique est activé dans l'onglet Profils).")
                .font(.system(size: 11))
                .foregroundColor(VKPagesPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Fermer") { dismiss() }
                    .buttonStyle(PagesPrimaryButtonStyle())
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    private func appRow(_ bundleID: String) -> some View {
        HStack(spacing: 8) {
            if let icon = PagesAppIconResolver.icon(forBundleID: bundleID) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 22, height: 22)
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: 14))
                    .foregroundColor(VKPagesPalette.textTertiary)
                    .frame(width: 22, height: 22)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(PagesAppIconResolver.name(forBundleID: bundleID))
                    .font(.system(size: 12, weight: .medium))
                Text(bundleID)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(VKPagesPalette.textTertiary)
            }
            Spacer()
            Button {
                removeBundleID(bundleID)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(VKPagesPalette.danger)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Retirer")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }

    private func addBundleID(_ bundleID: String) {
        var updated = profile
        guard !updated.linkedAppBundleIDs.contains(bundleID) else { return }
        updated.linkedAppBundleIDs.append(bundleID)
        store.updateProfile(updated)
    }

    private func removeBundleID(_ bundleID: String) {
        var updated = profile
        updated.linkedAppBundleIDs.removeAll { $0 == bundleID }
        store.updateProfile(updated)
    }
}
