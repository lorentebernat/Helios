//
//  ShipBuildOrder.swift
//  Helios
//
//  Created by Bernat on 11/08/2026.
//


// ShipBuildOrder.swift
// A ship under construction in the shipyard queue. Becomes a real Ship on
// completion.
//
// Codable (Phase 1.5 Step 5): synthesised. This is player-created mutable
// state with no registry counterpart, so it's saved in full — including
// `id`, which stays a UUID (unlike Ship.id/ShipID, nothing here needs to be
// deterministic; a build order never appears inside `tick()`'s pure step,
// only the queue it sits in does).

import Foundation

struct ShipBuildOrder: Identifiable, Hashable, Codable {
    let id = UUID()
    var name: String
    let role: ShipRole
    var remainingMinutes: Double
    let totalMinutes: Double

    var isComplete: Bool { remainingMinutes <= 0 }

    var progress: Double {
        guard totalMinutes > 0 else { return 1 }
        return min(1, max(0, (totalMinutes - remainingMinutes) / totalMinutes))
    }

    mutating func applyTick(minutesPerTick: Double) {
        remainingMinutes = max(0, remainingMinutes - minutesPerTick)
    }
}
