import Foundation
import SwiftUI

/// Fixed geometry of the keyboard panel (base size, pre-scale).
enum VKMetrics {
    static let baseWidth: CGFloat = 820
    static let baseHeight: CGFloat = 320
    static let panelCornerRadius: CGFloat = 16
    static let keyCornerRadius: CGFloat = 8
    static let gap: CGFloat = 6
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 14
    /// Every row sums to 11 width units (the letter rows have 11 columns).
    static let unitsPerRow: Double = 11

    static var unitWidth: CGFloat {
        (baseWidth - horizontalPadding * 2 - gap * 10) / CGFloat(unitsPerRow)
    }

    static var rowHeight: CGFloat {
        (baseHeight - verticalPadding * 2 - gap * 5) / 6
    }

    /// Width of a key spanning `units` grid units (absorbing interior gaps).
    static func keyWidth(_ units: Double) -> CGFloat {
        CGFloat(units) * unitWidth + CGFloat(units - 1) * gap
    }
}

/// Palette matching the PS5 system keyboard's near-black look.
enum VKColor {
    static let panel = Color(red: 27 / 255, green: 29 / 255, blue: 34 / 255)   // #1B1D22
    static let label = Color.white.opacity(0.9)
    static let labelDim = Color.white.opacity(0.55)
    static let selectorFill = Color(red: 58 / 255, green: 58 / 255, blue: 60 / 255) // #3A3A3C
    static let badgeFill = Color(red: 58 / 255, green: 58 / 255, blue: 60 / 255)
    static let badgeText = Color.white.opacity(0.6)
    static let doneRestFill = Color.white.opacity(0.08)
}

/// Faithful PS5-style keyboard surface. Purely declarative: all interaction
/// state lives in `VKModel`; mouse clicks reuse the controller activate path.
struct VKKeyboardView: View {
    @ObservedObject var model: VKModel

    var body: some View {
        let grid = model.grid
        VStack(spacing: VKMetrics.gap) {
            ForEach(0..<grid.count, id: \.self) { rowIndex in
                HStack(spacing: VKMetrics.gap) {
                    ForEach(Array(grid[rowIndex].enumerated()), id: \.element.id) { item in
                        VKKeyView(
                            key: item.element,
                            position: VKPosition(row: rowIndex, col: item.offset),
                            model: model
                        )
                    }
                }
            }
        }
        .padding(.horizontal, VKMetrics.horizontalPadding)
        .padding(.vertical, VKMetrics.verticalPadding)
        .frame(width: VKMetrics.baseWidth, height: VKMetrics.baseHeight)
        .background(panelBackground)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: VKMetrics.panelCornerRadius, style: .continuous)
            .fill(VKColor.panel)
            .overlay(
                // Subtle 1 px hairline, brightest along the top edge.
                RoundedRectangle(cornerRadius: VKMetrics.panelCornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.16), Color.white.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
    }
}

/// One key cell: flat label at rest, white rounded-rect when focused,
/// brief flash + scale dip when pressed.
struct VKKeyView: View {
    let key: VKKey
    let position: VKPosition
    @ObservedObject var model: VKModel

    private var isFocused: Bool { model.focus == position }
    private var isPressed: Bool { model.pressedKeyID == key.id }
    private var isLit: Bool { isFocused || isPressed }

    /// Layer selectors (and ⇧) keep a persistent filled background while
    /// their layer / shift state is active — the PS5's layer indication.
    private var isSelectorActive: Bool {
        switch key.special {
        case .layerABC: return model.pageID == .letters
        case .layerSymbols: return model.pageID == .symbols1 || model.pageID == .symbols2
        case .layerAccents: return model.pageID == .accents
        case .shift: return model.shift.isActive
        default: return false
        }
    }

    var body: some View {
        ZStack {
            background
            content
        }
        .frame(width: VKMetrics.keyWidth(key.widthUnits), height: VKMetrics.rowHeight)
        .scaleEffect(isPressed ? 0.94 : (isFocused ? 1.06 : 1.0))
        .animation(.easeOut(duration: 0.12), value: isFocused)
        .animation(.easeOut(duration: 0.06), value: isPressed)
        .contentShape(Rectangle())
        .onTapGesture {
            model.mouseActivate(at: position)
        }
    }

    // MARK: Background

    @ViewBuilder
    private var background: some View {
        if isLit {
            keyShape
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.35), radius: 4, x: 0, y: 2)
        } else if isSelectorActive {
            keyShape.fill(VKColor.selectorFill)
        } else if key.special == .done {
            keyShape.fill(VKColor.doneRestFill)
        }
    }

    /// The Done key renders as a wider pill; every other key is a rounded rect.
    private var keyShape: RoundedRectangle {
        let radius = key.special == .done
            ? VKMetrics.rowHeight / 2
            : VKMetrics.keyCornerRadius
        return RoundedRectangle(cornerRadius: radius, style: .continuous)
    }

    // MARK: Content

    private var content: some View {
        HStack(spacing: 6) {
            if key.special == .controllerHint {
                Image(systemName: "gamecontroller")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(foregroundColor)
            } else {
                let label = key.display(shift: model.shift)
                if !label.isEmpty {
                    Text(label)
                        .font(labelFont)
                        .foregroundColor(foregroundColor)
                        .overlay(alignment: .bottom) { capsLockUnderline }
                }
            }
            if let badge = key.controllerBadge {
                VKBadgeChip(token: badge, onLitKey: isLit)
            }
        }
    }

    /// Small bar under ⇧ while caps lock is engaged.
    @ViewBuilder
    private var capsLockUnderline: some View {
        if key.special == .shift, model.shift == .caps {
            RoundedRectangle(cornerRadius: 1)
                .fill(foregroundColor)
                .frame(width: 12, height: 2)
                .offset(y: 3)
        }
    }

    private var labelFont: Font {
        switch key.kind {
        case .character, .symbol:
            return .system(size: 20, weight: .regular)
        case .special(let special):
            switch special {
            case .layerABC, .layerSymbols, .layerAccents, .done:
                return .system(size: 15, weight: .medium)
            case .shift, .backspace, .enter:
                return .system(size: 17, weight: .regular)
            case .cursorLeft, .cursorRight:
                return .system(size: 13, weight: .regular)
            case .options:
                return .system(size: 15, weight: .bold)
            case .space, .controllerHint:
                return .system(size: 15, weight: .regular)
            }
        }
    }

    private var foregroundColor: Color {
        isLit ? Color.black : VKColor.label
    }
}

/// Small gray chip showing the controller shortcut of a function key,
/// exactly like the PS5 bottom bars. Tokens "triangle" / "square" render as
/// SF Symbols; every other token ("L1", "R2", "L3+R3"…) renders as text.
struct VKBadgeChip: View {
    let token: String
    var onLitKey: Bool = false

    var body: some View {
        glyph
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(onLitKey ? Color.black.opacity(0.12) : VKColor.badgeFill)
            )
    }

    @ViewBuilder
    private var glyph: some View {
        switch token {
        case "triangle":
            Image(systemName: "triangle")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(textColor)
        case "square":
            Image(systemName: "square")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(textColor)
        default:
            Text(token)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(textColor)
        }
    }

    private var textColor: Color {
        onLitKey ? Color.black.opacity(0.6) : VKColor.badgeText
    }
}
