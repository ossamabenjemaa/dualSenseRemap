import Foundation
import SwiftUI
import AppKit

// MARK: - Diagram layout
//
// All geometry is expressed in a base 460 × 300 pt canvas; the diagram and
// the hotspot layer multiply by the same scale factor so hotspots always
// track the drawn shapes.
enum PagesDiagramLayout {
    static let baseSize = CGSize(width: 460, height: 300)

    // Cluster centers.
    static let dpadCenter = CGPoint(x: 105, y: 124)
    static let faceCenter = CGPoint(x: 355, y: 124)
    static let faceOffset: CGFloat = 29
    static let leftStickCenter = CGPoint(x: 172, y: 186)
    static let rightStickCenter = CGPoint(x: 288, y: 186)
    static let stickRadius: CGFloat = 27
    static let stickKnobRadius: CGFloat = 17
    /// Max knob visual deflection at full stick tilt (base-space points).
    static let stickTravel: CGFloat = 9

    static let touchpadRect = CGRect(x: 156, y: 46, width: 148, height: 80)
    static let psCenter = CGPoint(x: 230, y: 216)
    static let muteCenter = CGPoint(x: 230, y: 240)

    /// Hotspot rectangle for every digital element shown on the diagram.
    static func rect(for element: ControllerElement) -> CGRect {
        switch element {
        case .triangle: return centered(faceCenter.x, faceCenter.y - faceOffset, 30, 30)
        case .cross: return centered(faceCenter.x, faceCenter.y + faceOffset, 30, 30)
        case .square: return centered(faceCenter.x - faceOffset, faceCenter.y, 30, 30)
        case .circle: return centered(faceCenter.x + faceOffset, faceCenter.y, 30, 30)
        case .dpadUp: return centered(dpadCenter.x, dpadCenter.y - 23, 24, 24)
        case .dpadDown: return centered(dpadCenter.x, dpadCenter.y + 23, 24, 24)
        case .dpadLeft: return centered(dpadCenter.x - 23, dpadCenter.y, 24, 24)
        case .dpadRight: return centered(dpadCenter.x + 23, dpadCenter.y, 24, 24)
        case .l1: return centered(105, 31, 60, 12)
        case .r1: return centered(355, 31, 60, 12)
        case .l2: return centered(105, 15, 46, 18)
        case .r2: return centered(355, 15, 46, 18)
        case .l3: return centered(leftStickCenter.x, leftStickCenter.y, 56, 56)
        case .r3: return centered(rightStickCenter.x, rightStickCenter.y, 56, 56)
        case .create: return centered(136, 66, 18, 30)
        case .options: return centered(324, 66, 18, 30)
        case .ps: return centered(psCenter.x, psCenter.y, 28, 22)
        case .mute: return centered(muteCenter.x, muteCenter.y, 30, 12)
        case .touchpadClick: return touchpadRect
        default: return .zero
        }
    }

    /// Elements that get an interactive hotspot on the diagram.
    static let hotspotElements: [ControllerElement] = [
        .l2, .r2, .l1, .r1,
        .create, .options,
        .dpadUp, .dpadDown, .dpadLeft, .dpadRight,
        .triangle, .circle, .cross, .square,
        .l3, .r3, .ps, .mute,
        .touchpadClick,
    ]

    private static func centered(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h)
    }
}

// MARK: - Body silhouette

/// Stylized top-view DualSense silhouette (two grips + central bridge),
/// drawn with cubic curves in the normalized 460 × 300 space.
struct PagesControllerBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / PagesDiagramLayout.baseSize.width
        let sy = rect.height / PagesDiagramLayout.baseSize.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }

        var path = Path()
        path.move(to: p(80, 40))
        // Top edge, slight rise at center.
        path.addCurve(to: p(380, 40), control1: p(180, 28), control2: p(280, 28))
        // Right shoulder flare.
        path.addCurve(to: p(408, 95), control1: p(398, 46), control2: p(406, 66))
        // Right grip, outer edge.
        path.addCurve(to: p(388, 260), control1: p(414, 140), control2: p(404, 214))
        // Right grip, rounded bottom.
        path.addCurve(to: p(330, 268), control1: p(380, 280), control2: p(352, 280))
        // Right grip, inner edge back up to the body.
        path.addCurve(to: p(298, 195), control1: p(312, 250), control2: p(300, 218))
        // Bottom center dip between the grips.
        path.addCurve(to: p(162, 195), control1: p(265, 246), control2: p(195, 246))
        // Left grip, inner edge.
        path.addCurve(to: p(130, 268), control1: p(160, 218), control2: p(148, 250))
        // Left grip, rounded bottom.
        path.addCurve(to: p(72, 260), control1: p(108, 280), control2: p(80, 280))
        // Left grip, outer edge.
        path.addCurve(to: p(52, 95), control1: p(56, 214), control2: p(46, 140))
        // Left shoulder flare, back to start.
        path.addCurve(to: p(80, 40), control1: p(54, 66), control2: p(62, 46))
        path.closeSubpath()
        return path
    }
}

// MARK: - Diagram

/// Schematic top-view DualSense drawn with SwiftUI shapes. Purely visual —
/// the interactive hotspots are overlaid by `ControllerPageView` using the
/// same `PagesDiagramLayout` geometry. Elements pressed on the real
/// controller glow with the accent color; the sticks deflect and the
/// triggers fill with the live analog values.
struct ControllerDiagram: View {
    let snapshot: ControllerSnapshot
    let lightbarColor: Color
    /// Uniform scale from the 460 × 300 base space to on-screen points.
    let scale: CGFloat

    private var s: CGFloat { scale }

    private func pressed(_ element: ControllerElement) -> Bool {
        snapshot.pressed.contains(element)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            shoulderTabs
            bodyPlate
            touchpadPlate
            lightbarHints
            systemPills
            dpadCluster
            faceCluster
            stick(center: PagesDiagramLayout.leftStickCenter,
                  value: snapshot.leftStick,
                  clickElement: .l3)
            stick(center: PagesDiagramLayout.rightStickCenter,
                  value: snapshot.rightStick,
                  clickElement: .r3)
            psAndMute
        }
        .frame(width: PagesDiagramLayout.baseSize.width * s,
               height: PagesDiagramLayout.baseSize.height * s)
        .animation(VKPagesPalette.quick, value: snapshot.pressed)
    }

    // MARK: Body

    private var bodyPlate: some View {
        PagesControllerBodyShape()
            .fill(
                LinearGradient(
                    colors: [
                        VKPagesPalette.cardBackground,
                        VKPagesPalette.insetBackground,
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(
                PagesControllerBodyShape()
                    .stroke(VKPagesPalette.separator.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 8 * s, x: 0, y: 3 * s)
    }

    // MARK: Shoulders / triggers

    private var shoulderTabs: some View {
        Group {
            triggerTab(element: .l2, value: snapshot.leftTrigger)
            triggerTab(element: .r2, value: snapshot.rightTrigger)
            bumperTab(element: .l1)
            bumperTab(element: .r1)
        }
    }

    private func triggerTab(element: ControllerElement, value: Double) -> some View {
        let r = PagesDiagramLayout.rect(for: element)
        let fill = CGFloat(max(0, min(1, value)))
        return ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 5 * s, style: .continuous)
                .fill(VKPagesPalette.insetBackground)
            // Analog fill rises with the physical pull.
            RoundedRectangle(cornerRadius: 5 * s, style: .continuous)
                .fill(VKPagesPalette.accent.opacity(0.85))
                .frame(height: max(0, r.height * s * fill))
        }
        .clipShape(RoundedRectangle(cornerRadius: 5 * s, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5 * s, style: .continuous)
                .strokeBorder(pressed(element)
                              ? VKPagesPalette.accent
                              : VKPagesPalette.separator.opacity(0.8),
                              lineWidth: 1)
        )
        .frame(width: r.width * s, height: r.height * s)
        .position(x: r.midX * s, y: r.midY * s)
        .shadow(color: pressed(element) ? VKPagesPalette.accentGlow : .clear,
                radius: 5 * s)
    }

    private func bumperTab(element: ControllerElement) -> some View {
        let r = PagesDiagramLayout.rect(for: element)
        return RoundedRectangle(cornerRadius: 4 * s, style: .continuous)
            .fill(pressed(element) ? VKPagesPalette.accent : VKPagesPalette.insetBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 4 * s, style: .continuous)
                    .strokeBorder(VKPagesPalette.separator.opacity(0.8), lineWidth: 1)
            )
            .frame(width: r.width * s, height: r.height * s)
            .position(x: r.midX * s, y: r.midY * s)
            .shadow(color: pressed(element) ? VKPagesPalette.accentGlow : .clear,
                    radius: 5 * s)
    }

    // MARK: Touchpad & lightbar

    private var touchpadPlate: some View {
        let r = PagesDiagramLayout.touchpadRect
        let isPressed = pressed(.touchpadClick)
        return ZStack {
            RoundedRectangle(cornerRadius: 14 * s, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            VKPagesPalette.insetBackground,
                            VKPagesPalette.cardBackground,
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            if isPressed {
                RoundedRectangle(cornerRadius: 14 * s, style: .continuous)
                    .fill(VKPagesPalette.accentTint)
            }
            // Live finger dots.
            touchDot(snapshot.primaryTouch, in: r)
            touchDot(snapshot.secondaryTouch, in: r)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14 * s, style: .continuous)
                .strokeBorder(isPressed
                              ? VKPagesPalette.accent
                              : VKPagesPalette.separator.opacity(0.8),
                              lineWidth: 1)
        )
        .frame(width: r.width * s, height: r.height * s)
        .position(x: r.midX * s, y: r.midY * s)
        .shadow(color: isPressed ? VKPagesPalette.accentGlow : .clear, radius: 6 * s)
    }

    @ViewBuilder
    private func touchDot(_ touch: TouchpadTouch, in padRect: CGRect) -> some View {
        if touch.isTouching {
            // Touch coordinates are normalized [-1, 1], origin at pad center,
            // +y toward the top edge.
            let dx = CGFloat(touch.x) * (padRect.width / 2 - 6)
            let dy = -CGFloat(touch.y) * (padRect.height / 2 - 6)
            Circle()
                .fill(VKPagesPalette.accent.opacity(touch.id == 0 ? 0.9 : 0.55))
                .frame(width: 9 * s, height: 9 * s)
                .offset(x: dx * s, y: dy * s)
        }
    }

    private var lightbarHints: some View {
        let r = PagesDiagramLayout.touchpadRect
        return Group {
            Capsule()
                .fill(lightbarColor.opacity(0.9))
                .frame(width: 5 * s, height: (r.height - 10) * s)
                .position(x: (r.minX - 6) * s, y: r.midY * s)
            Capsule()
                .fill(lightbarColor.opacity(0.9))
                .frame(width: 5 * s, height: (r.height - 10) * s)
                .position(x: (r.maxX + 6) * s, y: r.midY * s)
        }
        .shadow(color: lightbarColor.opacity(0.55), radius: 4 * s)
    }

    // MARK: Create / Options pills

    private var systemPills: some View {
        Group {
            systemPill(element: .create)
            systemPill(element: .options)
        }
    }

    private func systemPill(element: ControllerElement) -> some View {
        let r = PagesDiagramLayout.rect(for: element)
        return Capsule()
            .fill(pressed(element) ? VKPagesPalette.accent : VKPagesPalette.insetBackground)
            .overlay(Capsule().strokeBorder(VKPagesPalette.separator.opacity(0.8), lineWidth: 1))
            .frame(width: 8 * s, height: 24 * s)
            .position(x: r.midX * s, y: r.midY * s)
            .shadow(color: pressed(element) ? VKPagesPalette.accentGlow : .clear, radius: 4 * s)
    }

    // MARK: D-pad

    private var dpadCluster: some View {
        let c = PagesDiagramLayout.dpadCenter
        return ZStack {
            // Cross base: two rounded bars.
            RoundedRectangle(cornerRadius: 6 * s, style: .continuous)
                .fill(VKPagesPalette.insetBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 6 * s, style: .continuous)
                        .strokeBorder(VKPagesPalette.separator.opacity(0.8), lineWidth: 1)
                )
                .frame(width: 62 * s, height: 21 * s)
            RoundedRectangle(cornerRadius: 6 * s, style: .continuous)
                .fill(VKPagesPalette.insetBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 6 * s, style: .continuous)
                        .strokeBorder(VKPagesPalette.separator.opacity(0.8), lineWidth: 1)
                )
                .frame(width: 21 * s, height: 62 * s)
            // Pressed arms glow.
            dpadArm(.dpadUp)
            dpadArm(.dpadDown)
            dpadArm(.dpadLeft)
            dpadArm(.dpadRight)
        }
        .position(x: c.x * s, y: c.y * s)
    }

    @ViewBuilder
    private func dpadArm(_ element: ControllerElement) -> some View {
        if pressed(element) {
            let r = PagesDiagramLayout.rect(for: element)
            let c = PagesDiagramLayout.dpadCenter
            RoundedRectangle(cornerRadius: 5 * s, style: .continuous)
                .fill(VKPagesPalette.accent)
                .frame(width: (r.width - 6) * s, height: (r.height - 6) * s)
                .offset(x: (r.midX - c.x) * s, y: (r.midY - c.y) * s)
                .shadow(color: VKPagesPalette.accentGlow, radius: 5 * s)
        }
    }

    // MARK: Face buttons

    private var faceCluster: some View {
        Group {
            faceButton(.triangle, glyph: "△")
            faceButton(.circle, glyph: "○")
            faceButton(.cross, glyph: "✕")
            faceButton(.square, glyph: "□")
        }
    }

    private func faceButton(_ element: ControllerElement, glyph: String) -> some View {
        let r = PagesDiagramLayout.rect(for: element)
        let isPressed = pressed(element)
        return Circle()
            .fill(isPressed ? VKPagesPalette.accent : VKPagesPalette.insetBackground)
            .overlay(
                Circle().strokeBorder(isPressed
                                      ? VKPagesPalette.accent
                                      : VKPagesPalette.separator.opacity(0.9),
                                      lineWidth: 1)
            )
            .overlay(
                Text(glyph)
                    .font(.system(size: 12 * s, weight: .semibold))
                    .foregroundColor(isPressed ? .white : VKPagesPalette.textSecondary)
            )
            .frame(width: 27 * s, height: 27 * s)
            .position(x: r.midX * s, y: r.midY * s)
            .shadow(color: isPressed ? VKPagesPalette.accentGlow : .clear, radius: 6 * s)
    }

    // MARK: Sticks

    private func stick(center: CGPoint, value: CGPoint, clickElement: ControllerElement) -> some View {
        let isPressed = pressed(clickElement)
        // GameController convention: +y is up; SwiftUI +y is down.
        let dx = value.x * PagesDiagramLayout.stickTravel
        let dy = -value.y * PagesDiagramLayout.stickTravel
        return ZStack {
            Circle()
                .fill(VKPagesPalette.insetBackground.opacity(0.6))
                .overlay(Circle().strokeBorder(VKPagesPalette.separator.opacity(0.9), lineWidth: 1))
                .frame(width: PagesDiagramLayout.stickRadius * 2 * s,
                       height: PagesDiagramLayout.stickRadius * 2 * s)
            Circle()
                .fill(
                    isPressed
                    ? AnyShapeStyle(VKPagesPalette.accent)
                    : AnyShapeStyle(
                        LinearGradient(
                            colors: [
                                VKPagesPalette.cardBackground,
                                VKPagesPalette.insetBackground,
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                )
                .overlay(Circle().strokeBorder(VKPagesPalette.separator, lineWidth: 1))
                .frame(width: PagesDiagramLayout.stickKnobRadius * 2 * s,
                       height: PagesDiagramLayout.stickKnobRadius * 2 * s)
                .offset(x: dx * s, y: dy * s)
                .shadow(color: isPressed ? VKPagesPalette.accentGlow : Color.black.opacity(0.15),
                        radius: 3 * s, x: 0, y: 1 * s)
        }
        .position(x: center.x * s, y: center.y * s)
    }

    // MARK: PS button & mute bar

    private var psAndMute: some View {
        Group {
            psButton
            muteBar
        }
    }

    private var psButton: some View {
        let r = PagesDiagramLayout.rect(for: .ps)
        let isPressed = pressed(.ps)
        return RoundedRectangle(cornerRadius: 7 * s, style: .continuous)
            .fill(isPressed ? VKPagesPalette.accent : VKPagesPalette.insetBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 7 * s, style: .continuous)
                    .strokeBorder(VKPagesPalette.separator.opacity(0.9), lineWidth: 1)
            )
            .overlay(
                Text("PS")
                    .font(.system(size: 8 * s, weight: .bold))
                    .foregroundColor(isPressed ? .white : VKPagesPalette.textSecondary)
            )
            .frame(width: r.width * s, height: r.height * s)
            .position(x: r.midX * s, y: r.midY * s)
            .shadow(color: isPressed ? VKPagesPalette.accentGlow : .clear, radius: 5 * s)
    }

    private var muteBar: some View {
        let r = PagesDiagramLayout.rect(for: .mute)
        let isPressed = pressed(.mute)
        return Capsule()
            .fill(isPressed ? VKPagesPalette.warning : VKPagesPalette.insetBackground)
            .overlay(Capsule().strokeBorder(VKPagesPalette.separator.opacity(0.9), lineWidth: 1))
            .frame(width: 24 * s, height: 7 * s)
            .position(x: r.midX * s, y: r.midY * s)
            .shadow(color: isPressed ? VKPagesPalette.warning.opacity(0.5) : .clear, radius: 4 * s)
    }
}
