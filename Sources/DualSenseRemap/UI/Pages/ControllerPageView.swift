import Foundation
import SwiftUI
import AppKit
import Combine

/// Identifies which mapping editor popover is open (diagram hotspot vs
/// callout list row — each anchors its own popover).
fileprivate struct PagesEditTarget: Equatable {
    var element: ControllerElement
    var fromList: Bool
}

/// The hero page: schematic DualSense with interactive hotspots, Logi-style
/// callout columns showing current bindings, and tuning cards for the analog
/// subsystems (sticks, triggers, touchpad, gyroscope).
public struct ControllerPageView: View {

    @ObservedObject private var manager = DualSenseManager.shared
    @ObservedObject private var store = ProfileStore.shared

    @State private var hoveredElement: ControllerElement?
    @State private var editTarget: PagesEditTarget?

    private static let leftCalloutElements: [ControllerElement] = [
        .l2, .l1, .create, .touchpadClick, .ps, .mute,
    ]
    private static let rightCalloutElements: [ControllerElement] = [
        .r2, .r1, .options, .triangle, .circle, .cross, .square,
    ]

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroCard
                tuningGrid
            }
            .padding(24)
            .frame(maxWidth: 1120)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Hero card

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            statusRow
            HStack(alignment: .center, spacing: 14) {
                calloutColumn(Self.leftCalloutElements, arrowEdge: .leading)
                diagramArea
                    .frame(maxWidth: .infinity)
                calloutColumn(Self.rightCalloutElements, arrowEdge: .trailing)
            }
            Text("Survolez un élément de la manette puis cliquez pour changer son affectation. Les pressions réelles s'illuminent en direct.")
                .font(.system(size: 11))
                .foregroundColor(VKPagesPalette.textTertiary)
        }
        .pagesCard()
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(manager.snapshot.isConnected ? VKPagesPalette.success : VKPagesPalette.textTertiary)
                .frame(width: 8, height: 8)
            Text(manager.snapshot.isConnected
                 ? (manager.snapshot.controllerName.isEmpty ? "Manette connectée" : manager.snapshot.controllerName)
                 : "Aucune manette connectée — les réglages restent modifiables")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(VKPagesPalette.textPrimary)
            Spacer()
            if manager.snapshot.isConnected {
                HStack(spacing: 4) {
                    Image(systemName: batterySymbol)
                        .font(.system(size: 11))
                    Text("\(Int(manager.snapshot.battery.level * 100)) %")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(VKPagesPalette.textSecondary)
            }
            HStack(spacing: 5) {
                Image(systemName: store.activeProfile.icon)
                    .font(.system(size: 10))
                Text(store.activeProfile.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(VKPagesPalette.accent)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(VKPagesPalette.accentTint))
        }
        .animation(VKPagesPalette.quick, value: manager.snapshot.isConnected)
    }

    private var batterySymbol: String {
        switch manager.snapshot.battery.state {
        case .charging: return "battery.100.bolt"
        default:
            let level = manager.snapshot.battery.level
            if level > 0.6 { return "battery.100" }
            if level > 0.25 { return "battery.50" }
            return "battery.25"
        }
    }

    // MARK: - Diagram + hotspots

    private var diagramArea: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / PagesDiagramLayout.baseSize.width,
                            geo.size.height / PagesDiagramLayout.baseSize.height)
            ZStack(alignment: .topLeading) {
                ControllerDiagram(snapshot: manager.snapshot,
                                  lightbarColor: activeLightbarColor,
                                  scale: scale)
                hotspotLayer(scale: scale)
            }
            .frame(width: PagesDiagramLayout.baseSize.width * scale,
                   height: PagesDiagramLayout.baseSize.height * scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(PagesDiagramLayout.baseSize.width / PagesDiagramLayout.baseSize.height,
                     contentMode: .fit)
        .frame(minWidth: 320, maxWidth: 560)
    }

    private var activeLightbarColor: Color {
        let lightbar = store.activeProfile.lightbar
        return Color(red: lightbar.red, green: lightbar.green, blue: lightbar.blue)
    }

    private func hotspotLayer(scale: CGFloat) -> some View {
        ForEach(PagesDiagramLayout.hotspotElements) { element in
            hotspot(element, scale: scale)
        }
    }

    private func hotspot(_ element: ControllerElement, scale: CGFloat) -> some View {
        let rect = PagesDiagramLayout.rect(for: element)
        let isHovered = hoveredElement == element
        return Button {
            editTarget = PagesEditTarget(element: element, fromList: false)
        } label: {
            RoundedRectangle(cornerRadius: 6 * scale, style: .continuous)
                .fill(isHovered ? VKPagesPalette.accentTint : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6 * scale, style: .continuous)
                        .strokeBorder(VKPagesPalette.accent.opacity(isHovered ? 0.9 : 0),
                                      lineWidth: 1.5)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: rect.width * scale, height: rect.height * scale)
        .position(x: rect.midX * scale, y: rect.midY * scale)
        .onHover { inside in
            withAnimation(VKPagesPalette.quick) {
                if inside {
                    hoveredElement = element
                } else if hoveredElement == element {
                    hoveredElement = nil
                }
            }
        }
        .popover(isPresented: popoverBinding(element, fromList: false), arrowEdge: .bottom) {
            MappingEditorView(element: element)
        }
        .help(element.displayName)
        .accessibilityLabel(Text(element.displayName))
    }

    private func popoverBinding(_ element: ControllerElement, fromList: Bool) -> Binding<Bool> {
        Binding(
            get: {
                editTarget == PagesEditTarget(element: element, fromList: fromList)
            },
            set: { newValue in
                if newValue {
                    editTarget = PagesEditTarget(element: element, fromList: fromList)
                } else if editTarget == PagesEditTarget(element: element, fromList: fromList) {
                    editTarget = nil
                }
            }
        )
    }

    // MARK: - Callout columns

    private func calloutColumn(_ elements: [ControllerElement], arrowEdge: Edge) -> some View {
        VStack(spacing: 5) {
            ForEach(elements) { element in
                calloutRow(element, arrowEdge: arrowEdge)
            }
        }
        .frame(width: 172)
    }

    private func calloutRow(_ element: ControllerElement, arrowEdge: Edge) -> some View {
        let isPressed = manager.snapshot.pressed.contains(element)
        let isHovered = hoveredElement == element
        return Button {
            editTarget = PagesEditTarget(element: element, fromList: true)
        } label: {
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isPressed ? VKPagesPalette.accent : VKPagesPalette.separator.opacity(0.6))
                    .frame(width: 3, height: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(PagesElementNames.short(for: element))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(VKPagesPalette.textPrimary)
                    Text(store.activeProfile.action(for: element).displayName)
                        .font(.system(size: 10))
                        .foregroundColor(VKPagesPalette.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? VKPagesPalette.accentTint : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isPressed
                                  ? VKPagesPalette.accent.opacity(0.8)
                                  : VKPagesPalette.separator.opacity(0.35),
                                  lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { inside in
            withAnimation(VKPagesPalette.quick) {
                if inside {
                    hoveredElement = element
                } else if hoveredElement == element {
                    hoveredElement = nil
                }
            }
        }
        .popover(isPresented: popoverBinding(element, fromList: true), arrowEdge: arrowEdge) {
            MappingEditorView(element: element)
        }
        .animation(VKPagesPalette.quick, value: isPressed)
    }

    // MARK: - Tuning cards

    private var tuningGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible())],
                  alignment: .leading, spacing: 16) {
            PagesSticksCard()
            PagesTriggersCard()
            PagesTouchpadCard()
            PagesGyroCard()
            PagesHapticsCard()
        }
    }
}
