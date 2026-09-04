//
//  Quota.swift
//  Helios
//
//  Created by Bernat on 04/09/2026.
//


// Quota.swift
// The Empire's mandatory demand: a manifest of named goods and amounts it
// expects to leave your docks by a deadline.
//
// NAMED GOODS, NOT BULK TONNAGE. A manifest forces retasking — your chains are
// tuned for what your colonists need, and the manifest asks for something else.
// A tonnage wouldn't. HELIOS.md §4.2.
//
// THE DEADLINE IS AN ABSOLUTE TICK COUNT, NEVER A DATE. tick() must stay pure
// and clock-free: it is what makes Phase 4's offline replay and Phase 9's
// server reconciliation possible, and the Phase 1.5 `tickIsDeterministic` test
// stands guard over it. Cadence is therefore expressed in *game-minutes*, which
// becomes real-world time for free when Phase 4 dials economyRate to 1/60.
// (HELIOS.md §4.8 calls the cadence "real-time" — that remains the intent; this
// is how it gets there without building it twice.)

import Foundation

struct Quota: Codable, Hashable, Identifiable {

    /// Monotonic and deterministic — minted by `GameState` on settlement in
    /// Step 4, never a UUID.
    let id: Int

    /// The manifest: how much of each named good the Empire expects. Sized per
    /// good from that good's own measured capacity, never as one bulk figure
    /// split evenly — Water (0.50/min) and Ration Bars (0.15/min) are thin, and
    /// a flat split would demand the impossible of them.
    let lines: [Resource.ID: Double]

    /// Game-minutes, not wall clock.
    let intervalMinutes: Double

    /// Absolute value of `GameState.tickCount` at which this quota settles.
    let dueAtTick: Int

    // MARK: - Reading the manifest

    var lineCount: Int { lines.count }
    var isEmpty: Bool { lines.isEmpty }

    /// How much of `good` is owed. Zero for a good this manifest doesn't name.
    func amount(of good: Resource.ID) -> Double {
        lines[good] ?? 0
    }

    /// The steady rate this line has to be delivered at to arrive on time.
    /// Step 3's delivery is paced by this; Step 5's cadence rule depends on it
    /// being interval-invariant.
    func demandPerGameMinute(of good: Resource.ID) -> Double {
        guard intervalMinutes > 0 else { return 0 }
        return amount(of: good) / intervalMinutes
    }

    /// Total demand per game-minute across the whole manifest.
    ///
    /// **This is the number Standing must never raise.** Falling Standing
    /// shortens the interval and shrinks each shipment proportionally, so this
    /// figure is the same at Receivership as at Patron. Raising it on failure
    /// would be self-reinforcing — structurally identical to a brownout
    /// throttling the plant that would end it. HELIOS.md §4.1.
    var totalDemandPerGameMinute: Double {
        guard intervalMinutes > 0 else { return 0 }
        return lines.values.reduce(0, +) / intervalMinutes
    }

    /// Manifest lines in resource-registry order, so the UI is stable across
    /// renders — a dictionary has no order of its own.
    var sortedLines: [(good: Resource.ID, amount: Double)] {
        Resource.all.compactMap { resource in
            guard let amount = lines[resource.id] else { return nil }
            return (good: resource.id, amount: amount)
        }
    }

    // MARK: - Sample (for previews and tests; convention is on the model)

    static let sample = Quota(
        id: 1,
        lines: [
            "power-cells": 1_260,
            "raw-ore":     1_200,
            "alloy-tools":   660,
            "oxygen":        540,
            "raw-ice":       480,
            "grain":         480,
            "water":         120,
            "ration-bars":    36
        ],
        intervalMinutes: 240,
        dueAtTick: 240
    )
}