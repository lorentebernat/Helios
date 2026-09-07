// CapacityProbe.swift
// What this colony *could* export per game-minute: production at full output,
// net of what the colonists eat. The number every quota is sized from.
//
// The method is deliberately "run the real thing in a sandbox" rather than
// "derive a formula". A second formula would duplicate ProductionAllocator's
// rules — output caps, the two-phase grid, proportional input allocation,
// population eating first — in a place that can silently drift from it. This
// runs a *copy* of the colony through the actual allocator instead, so the
// probe cannot disagree with the simulation.
//
// ASSESSED CAPACITY IS *INSTALLED* CAPACITY, NOT ACTUAL OUTPUT. Every chain is
// forced to outputPercent = 1 before measuring. If quota scaled with what the
// colony currently produces, throttling a chain would lower next cycle's demand
// and the optimal play would be to run everything at minimum — the standing
// spiral arriving through a side door. Throttling changes what you deliver this
// cycle, never what is asked of you next cycle. HELIOS.md §4.1.
//
// THE WINDOW IS MEASURED IN GAME-MINUTES, NOT TICKS. This is not cosmetic. A
// tick-counted window is a different amount of *simulated time* at every
// economyRate, and the seed colony's population ramp (248 → 450 colonists,
// ~90 game-minutes) is exactly the sort of transient a short window measures
// instead of skipping: fewer colonists eating means a wildly inflated surplus.
// At the 1/60 rate Phase 4 dials in, a 200-*tick* settle is 3.3 game-minutes
// and lands entirely inside that ramp. Measuring the ramp is the same mistake
// HELIOS.md Appendix C made, and it is what made its published figures exceed
// the network's arithmetic ceiling on every single good.
//
// Pure and deterministic: no Date, no randomness, no mutation of the live
// colony. Not called per tick — once per quota generation. At the 1/60 rate a
// probe is ~48,000 sandbox ticks of pure arithmetic over ten chains and nine
// resources, which happens once per quota interval, i.e. once every 14,400
// real ticks.

import Foundation

struct CapacityProbe {

    /// Game-minutes run and discarded before measurement begins, so the
    /// sandbox reaches steady state before anything is counted. The seed
    /// colony's population ramp takes ~90 game-minutes; 200 clears it with
    /// room to spare.
    static let settleMinutes: Double = 200

    /// The sandbox sink pulls every good down to this fraction of its storage
    /// capacity at the end of each tick. Its only job is to stop stores
    /// saturating (which would cap output and understate capacity) without
    /// starving the chains of their inputs. The measured result is provably
    /// insensitive to this value — a good that never reaches the floor, like
    /// Refined Alloy, is simply never touched by it.
    static let sandboxFloorFraction: Double = 0.3

    /// Per-resource export capacity per game-minute: production at full output,
    /// net of what the colonists eat. Runs a *copy* of the colony — never
    /// mutates the live one.
    ///
    /// - Parameters:
    ///   - economyRate: game-minutes advanced per tick, as the live simulation
    ///     runs it. The sandbox is stepped at the same granularity, because the
    ///     simulation is path-dependent and a different tick size is a
    ///     different simulation.
    ///   - gameMinutes: how much simulated time is *measured*. `settleMinutes`
    ///     more are run first and discarded.
    static func measure(
        colony: Colony,
        economyRate: Double,
        gameMinutes: Double = 600
    ) -> [Resource.ID: Double] {
        guard gameMinutes > 0, economyRate > 0 else { return [:] }

        // The single conversion from game-minutes to ticks, mirroring
        // QuotaGenerator.ticks(forInterval:economyRate:). Nothing in this file
        // reasons in ticks except the loop bounds.
        let settleTicks = max(1, Int((settleMinutes / economyRate).rounded()))
        let measuredTicks = max(1, Int((gameMinutes / economyRate).rounded()))

        // Colony is a struct all the way down — stock, population, chains and
        // the shipyard queue are all value types — so this is a deep copy and
        // the caller's colony cannot be reached from here.
        var sandbox = colony
        for i in sandbox.productionChains.indices {
            sandbox.productionChains[i].outputPercent = 1
        }
        // The shipyard has no bearing on export capacity, and an order that
        // completed inside the sandbox would be silently discarded anyway.
        sandbox.shipyardQueue = []

        let goods = Resource.all.map(\.id)
        var net = [Resource.ID: Double](uniqueKeysWithValues: goods.map { ($0, 0.0) })
        var before = [Resource.ID: Double](uniqueKeysWithValues: goods.map { ($0, 0.0) })

        for t in 0..<(settleTicks + measuredTicks) {
            let measuring = t >= settleTicks

            for id in goods {
                before[id] = sandbox.stock.amount(of: id)
            }

            // No quota: the probe brings its own sink. Delivering against a
            // real manifest here would measure the quota rather than the
            // colony, and the quota is what we are trying to size.
            // fleetRate 0: nothing in this sandbox should advance a build.
            sandbox.applyTick(economyRate: economyRate, fleetRate: 0)

            for id in goods {
                let floor = sandbox.stock.capacity(of: id) * sandboxFloorFraction
                let excess = max(0, sandbox.stock.amount(of: id) - floor)
                sandbox.stock.drain(id, excess)

                if measuring {
                    // Net production this tick = what the colony still holds
                    // that it didn't hold before, plus what the sink took.
                    // Measuring both halves means the answer is correct whether
                    // a good is being exported (Power Cells), held flat at the
                    // floor (Water), or quietly accumulating below it
                    // (Refined Alloy) — no dependence on where the floor sits.
                    let kept = sandbox.stock.amount(of: id) - (before[id] ?? 0)
                    net[id] = (net[id] ?? 0) + kept + excess
                }
            }
        }

        // Divide by the game-minutes actually simulated, not the figure that
        // was asked for — the tick conversion above rounds.
        let elapsedMinutes = Double(measuredTicks) * economyRate
        // Clamped at zero: a colony that consumes more of a good than it makes
        // has no export capacity for it, not a negative one.
        return net.mapValues { max(0, $0 / elapsedMinutes) }
    }
}
