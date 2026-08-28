// Destination.swift
// Authored world reference data. Static by design — nothing mutates these.
// IDs are hand-written slugs so seed data can reference them and so references
// survive save/load.
//
// NO SwiftUI HERE — colour mappings live in DesignSystem/ModelStyles.swift so
// this stays portable to a server. See HELIOS_ROADMAP.md §3.

import Foundation

enum WorldType: String, CaseIterable {
    case oceanic = "Oceanic"
    case arid = "Arid"
    case ice = "Ice"
    case volcanic = "Volcanic"
    case gasGiant = "Gas Giant"
}

enum DangerLevel: String {
    case safe = "Safe"
    case moderate = "Moderate"
    case hostile = "Hostile"
}

struct Destination: Identifiable, Hashable {
    let id: String                 // slug, e.g. "kepler-7"
    let name: String
    let worldType: WorldType
    let coordinate: GalaxyCoordinate
    let travelTimeMinutes: Int     // authored for now; Phase 2 derives from coordinate
    let colonistTier: String?
    let danger: DangerLevel

    static let samples: [Destination] = [
        .init(id: "kepler-7", name: "Kepler Outpost-7", worldType: .arid,
              coordinate: GalaxyCoordinate(galaxy: 1, system: 42, position: 5),
              travelTimeMinutes: 0, colonistTier: "Survivors", danger: .safe),
        .init(id: "vesta", name: "Vesta Station", worldType: .gasGiant,
              coordinate: GalaxyCoordinate(galaxy: 1, system: 42, position: 9),
              travelTimeMinutes: 12, colonistTier: "Survivors", danger: .safe),
        .init(id: "sector-12", name: "Unmapped Sector 12", worldType: .ice,
              coordinate: GalaxyCoordinate(galaxy: 1, system: 47, position: 3),
              travelTimeMinutes: 34, colonistTier: nil, danger: .moderate),
        .init(id: "triton", name: "Triton Reach", worldType: .oceanic,
              coordinate: GalaxyCoordinate(galaxy: 1, system: 58, position: 11),
              travelTimeMinutes: 58, colonistTier: "Settlers", danger: .moderate),
        .init(id: "anomaly", name: "Deep Space Anomaly", worldType: .volcanic,
              coordinate: GalaxyCoordinate(galaxy: 1, system: 120, position: 1),
              travelTimeMinutes: 210, colonistTier: nil, danger: .hostile)
    ]

    static func byID(_ id: Destination.ID) -> Destination? {
        samples.first { $0.id == id }
    }

    /// Resolves a destination id to its display name. Returns nil for a nil id.
    static func displayName(_ id: Destination.ID?) -> String? {
        guard let id else { return nil }
        return byID(id)?.name
    }
}
