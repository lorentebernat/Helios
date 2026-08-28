//
//  ColonistTier.swift
//  Helios
//
//  Created by Bernat on 12/08/2026.
//


// ColonistTier.swift
// The five-rung colonist ladder. Basic needs gate survival and growth;
// luxury needs gate promotion via happiness.
//
// TIERS 3–5 ARE PLACEHOLDERS — their needs will be designed alongside the
// fuller resource/chain network.

import Foundation

enum ColonistTier: String, CaseIterable, Hashable {
    case survivors
    case settlers
    case engineers
    case synthesists
    case ascendant

    var displayName: String {
        switch self {
        case .survivors: return "Survivors"
        case .settlers: return "Settlers"
        case .engineers: return "Engineers"
        case .synthesists: return "Synthesists"
        case .ascendant: return "Ascendant"
        }
    }

    var next: ColonistTier? {
        let all = Self.allCases
        guard let i = all.firstIndex(of: self), i + 1 < all.count else { return nil }
        return all[i + 1]
    }

    var basicNeeds: [PopulationNeed] {
        switch self {
        case .survivors:
            return [
                PopulationNeed(resourceID: "oxygen", per100PerMin: 2.0),
                PopulationNeed(resourceID: "ration-bars", per100PerMin: 1.2)
            ]
        case .settlers:
            return [
                PopulationNeed(resourceID: "oxygen", per100PerMin: 2.5),
                PopulationNeed(resourceID: "ration-bars", per100PerMin: 1.5),
                PopulationNeed(resourceID: "water", per100PerMin: 1.0)
            ]
        case .engineers, .synthesists, .ascendant:
            return []   // placeholder
        }
    }

    var luxuryNeeds: [PopulationNeed] {
        switch self {
        case .survivors:
            return []   // entry tier has no luxuries — always "happy"
        case .settlers:
            return [PopulationNeed(resourceID: "alloy-tools", per100PerMin: 0.5)]
        case .engineers, .synthesists, .ascendant:
            return []   // placeholder
        }
    }

    /// Ascendant provide no workforce (highest income instead).
    /// SCAFFOLD ONLY — workforce is not yet wired to chain staffing.
    var providesWorkforce: Bool { self != .ascendant }
}