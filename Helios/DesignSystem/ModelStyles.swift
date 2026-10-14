// ModelStyles.swift
// View-layer colour mappings for domain types. These live here rather than on
// the models themselves so the simulation stays free of SwiftUI and remains
// portable to a server. See HELIOS_ROADMAP.md §3.

import SwiftUI

extension ChainStatus {
    /// Text tint. Constrained states share the amber warning treatment.
    var tint: Color {
        switch self {
        case .running, .paused: return GameTheme.textSecondary
        case .limited, .stalled: return GameTheme.warn
        }
    }

    /// Status dot. Green only when genuinely unconstrained.
    var indicator: Color {
        switch self {
        case .running: return .green.opacity(0.8)
        case .paused: return GameTheme.textSecondary
        case .limited, .stalled: return GameTheme.warn
        }
    }
}

extension ShipStatus {
    var tint: Color {
        switch self {
        case .inTransit: return GameTheme.accent
        case .docked: return GameTheme.textSecondary
        case .idle: return GameTheme.warn
        }
    }
}

extension DangerLevel {
    var tint: Color {
        switch self {
        case .safe: return .green
        case .moderate: return .yellow
        case .hostile: return GameTheme.warn
        }
    }
}

extension WorldType {
    var baseColor: Color {
        switch self {
        case .oceanic: return Color(red: 0.25, green: 0.55, blue: 0.80)
        case .arid: return Color(red: 0.75, green: 0.55, blue: 0.35)
        case .ice: return Color(red: 0.70, green: 0.85, blue: 0.90)
        case .volcanic: return Color(red: 0.65, green: 0.30, blue: 0.25)
        case .gasGiant: return Color(red: 0.60, green: 0.50, blue: 0.75)
        }
    }

    var bandColor: Color {
        switch self {
        case .oceanic: return Color(red: 0.10, green: 0.30, blue: 0.45)
        case .arid: return Color(red: 0.40, green: 0.28, blue: 0.15)
        case .ice: return Color(red: 0.40, green: 0.55, blue: 0.60)
        case .volcanic: return Color(red: 0.30, green: 0.10, blue: 0.08)
        case .gasGiant: return Color(red: 0.30, green: 0.22, blue: 0.42)
        }
    }
}

extension ResearchCategory {
    /// SF Symbol for the category chip. View-layer, so it lives here rather
    /// than on the model (HELIOS.md §18 S9).
    var icon: String {
        switch self {
        case .production: return "cube.transparent.fill"
        case .fleet: return "paperplane.fill"
        case .defense: return "shield.lefthalf.filled"
        case .habitat: return "house.fill"
        }
    }
}
