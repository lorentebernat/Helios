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

    /// Called from `GameState.queueShip`, a UI action triggered by the
    /// player tapping "Build" — never from `tick()`. That's what makes this
    /// fine despite being unseeded randomness: HELIOS.md §14's "no randomness
    /// inside tick()" hedge is about the pure simulation step being replayable
    /// and reconcilable, and a name picked once at order time doesn't affect
    /// that — it's baked into the ShipBuildOrder before tick() ever touches it.
    static func random() -> String {
        "\(first.randomElement() ?? "Pale") \(second.randomElement() ?? "Comet")"
    }
}
