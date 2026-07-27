import Foundation
import SwiftUI
import AppKit
import Combine

/// Virtual keyboard page: static PS5-style AZERTY preview, controller
/// shortcut reference and settings (scale + haptics + Return-on-OK).
public struct VirtualKeyboardPageView: View {

    @ObservedObject private var store = ProfileStore.shared
    @ObservedObject private var keyboard = VirtualKeyboardController.shared

    /// Local mirror of the module preference (UserDefaults is not observable).
    @State private var sendReturnOnDone = VKPreferences.sendReturnOnDone

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroCard
                shortcutsCard
                settingsCard
            }
            .padding(24)
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        HStack(alignment: .center, spacing: 20) {
            PagesMiniAzertyPreview()
            VStack(alignment: .leading, spacing: 10) {
                Text("Clavier AZERTY façon PS5")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(VKPagesPalette.textPrimary)
                Text("Un clavier flottant piloté entièrement à la manette, sans jamais voler le focus : le texte est envoyé directement dans l'application active.")
                    .font(.system(size: 12))
                    .foregroundColor(VKPagesPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    VirtualKeyboardController.shared.toggle()
                } label: {
                    Label(keyboard.isVisible ? "Masquer le clavier" : "Afficher le clavier",
                          systemImage: "keyboard")
                }
                .buttonStyle(PagesPrimaryButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .pagesCard()
        .animation(VKPagesPalette.quick, value: keyboard.isVisible)
    }

    // MARK: - Shortcuts

    private struct KeyboardShortcut: Identifiable {
        let id: String
        let glyph: String
        let title: String
        let detail: String
    }

    private static let shortcuts: [KeyboardShortcut] = [
        KeyboardShortcut(id: "cross", glyph: "✕", title: "Valider",
                         detail: "Appuie sur la touche sélectionnée"),
        KeyboardShortcut(id: "circle", glyph: "○", title: "Fermer",
                         detail: "Masque le clavier virtuel"),
        KeyboardShortcut(id: "triangle", glyph: "△", title: "Espace",
                         detail: "Insère une espace"),
        KeyboardShortcut(id: "square", glyph: "□", title: "Effacer",
                         detail: "Supprime le caractère précédent"),
        KeyboardShortcut(id: "l2", glyph: "L2", title: "Maj",
                         detail: "Maintenir pour les majuscules"),
        KeyboardShortcut(id: "l1r1", glyph: "L1 / R1", title: "Curseur",
                         detail: "Déplace le curseur dans le texte"),
        KeyboardShortcut(id: "r3", glyph: "R3", title: "Accents",
                         detail: "Bascule la page des accents"),
        KeyboardShortcut(id: "r2", glyph: "R2", title: "Terminé",
                         detail: "Envoie Entrée puis ferme le clavier"),
    ]

    private var shortcutsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            PagesSectionHeader("Raccourcis manette",
                               subtitle: "Le clavier reprend la grammaire du clavier PS5")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                      alignment: .leading, spacing: 8) {
                ForEach(Self.shortcuts) { shortcut in
                    shortcutRow(shortcut)
                }
            }
        }
        .pagesCard()
    }

    private func shortcutRow(_ shortcut: KeyboardShortcut) -> some View {
        HStack(spacing: 9) {
            Text(shortcut.glyph)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(VKPagesPalette.accent)
                .padding(.horizontal, 7)
                .frame(height: 24)
                .frame(minWidth: 34)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(VKPagesPalette.accentTint)
                )
            VStack(alignment: .leading, spacing: 0) {
                Text(shortcut.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(VKPagesPalette.textPrimary)
                Text(shortcut.detail)
                    .font(.system(size: 10))
                    .foregroundColor(VKPagesPalette.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Settings

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            PagesSectionHeader("Réglages",
                               subtitle: "Appliqués immédiatement au clavier flottant")
            PagesSliderRow(title: "Taille du clavier",
                           value: $store.settings.virtualKeyboardScale,
                           range: 0.5...2.0,
                           format: { String(format: "%.0f %%", $0 * 100) })
            Toggle("Impulsion haptique à chaque touche", isOn: $store.settings.keyboardHapticFeedback)
                .font(.system(size: 12))
            Toggle("OK (R2) envoie Entrée avant de fermer", isOn: $sendReturnOnDone)
                .font(.system(size: 12))
                .onChange(of: sendReturnOnDone) { newValue in
                    VKPreferences.sendReturnOnDone = newValue
                }
        }
        .pagesCard()
    }
}

// MARK: - Static AZERTY preview

/// Compact, purely decorative AZERTY keyboard in the PS5 dark style.
/// Intentionally independent from the real VirtualKeyboard module.
struct PagesMiniAzertyPreview: View {

    private static let rows: [[String]] = [
        ["a", "z", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["q", "s", "d", "f", "g", "h", "j", "k", "l", "m"],
        ["w", "x", "c", "v", "b", "n", "'", "-", "@", "."],
    ]

    /// The key highlighted as the "cursor" in the preview.
    private static let highlighted = "e"

    var body: some View {
        VStack(spacing: 5) {
            ForEach(0..<Self.rows.count, id: \.self) { rowIndex in
                HStack(spacing: 5) {
                    ForEach(Self.rows[rowIndex], id: \.self) { key in
                        keyCap(key, highlighted: key == Self.highlighted)
                    }
                }
            }
            HStack(spacing: 5) {
                specialKey("⇧", width: 34)
                specialKey("espace", width: 158)
                specialKey("⌫", width: 34)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(VKPagesPalette.keyboardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
        .fixedSize()
        .accessibilityHidden(true)
    }

    private func keyCap(_ label: String, highlighted: Bool) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(highlighted ? .white : Color.white.opacity(0.85))
            .frame(width: 22, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(highlighted ? VKPagesPalette.accent : VKPagesPalette.keyCapFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(highlighted
                                  ? VKPagesPalette.accent.opacity(0.9)
                                  : VKPagesPalette.keyCapStroke,
                                  lineWidth: 1)
            )
    }

    private func specialKey(_ label: String, width: CGFloat) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(Color.white.opacity(0.7))
            .frame(width: width, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(VKPagesPalette.keyCapFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(VKPagesPalette.keyCapStroke, lineWidth: 1)
            )
    }
}
