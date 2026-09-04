// QuotaGenerator.swift
// How one manifest is sized. Pure, deterministic, no clock, no randomness:
// the same colony at the same tick always produces the same manifest.
//
// Three settled decisions live here, from HELIOS.md §4.2 "Sizing":
//
//   1. PER GOOD, AT ITS OWN RATE. amount = capacity[good] × interval × load.
//      Never one bulk tonnage split evenly — Water and Ration Bars are thin
//      (0.50 and 0.15 per game-minute) and a flat split would demand the
//      impossible of them while barely troubling Power Cells.
//
//   2. BREADTH BEATS SIZE. A manifest naming one good unsticks one chain and
//      leaves every other store saturated — S1 with extra steps. So every
//      eligible good is named, which for the seed network is eight of nine and
//      comfortably clears the five-line floor below.
//
//   3. NEVER NAME A GOOD THE COLONY STRUCTURALLY CANNOT SPARE. Refined Alloy
//      measures 0.00/game-minute — the Smelter supplies 7/min and the Tool Fab
//      plus Cell Factory demand 8 — so asking for it is asking for nothing.
//
// It reads capacity from `CapacityProbe`, which measures INSTALLED capacity
// with every chain forced to full output. Throttling a chain therefore changes
// what you deliver this cycle and never what is asked of you next cycle.
// HELIOS.md §4.1.

import Foundation

struct QuotaGenerator {

    /// Base cadence in game-minutes. Step 5 multiplies this by the Standing
    /// band; at today's accelerated `economyRate` of 1.0 a 240-game-minute
    /// interval is 4 real minutes, which is convenient for development, and it
    /// becomes 4 real hours for free when Phase 4 dials the rate to 1/60.
    static let baseIntervalMinutes: Double = 240

    /// The measured sweet spot. Below ~0.75 the quota is too small to be a sink
    /// and the colony stays saturated; above ~1.2 it starts killing colonists.
    /// The usable band is narrow and must be re-measured whenever the chain
    /// network changes. HELIOS.md Appendix C.
    static let standardLoad: Double = 1.0

    /// A good below this measured capacity is never named. See decision 3.
    static let minimumCapacityPerGameMinute: Double = 0.05

    /// Not enforced by padding — the floor above always wins, because naming a
    /// good the colony cannot spare is worse than a short manifest. This is an
    /// assertion about the network, pinned by a test, so that a future
    /// rebalance which starves the manifest is caught rather than shipped.
    static let minimumLineCount = 5

    /// How many ticks one interval of game-minutes takes at a given rate. The
    /// single place game-minutes become ticks, so nothing downstream is tempted
    /// to reach for a clock.
    static func ticks(forInterval intervalMinutes: Double, economyRate: Double) -> Int {
        guard economyRate > 0 else { return 1 }
        return max(1, Int((intervalMinutes / economyRate).rounded()))
    }

    static func generate(
        id: Int,
        colony: Colony,
        economyRate: Double,
        issuedAtTick: Int,
        intervalMinutes: Double = QuotaGenerator.baseIntervalMinutes,
        load: Double = QuotaGenerator.standardLoad
    ) -> Quota {
        let capacity = CapacityProbe.measure(colony: colony, economyRate: economyRate)

        // Sorted so the iteration order is fixed rather than whatever the
        // dictionary happens to hand back — determinism is a requirement here,
        // not a nicety (Phase 4 replay, Phase 9 reconciliation).
        let eligible = capacity
            .filter { $0.value >= minimumCapacityPerGameMinute }
            .keys
            .sorted()

        var lines: [Resource.ID: Double] = [:]
        for good in eligible {
            let raw = (capacity[good] ?? 0) * intervalMinutes * load
            // One decimal: a manifest is read by a person, and the underlying
            // capacity figures carry no more precision than this anyway.
            lines[good] = (raw * 10).rounded() / 10
        }

        return Quota(
            id: id,
            lines: lines,
            intervalMinutes: intervalMinutes,
            dueAtTick: issuedAtTick + ticks(forInterval: intervalMinutes, economyRate: economyRate)
        )
    }
}