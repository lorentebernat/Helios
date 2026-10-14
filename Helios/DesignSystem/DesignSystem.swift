// DesignSystem.swift
// Central design tokens + glass panel modifier for the game's UI.
// Replaces the inline GameTheme/GlassPanel that lived in MainColonyView.swift.

import SwiftUI

// MARK: - Design Tokens

enum GameTheme {

    // MARK: Colors

    static let voidTop = Color(red: 0.04, green: 0.05, blue: 0.10)
    static let voidBottom = Color(red: 0.01, green: 0.02, blue: 0.05)
    static let accent = Color(red: 0.30, green: 0.85, blue: 0.95)      // cyan
    static let accentDim = Color(red: 0.30, green: 0.85, blue: 0.95).opacity(0.35)
    static let warn = Color(red: 0.95, green: 0.55, blue: 0.25)        // amber, alerts only
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let track = Color.white.opacity(0.08)                        // empty part of a progress bar
    static let energy = Color.yellow                                    // grid / power readouts
    static let credit = Color.green                                     // credits readout

    // MARK: Spacing

    enum Spacing {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 18
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }

    // MARK: Corner Radius
    // Named by the component role that uses it, not by size — so intent stays
    // clear even if the underlying number changes later.

    enum Radius {
        static let chip: CGFloat = 16          // CategoryChip
        static let pill: CGFloat = 14          // ResourcePill
        static let row: CGFloat = 18           // ProductionChainRow
        static let panel: CGFloat = 24         // standard glass panels
        static let hero: CGFloat = 26          // ColonyTierCard
        static let tabBar: CGFloat = 28        // GlassTabBar
        static let circleButton: CGFloat = 20  // CircleGlassButton
        static let iconBadge: CGFloat = 14     // fixed icon badges (chain rows, list icons)
    }

    // MARK: Sizes
    // Fixed dimensions that recur across components — not spacing, not radius,
    // but a concrete width/height a component always uses.

    enum Size {
        static let iconBadge: CGFloat = 46     // ProductionChainRow icon badge, reusable for Fleet/Research icons
        static let progressBar: CGFloat = 5    // capsule progress bars in rows and cards
        static let heroProgressBar: CGFloat = 6 // QuotaPanel's bar
    }

    // MARK: Glass Stroke Opacity
    // Three intentional levels — not every panel should look identical.
    // .subtle:   small/secondary elements (pills, rows) — quieter border
    // .standard: default panels (chips, buttons)
    // .prominent: hero/emphasis elements (tier card, tab bar) — stronger border
    // If you find yourself reaching for a raw number instead of one of these
    // three, that's a signal to reconsider the hierarchy rather than add a fourth.

    enum GlassStroke {
        static let subtle: Double = 0.14
        static let standard: Double = 0.18
        static let prominent: Double = 0.20
    }

    // MARK: Typography
    // Named by role, not by size/weight — so usage stays readable at the call site.

    enum Font {
        static let label = SwiftUI.Font.system(size: 11, weight: .semibold)          // eyebrow/category labels, tracked
        static let caption = SwiftUI.Font.system(size: 12, weight: .regular)         // status notes, secondary text
        static let body = SwiftUI.Font.system(size: 13, weight: .semibold, design: .rounded) // pill values, chain rates
        static let chipLabel = SwiftUI.Font.system(size: 11, weight: .medium)        // CategoryChip text
        static let rowTitle = SwiftUI.Font.system(size: 15, weight: .semibold)       // ProductionChainRow name
        static let sectionTitle = SwiftUI.Font.system(size: 17, weight: .bold, design: .rounded) // "Production Chains"
        static let heroValue = SwiftUI.Font.system(size: 22, weight: .bold, design: .rounded)    // resource/pop counts
        static let heroTitle = SwiftUI.Font.system(size: 24, weight: .bold, design: .rounded)    // tier name
        static let tabLabel = SwiftUI.Font.system(size: 10, weight: .medium)                    // GlassTabBar labels — smallest text in the UI
        static let footnote = SwiftUI.Font.system(size: 10, weight: .regular)                   // fine print under a row or card
        static let button = SwiftUI.Font.system(size: 13, weight: .semibold)                    // glass pill buttons
    }
}

// MARK: - Glass Panel Modifier

struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = GameTheme.Radius.panel
    var strokeOpacity: Double = GameTheme.GlassStroke.standard

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(strokeOpacity), .white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

extension View {
    func glass(
        cornerRadius: CGFloat = GameTheme.Radius.panel,
        strokeOpacity: Double = GameTheme.GlassStroke.standard
    ) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius, strokeOpacity: strokeOpacity))
    }
}
