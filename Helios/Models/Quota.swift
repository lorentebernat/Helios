// Quota.swift
// The Empire's mandatory demand: a manifest of named goods and amounts it
// expects to leave your docks by a deadline.
//
// NAMED GOODS, NOT BULK TONNAGE. A manifest forces retasking — your chains are
// tuned for what your colonists need, and the manifest asks for something else.
// A tonnage wouldn't. HELIOS.md §4.2.
//
// THE WINDOW IS TICKS, NEVER DATES. A quota carries `issuedAtTick` and
// `dueAtTick`, and every question about its progress — how far into the cycle
// we are, how much is owed by now, whether it has settled — answers itself from
// integer tick arithmetic. `tick()` must stay pure and clock-free: it is what
// makes Phase 4's offline replay and Phase 9's server reconciliation possible.
// Cadence is expressed in *game-minutes*, which becomes real-world time for
// free when Phase 4 dials economyRate to 1/60. (HELIOS.md §4.8 calls the
// cadence "real-time" — that remains the intent; this is how it gets there
// without building it twice.)
//
// Note there is exactly one clock: `GameState.tickCount`. The ledger used to
// carry its own `elapsedMinutes`, which was a second measure of the same thing
// — the shape of §18 S7, where `Colony.gridFactor` re-derived what the
// allocator had already computed and the two only agreed by coincidence. The
// quota owns its window; the ledger owns its deliveries; nothing is derived
// twice.

import Foundation

struct Quota: Codable, Hashable, Identifiable {

    /// Monotonic and deterministic — minted by `GameState`, never a UUID.
    let id: Int

    /// The manifest: how much of each named good the Empire expects. Sized per
    /// good from that good's own measured capacity, never as one bulk figure
    /// split evenly — Water (0.50/min) and Ration Bars (0.15/min) are thin, and
    /// a flat split would demand the impossible of them.
    let lines: [Resource.ID: Double]

    /// Cadence in game-minutes. Display and sizing only; the schedule itself
    /// runs on the tick window below.
    let intervalMinutes: Double

    /// Value of `GameState.tickCount` when this manifest was published.
    let issuedAtTick: Int

    /// Value of `GameState.tickCount` at which this quota settles.
    let dueAtTick: Int

    // MARK: - Reading the manifest

    var lineCount: Int { lines.count }
    var isEmpty: Bool { lines.isEmpty }

    /// How much of `good` is owed. Zero for a good this manifest doesn't name.
    func amount(of good: Resource.ID) -> Double {
        lines[good] ?? 0
    }

    /// The steady rate this line has to be delivered at to arrive on time.
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
    /// renders and delivery iterates in a fixed order — a dictionary has none.
    var sortedLines: [(good: Resource.ID, amount: Double)] {
        Resource.all.compactMap { resource in
            guard let amount = lines[resource.id] else { return nil }
            return (good: resource.id, amount: amount)
        }
    }

    // MARK: - The tick window

    var intervalTicks: Int { max(1, dueAtTick - issuedAtTick) }

    func isDue(atTick tick: Int) -> Bool { tick >= dueAtTick }

    func ticksRemaining(atTick tick: Int) -> Int { max(0, dueAtTick - tick) }

    /// Game-minutes left before the deadline, derived from the tick window
    /// rather than from a second stored counter. What `Format.duration` renders.
    func minutesRemaining(atTick tick: Int) -> Double {
        intervalMinutes * Double(ticksRemaining(atTick: tick)) / Double(intervalTicks)
    }

    /// How far through the cycle we are, 0...1.
    func scheduledFraction(atTick tick: Int) -> Double {
        min(1, max(0, Double(tick - issuedAtTick) / Double(intervalTicks)))
    }

    /// How much of `good` the dock is entitled to have collected *by now*.
    ///
    /// Two properties matter, and they are why this is a schedule rather than a
    /// per-tick rate cap:
    ///
    /// - **It can catch up.** If the store was empty earlier in the cycle, a
    ///   later surplus clears the backlog in one tick instead of the line
    ///   staying permanently behind.
    /// - **It can never run ahead.** Allowing the dock to collect early looks
    ///   harmless and is not: it empties a store, completes the line partway
    ///   through the cycle, and leaves the rest of the interval with no sink at
    ///   all. Measured with a 25% lead allowance at a 2,880-minute interval,
    ///   Alloy Tools sits at zero for 2,160 game-minutes, Settler happiness
    ///   goes to zero, and the colony dies of attrition. Running ahead is what
    ///   breaks interval-neutrality; staying on schedule is what preserves it.
    func scheduledAmount(of good: Resource.ID, atTick tick: Int) -> Double {
        amount(of: good) * scheduledFraction(atTick: tick)
    }

    /// Slack before delivery counts as behind schedule. Shared by the panel
    /// and `QuotaLineRow`, so both mean the same thing by amber.
    static let paceTolerance = 0.02

    // MARK: - Settlement arithmetic

    /// Overall fill, **normalised per line so a big line and a small line count
    /// equally**: `Σ(delivered[g] / lineAmount[g]) / lineCount`. Without the
    /// normalisation, Power Cells (1,260 units) would drown out Ration Bars
    /// (36) and the manifest's breadth would stop meaning anything.
    func fill(from ledger: QuotaLedger) -> Double {
        guard !isEmpty else { return 0 }
        let total = lines.reduce(0.0) { partial, line in
            guard line.value > 0 else { return partial + 1 }
            return partial + min(1, ledger.amountDelivered(of: line.key) / line.value)
        }
        return total / Double(lineCount)
    }

    /// Per-line fill, for the archive and for the Step 8 detail screen.
    func lineFills(from ledger: QuotaLedger) -> [Resource.ID: Double] {
        lines.reduce(into: [:]) { result, line in
            result[line.key] = line.value > 0
                ? min(1, ledger.amountDelivered(of: line.key) / line.value)
                : 1
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
        issuedAtTick: 0,
        dueAtTick: 240
    )
}
