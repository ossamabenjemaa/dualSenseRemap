import SwiftUI
import AppKit

/// Design tokens for the whole app — Logi Options+-inspired: quiet canvas,
/// white cards with hairline borders and soft shadows, one accent color used
/// exclusively for interaction/selection. All colors adapt to dark mode via
/// AppKit semantic colors.
enum DS {

    // MARK: - Color tokens

    /// "Pulse Blue" — the app accent. Interaction & selection only.
    static let accent = Color(red: 0.18, green: 0.44, blue: 0.95)
    /// Subtle accent wash for selected pills / hover fills.
    static let accentTint = accent.opacity(0.12)

    /// Window canvas behind cards.
    static let canvasBackground = Color(nsColor: .windowBackgroundColor)
    /// Card / popover surface (adaptive light-dark).
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    /// Inset areas (code boxes, capture fields).
    static let insetBackground = Color(nsColor: .underPageBackgroundColor)
    /// Hairline separators and card borders.
    static let separator = Color(nsColor: .separatorColor)

    static let textPrimary = Color(nsColor: .labelColor)
    static let textSecondary = Color(nsColor: .secondaryLabelColor)
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)

    static let success = Color(red: 0.18, green: 0.64, blue: 0.31)
    static let warning = Color(red: 0.82, green: 0.53, blue: 0.10)
    static let danger = Color(red: 0.84, green: 0.27, blue: 0.27)

    // MARK: - Spacing (4-pt grid)

    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 24

    // MARK: - Radii

    static let controlRadius: CGFloat = 8
    static let cardRadius: CGFloat = 12

    // MARK: - Typography (SF system stack)

    static let heroFont = Font.system(size: 28, weight: .semibold)
    static let titleFont = Font.system(size: 20, weight: .semibold)
    static let headingFont = Font.system(size: 15, weight: .semibold)
    static let bodyFont = Font.system(size: 13, weight: .regular)
    static let labelFont = Font.system(size: 12, weight: .medium)
    static let captionFont = Font.system(size: 11, weight: .regular)
    static let monoFont = Font.system(size: 12, weight: .regular, design: .monospaced)

    // MARK: - Motion

    /// Standard micro-animation for state changes (toggles, pills, dots).
    static let quickAnimation = Animation.easeInOut(duration: 0.15)
    /// Panel / step transitions.
    static let panelAnimation = Animation.easeInOut(duration: 0.3)

    // MARK: - App metadata

    /// Human-readable app version, e.g. "1.0 (42)". Falls back gracefully
    /// for bare SwiftPM binaries without an Info.plist.
    static var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        switch (short, build) {
        case let (short?, build?):
            return "\(short) (\(build))"
        case let (short?, nil):
            return short
        default:
            return "1.0 (dev)"
        }
    }
}

// MARK: - Card modifier

/// Standard content card: rounded 12-pt rectangle, adaptive surface, hairline
/// border, soft shadow. Apply with `.dsCard()`.
struct DSCardModifier: ViewModifier {
    var padding: CGFloat = DS.s5

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                    .fill(DS.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                    .strokeBorder(DS.separator.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

extension View {
    /// Wraps the view in the standard DualSense Remap card chrome.
    func dsCard(padding: CGFloat = DS.s5) -> some View {
        modifier(DSCardModifier(padding: padding))
    }
}

// MARK: - Section header

/// Card / page section header: semibold title + optional secondary subtitle.
struct DSSectionHeader: View {
    let title: String
    var subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.s1) {
            Text(title)
                .font(DS.headingFont)
                .foregroundColor(DS.textPrimary)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(DS.captionFont)
                    .foregroundColor(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Status pill

/// Colored status capsule: a dot + short label (e.g. "Connectée", "Requise").
struct StatusPill: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(DS.labelFont)
                .foregroundColor(DS.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, DS.s3)
        .padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.12)))
        .overlay(Capsule().strokeBorder(color.opacity(0.28), lineWidth: 1))
        .animation(DS.quickAnimation, value: label)
    }
}

// MARK: - Button styles

/// Filled accent button, Logi Options+-style rounded flat primary action.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.labelFont)
            .foregroundColor(.white)
            .padding(.horizontal, DS.s4)
            .padding(.vertical, DS.s2)
            .background(
                RoundedRectangle(cornerRadius: DS.controlRadius, style: .continuous)
                    .fill(DS.accent.opacity(configuration.isPressed ? 0.75 : 1.0))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DS.quickAnimation, value: configuration.isPressed)
    }
}

/// Quiet secondary button: subtle fill + hairline border.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.labelFont)
            .foregroundColor(DS.textPrimary)
            .padding(.horizontal, DS.s4)
            .padding(.vertical, DS.s2)
            .background(
                RoundedRectangle(cornerRadius: DS.controlRadius, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.12 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.controlRadius, style: .continuous)
                    .strokeBorder(DS.separator.opacity(0.6), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(DS.quickAnimation, value: configuration.isPressed)
    }
}
