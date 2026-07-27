import Foundation
import SwiftUI
import AppKit
import Combine

// MARK: - Categories

enum PagesActionCategory: String, CaseIterable, Identifiable {
    case keyboard
    case mouse
    case system
    case apps
    case hammerspoon
    case macros
    case remap
    case clear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keyboard: return "Clavier"
        case .mouse: return "Souris"
        case .system: return "Système"
        case .apps: return "Apps & commandes"
        case .hammerspoon: return "Hammerspoon"
        case .macros: return "Macros"
        case .remap: return "DualSense Remap"
        case .clear: return "Aucune"
        }
    }

    var symbol: String {
        switch self {
        case .keyboard: return "keyboard"
        case .mouse: return "cursorarrow.click"
        case .system: return "gearshape"
        case .apps: return "app"
        case .hammerspoon: return "hammer"
        case .macros: return "list.number"
        case .remap: return "gamecontroller"
        case .clear: return "slash.circle"
        }
    }

    static func category(for action: Action) -> PagesActionCategory {
        switch action {
        case .none: return .keyboard
        case .keyCombo, .typeText: return .keyboard
        case .mouse: return .mouse
        case .system: return .system
        case .hammerspoon: return .hammerspoon
        case .shellCommand, .openApp, .openURL: return .apps
        case .macro: return .macros
        case .toggleVirtualKeyboard, .cycleProfile, .openMappingWindow: return .remap
        }
    }
}

// MARK: - Macro row model

struct PagesMacroRow: Identifiable, Equatable {
    let id: UUID
    var step: MacroStep

    init(step: MacroStep) {
        self.id = UUID()
        self.step = step
    }
}

// MARK: - Mapping editor

/// Popover editor assigning an `Action` to a digital controller element.
/// Every write goes through `ProfileStore.updateProfile` on the active profile.
struct MappingEditorView: View {
    let element: ControllerElement

    @ObservedObject private var store = ProfileStore.shared
    @StateObject private var recorder = PagesKeyRecorder()
    @Environment(\.dismiss) private var dismiss

    @State private var category: PagesActionCategory

    // Keyboard
    @State private var recordedCombo: KeyCombo?
    @State private var textToType = ""
    // Mouse
    @State private var mouseSelection: MouseButtonAction = .leftClick
    // System
    @State private var systemSelection: SystemAction?
    // Apps & commands
    @State private var pickedApp: PagesAppInfo?
    @State private var urlString = ""
    @State private var shellCommand = ""
    // Hammerspoon
    @State private var hammerspoonEvent = ""
    // Macros
    @State private var macroName = ""
    @State private var macroRows: [PagesMacroRow] = []
    // Remap
    @State private var remapSelection: Action = .toggleVirtualKeyboard

    private static let hammerspoonSuggestions = [
        "launchpad", "missionControl", "showDesktop",
        "windowLeft", "windowRight", "windowMax",
        "focusApp", "spaceLeft", "spaceRight",
    ]

    init(element: ControllerElement) {
        self.element = element
        let current = ProfileStore.shared.activeProfile.action(for: element)
        _category = State(initialValue: PagesActionCategory.category(for: current))

        switch current {
        case .keyCombo(let combo):
            _recordedCombo = State(initialValue: combo)
        case .typeText(let text):
            _textToType = State(initialValue: text)
        case .mouse(let button):
            _mouseSelection = State(initialValue: button)
        case .system(let action):
            _systemSelection = State(initialValue: action)
        case .openApp(let bundleID, let name):
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
                ?? URL(fileURLWithPath: "/Applications", isDirectory: true)
            _pickedApp = State(initialValue: PagesAppInfo(bundleID: bundleID, name: name, url: url))
        case .openURL(let url):
            _urlString = State(initialValue: url)
        case .shellCommand(let command):
            _shellCommand = State(initialValue: command)
        case .hammerspoon(let event):
            _hammerspoonEvent = State(initialValue: event)
        case .macro(let name, let steps):
            _macroName = State(initialValue: name)
            _macroRows = State(initialValue: steps.map { PagesMacroRow(step: $0) })
        case .toggleVirtualKeyboard, .cycleProfile, .openMappingWindow:
            _remapSelection = State(initialValue: current)
        case .none:
            break
        }
    }

    private var currentAction: Action {
        store.activeProfile.action(for: element)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                categoryColumn
                Divider()
                ScrollView {
                    panel
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(width: 470, height: 460)
        .onDisappear { recorder.cancel() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(element.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(VKPagesPalette.textPrimary)
                Text("Affectation actuelle : \(currentAction.displayName)")
                    .font(.system(size: 11))
                    .foregroundColor(VKPagesPalette.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            if currentAction != Action.none {
                Button("Retirer") { assign(.none) }
                    .buttonStyle(PagesSecondaryButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: Category column

    private var categoryColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(PagesActionCategory.allCases) { entry in
                    categoryButton(entry)
                }
            }
            .padding(8)
        }
        .frame(width: 150)
    }

    private func categoryButton(_ entry: PagesActionCategory) -> some View {
        let isSelected = category == entry
        return Button {
            withAnimation(VKPagesPalette.quick) { category = entry }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: entry.symbol)
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 16)
                Text(entry.title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundColor(isSelected ? VKPagesPalette.accent : VKPagesPalette.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? VKPagesPalette.accentTint : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: Panels

    @ViewBuilder
    private var panel: some View {
        switch category {
        case .keyboard: keyboardPanel
        case .mouse: mousePanel
        case .system: systemPanel
        case .apps: appsPanel
        case .hammerspoon: hammerspoonPanel
        case .macros: macrosPanel
        case .remap: remapPanel
        case .clear: clearPanel
        }
    }

    // Keyboard

    private var keyboardPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelTitle("Raccourci clavier")
            recorderField(
                label: recordedCombo?.displayName,
                placeholder: "Cliquer puis appuyer une touche…",
                isRecording: recorder.isRecording
            ) {
                if recorder.isRecording {
                    recorder.cancel()
                } else {
                    recorder.begin { combo in recordedCombo = combo }
                }
            }
            Button("Assigner le raccourci") {
                if let combo = recordedCombo { assign(.keyCombo(combo)) }
            }
            .buttonStyle(PagesPrimaryButtonStyle())
            .disabled(recordedCombo == nil)

            Divider().padding(.vertical, 2)

            panelTitle("Taper du texte")
            TextField("Texte à taper…", text: $textToType)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button("Assigner le texte") {
                assign(.typeText(textToType))
            }
            .buttonStyle(PagesPrimaryButtonStyle())
            .disabled(textToType.isEmpty)
        }
    }

    // Mouse

    private var mousePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelTitle("Action souris")
            VStack(alignment: .leading, spacing: 4) {
                ForEach(MouseButtonAction.allCases, id: \.self) { button in
                    radioRow(title: button.displayName,
                             isSelected: mouseSelection == button) {
                        mouseSelection = button
                    }
                }
            }
            Button("Assigner") { assign(.mouse(mouseSelection)) }
                .buttonStyle(PagesPrimaryButtonStyle())
        }
    }

    // System

    private var systemPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelTitle("Action système")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(SystemAction.allCases, id: \.self) { action in
                    systemCell(action)
                }
            }
            Button("Assigner") {
                if let action = systemSelection { assign(.system(action)) }
            }
            .buttonStyle(PagesPrimaryButtonStyle())
            .disabled(systemSelection == nil)
        }
    }

    private func systemCell(_ action: SystemAction) -> some View {
        let isSelected = systemSelection == action
        return Button {
            withAnimation(VKPagesPalette.quick) { systemSelection = action }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: PagesSystemActionSymbols.symbol(for: action))
                    .font(.system(size: 11))
                    .frame(width: 16)
                Text(action.displayName)
                    .font(.system(size: 11))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundColor(isSelected ? VKPagesPalette.accent : VKPagesPalette.textPrimary)
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? VKPagesPalette.accentTint : VKPagesPalette.insetBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(isSelected ? VKPagesPalette.accent : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // Apps & commands

    private var appsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            appSection
            Divider().padding(.vertical, 2)
            urlSection
            Divider().padding(.vertical, 2)
            shellSection
        }
    }

    private var appSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelTitle("Ouvrir une application")
            HStack(spacing: 8) {
                if let app = pickedApp {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                        .resizable()
                        .frame(width: 20, height: 20)
                    Text(app.name)
                        .font(.system(size: 12))
                        .lineLimit(1)
                } else {
                    Text("Aucune application choisie")
                        .font(.system(size: 12))
                        .foregroundColor(VKPagesPalette.textTertiary)
                }
                Spacer()
                Button("Choisir…") {
                    if let app = PagesAppPicker.pickApplication() { pickedApp = app }
                }
                .buttonStyle(PagesSecondaryButtonStyle())
            }
            Button("Assigner l'application") {
                if let app = pickedApp {
                    assign(.openApp(bundleID: app.bundleID, name: app.name))
                }
            }
            .buttonStyle(PagesPrimaryButtonStyle())
            .disabled(pickedApp == nil)
        }
    }

    private var urlSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelTitle("Ouvrir une URL")
            TextField("https://…", text: $urlString)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button("Assigner l'URL") { assign(.openURL(urlString)) }
                .buttonStyle(PagesPrimaryButtonStyle())
                .disabled(urlString.isEmpty)
        }
    }

    private var shellSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelTitle("Commande shell")
            TextField("open -a Terminal…", text: $shellCommand)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 11, design: .monospaced))
            Button("Assigner la commande") { assign(.shellCommand(shellCommand)) }
                .buttonStyle(PagesPrimaryButtonStyle())
                .disabled(shellCommand.isEmpty)
            HStack(alignment: .top, spacing: 5) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundColor(VKPagesPalette.warning)
                Text("La commande s'exécute avec vos privilèges utilisateur — à utiliser avec prudence.")
                    .font(.system(size: 10))
                    .foregroundColor(VKPagesPalette.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // Hammerspoon

    private var hammerspoonPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelTitle("Événement Hammerspoon")
            TextField("Nom de l'événement (ex. launchpad)", text: $hammerspoonEvent)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 11, design: .monospaced))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 6)],
                      alignment: .leading, spacing: 6) {
                ForEach(Self.hammerspoonSuggestions, id: \.self) { suggestion in
                    Button(suggestion) { hammerspoonEvent = suggestion }
                        .buttonStyle(PagesChipButtonStyle(isSelected: hammerspoonEvent == suggestion))
                }
            }
            if !HammerspoonBridge.shared.isInstalled {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(VKPagesPalette.warning)
                    Text("Hammerspoon n'est pas installé — l'événement ne sera déclenché qu'après son installation (voir l'onglet Hammerspoon).")
                        .font(.system(size: 10))
                        .foregroundColor(VKPagesPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button("Assigner l'événement") { assign(.hammerspoon(event: hammerspoonEvent)) }
                .buttonStyle(PagesPrimaryButtonStyle())
                .disabled(hammerspoonEvent.isEmpty)
        }
    }

    // Macros

    private var macrosPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelTitle("Macro")
            TextField("Nom de la macro", text: $macroName)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            VStack(spacing: 6) {
                ForEach(macroRows) { row in
                    macroRowView(row)
                }
            }
            if macroRows.isEmpty {
                Text("Aucune étape — ajoutez des touches, du texte ou des attentes.")
                    .font(.system(size: 11))
                    .foregroundColor(VKPagesPalette.textTertiary)
            }

            Menu {
                Button("Ajouter une touche") {
                    macroRows.append(PagesMacroRow(step: .keyCombo(
                        KeyCombo(keyCode: 49, modifiers: [], label: "Espace"))))
                }
                Button("Ajouter du texte") {
                    macroRows.append(PagesMacroRow(step: .text("")))
                }
                Button("Ajouter une attente") {
                    macroRows.append(PagesMacroRow(step: .wait(milliseconds: 200)))
                }
            } label: {
                Label("Ajouter une étape", systemImage: "plus")
                    .font(.system(size: 12))
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .fixedSize()

            Button("Assigner la macro") {
                let name = macroName.isEmpty ? "Macro" : macroName
                assign(.macro(name: name, steps: macroRows.map { $0.step }))
            }
            .buttonStyle(PagesPrimaryButtonStyle())
            .disabled(macroRows.isEmpty)
        }
    }

    @ViewBuilder
    private func macroRowView(_ row: PagesMacroRow) -> some View {
        HStack(spacing: 6) {
            switch row.step {
            case .keyCombo(let combo):
                Image(systemName: "keyboard")
                    .font(.system(size: 10))
                    .foregroundColor(VKPagesPalette.textSecondary)
                Button {
                    recorder.begin { newCombo in
                        updateRow(row.id, step: .keyCombo(newCombo))
                    }
                } label: {
                    Text(recorder.isRecording ? "Appuyez…" : combo.displayName)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(VKPagesPalette.insetBackground)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            case .text:
                Image(systemName: "textformat")
                    .font(.system(size: 10))
                    .foregroundColor(VKPagesPalette.textSecondary)
                TextField("Texte", text: macroTextBinding(row.id))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 11))
            case .wait(let milliseconds):
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundColor(VKPagesPalette.textSecondary)
                Stepper("\(milliseconds) ms",
                        value: macroWaitBinding(row.id),
                        in: 50...5000, step: 50)
                    .font(.system(size: 11))
            }
            Spacer(minLength: 0)
            macroRowControls(row)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }

    private func macroRowControls(_ row: PagesMacroRow) -> some View {
        HStack(spacing: 3) {
            Button { moveRow(row.id, delta: -1) } label: {
                Image(systemName: "chevron.up").font(.system(size: 9))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(macroRows.first?.id == row.id)
            Button { moveRow(row.id, delta: 1) } label: {
                Image(systemName: "chevron.down").font(.system(size: 9))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(macroRows.last?.id == row.id)
            Button { macroRows.removeAll { $0.id == row.id } } label: {
                Image(systemName: "trash").font(.system(size: 9))
                    .foregroundColor(VKPagesPalette.danger)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .foregroundColor(VKPagesPalette.textSecondary)
    }

    private func updateRow(_ id: UUID, step: MacroStep) {
        if let index = macroRows.firstIndex(where: { $0.id == id }) {
            macroRows[index].step = step
        }
    }

    private func moveRow(_ id: UUID, delta: Int) {
        guard let index = macroRows.firstIndex(where: { $0.id == id }) else { return }
        let target = index + delta
        guard target >= 0 && target < macroRows.count else { return }
        macroRows.swapAt(index, target)
    }

    private func macroTextBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: {
                if let row = macroRows.first(where: { $0.id == id }),
                   case .text(let text) = row.step {
                    return text
                }
                return ""
            },
            set: { newValue in updateRow(id, step: .text(newValue)) }
        )
    }

    private func macroWaitBinding(_ id: UUID) -> Binding<Int> {
        Binding(
            get: {
                if let row = macroRows.first(where: { $0.id == id }),
                   case .wait(let milliseconds) = row.step {
                    return milliseconds
                }
                return 200
            },
            set: { newValue in updateRow(id, step: .wait(milliseconds: newValue)) }
        )
    }

    // Remap (app-internal actions)

    private var remapPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelTitle("Fonctions DualSense Remap")
            VStack(alignment: .leading, spacing: 4) {
                radioRow(title: "Afficher / masquer le clavier virtuel",
                         isSelected: remapSelection == .toggleVirtualKeyboard) {
                    remapSelection = .toggleVirtualKeyboard
                }
                radioRow(title: "Profil suivant",
                         isSelected: remapSelection == .cycleProfile) {
                    remapSelection = .cycleProfile
                }
                radioRow(title: "Ouvrir la fenêtre DualSense Remap",
                         isSelected: remapSelection == .openMappingWindow) {
                    remapSelection = .openMappingWindow
                }
            }
            Button("Assigner") { assign(remapSelection) }
                .buttonStyle(PagesPrimaryButtonStyle())
        }
    }

    // Clear

    private var clearPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelTitle("Aucune action")
            Text("Le bouton \(element.displayName) ne déclenchera aucune action.")
                .font(.system(size: 11))
                .foregroundColor(VKPagesPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Effacer l'affectation") { assign(.none) }
                .buttonStyle(PagesPrimaryButtonStyle())
        }
    }

    // MARK: Shared bits

    private func panelTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(VKPagesPalette.textPrimary)
    }

    private func radioRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? VKPagesPalette.accent : VKPagesPalette.textTertiary)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(VKPagesPalette.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func recorderField(label: String?,
                               placeholder: String,
                               isRecording: Bool,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(isRecording ? "Appuyez sur une touche…" : (label ?? placeholder))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(isRecording
                                     ? VKPagesPalette.accent
                                     : (label == nil
                                        ? VKPagesPalette.textTertiary
                                        : VKPagesPalette.textPrimary))
                Spacer()
                Image(systemName: isRecording ? "record.circle" : "keyboard")
                    .font(.system(size: 11))
                    .foregroundColor(isRecording ? VKPagesPalette.accent : VKPagesPalette.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(VKPagesPalette.insetBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(isRecording ? VKPagesPalette.accent : VKPagesPalette.separator.opacity(0.6),
                                  lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .animation(VKPagesPalette.quick, value: isRecording)
    }

    // MARK: Assignment

    private func assign(_ action: Action) {
        var profile = store.activeProfile
        if case .none = action {
            profile.mappings.removeValue(forKey: element)
        } else {
            profile.mappings[element] = action
        }
        store.updateProfile(profile)
        dismiss()
    }
}
