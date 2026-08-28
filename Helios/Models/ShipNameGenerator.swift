//
//  ShipNameGenerator.swift
//  Helios
//
//  Created by Bernat on 11/08/2026.
//


// ShipNameGenerator.swift
// Two-word evocative names matching the seed fleet's aesthetic
// ("Pale Comet", "Dust Runner", "Long Horizon").

import Foundation

enum ShipNameGenerator {
    private static let first = [
        "Pale", "Dust", "Long", "Meridian", "Iron", "Silent", "Amber",
        "Hollow", "Vagrant", "Cinder", "Distant", "Quiet", "Vesper",
        "Salt", "Grey", "Bright", "Slow", "Far"
    ]

    private static let second = [
        "Comet", "Runner", "Horizon", "Hauler", "Watch", "Drift", "Wake",
        "Voyager", "Lantern", "Ember", "Wanderer", "Compass", "Reach",
        "Signal", "Passage", "Tide", "Harbour", "Bearing"
    ]

    static func random() -> String {
        "\(first.randomElement() ?? "Pale") \(second.randomElement() ?? "Comet")"
    }
}