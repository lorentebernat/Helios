//
//  CapacityTests.swift
//  HeliosTests
//
//  Phase 2 Step 1.
//

// Pins CapacityProbe — the number every quota is sized from, so a drift here
// silently re-tunes the entire Empire layer.
//
// NOTE ON THE EXPECTED TABLE. These values differ from HELIOS.md Appendix C by
// −1% to −3% on most goods, and by more on Water and Ration Bars. Appendix C is
// what is wrong, and it is checkable by hand: every one of its figures sits
// ABOVE the arithmetic ceiling of the seed network at full population
// (300 Survivors + 150 Settlers).
//
//   Ration Bars   Synth 6.00 max − 3.60 (survivors) − 2.25 (settlers) = 0.15
//   Water         Reclaimer 12.00 − 6 (hydro) − 4 (synth) − 1.50 (settlers) = 0.50
//   Oxygen        Recycler 12.00 − 6.00 − 3.75                        = 2.25
//   Raw Ice       20 − 8 − 10                                          = 2.00
//   Grain         10 − 8                                               = 2.00
//   Raw Ore       15 − 10                                              = 5.00
//   Power Cells   6 × 7/8  (the Refined Alloy bottleneck)              = 5.25
//   Alloy Tools   4 × 7/8 − 0.75 (settler luxury)                      = 2.75
//   Refined Alloy Smelter 7 in, Fab + Factory 7 out                    = 0.00
//
// Appendix C's figures are inflated by a near-constant ~0.06/min because they
// were averaged over a window that included the population ramp (248 → 450),
// when fewer colonists were eating. Noise on wide-margin goods; decisive on
// Ration Bars, whose true margin is 0.15. Appendix C is corrected in this phase.

import Testing
import Foundation
@testable import Helios

@Suite("Capacity")
struct CapacityTests {

    /// Measured export ceiling of the seed network, per game-minute.
    private static let expected: [Resource.ID: Double] = [
        "power-cells":   5.25,
        "raw-ore":       5.00,
        "alloy-tools":   2.75,
        "oxygen":        2.25,
        "raw-ice":       2.00,
        "grain":         2.00,
        "water":         0.50,
        "ration-bars":   0.15,
        "refined-alloy": 0.00
    ]

    /// ±5%, with an absolute floor so Refined Alloy's 0.00 has a window at all
    /// rather than demanding exact equality.
    private static func tolerance(for expected: Double) -> Double {
        max(0.02, expected * 0.05)
    }

    private func seedColony() -> Colony {
        GameState.seeded().colonies[0]
    }

    private func throttled(_ names: [String], to value: Double) -> Colony {
        var colony = seedColony()
        for name in names {
            guard let i = colony.productionChains.firstIndex(where: { $0.name == name }) else {
                Issue.record("No chain named \(name) in seed data")
                continue
            }
            colony.productionChains[i].outputPercent = value
        }
        return colony
    }

    // MARK: - The baseline everything downstream is tuned against

    @Test func matchesAppendixC() {
        let measured = CapacityProbe.measure(colony: seedColony(), economyRate: 1.0)

        for (id, want) in Self.expected {
            let got = measured[id] ?? -1
            #expect(abs(got - want) <= Self.tolerance(for: want),
                    "\(id): expected \(want) ± \(Self.tolerance(for: want)), got \(got)")
        }

        #expect(measured.count == Resource.all.count,
                "the probe should report every resource in the registry")
    }

    // MARK: - The anti-exploit test

    /// The most important test in this step. Quota is sized from *installed*
    /// capacity, so throttling a chain must not change what the Empire asks for
    /// next cycle. If this fails, the optimal play becomes running the colony at
    /// minimum and the whole economy is poisoned. HELIOS.md §4.1.
    @Test func isUnaffectedByThrottling() {
        let full = CapacityProbe.measure(colony: seedColony(), economyRate: 1.0)
        let quiet = CapacityProbe.measure(
            colony: throttled(["Alloy Tool Fab", "Cell Factory", "Hydroponics Bay"], to: 0.25),
            economyRate: 1.0
        )

        for id in Resource.all.map(\.id) {
            #expect(full[id] == quiet[id],
                    "\(id): throttling changed assessed capacity — \(full[id] ?? -1) vs \(quiet[id] ?? -1)")
        }
    }

    /// The extreme form: a colony with everything switched off must still
    /// assess exactly the same, because it has built exactly the same.
    @Test func isUnaffectedByAFullShutdown() {
        let full = CapacityProbe.measure(colony: seedColony(), economyRate: 1.0)

        var dark = seedColony()
        for i in dark.productionChains.indices {
            dark.productionChains[i].outputPercent = 0
        }
        let measured = CapacityProbe.measure(colony: dark, economyRate: 1.0)

        for id in Resource.all.map(\.id) {
            #expect(full[id] == measured[id],
                    "\(id): a shut-down colony assessed differently — \(full[id] ?? -1) vs \(measured[id] ?? -1)")
        }
    }
    
    /// A power-limited colony assesses *below* what a player who throttles can
    /// actually produce — and that is the safe direction, not a defect.
    ///
    /// The probe forces every chain to 100%, which for a colony whose grid
    /// cannot serve everything at once is a state it can never occupy. Measured
    /// with the Power Plant at 90 MW instead of 240, capacity comes back at
    /// roughly 53% of the healthy figures across the board, and Ration Bars
    /// falls to 0.00 — below the naming floor, so a power-starved colony is not
    /// even asked for them.
    ///
    /// The alternative would be to measure the best output achievable under
    /// some throttling strategy. That is strictly worse: the Empire would
    /// optimise on the player's behalf, and the assessment would *rise* the
    /// moment they played well. Under-assessment errs toward the player.
    ///
    /// The cost is real and belongs in the record. A player who throttles
    /// wisely out-produces the assessment, and at load 1.0 that surplus has
    /// nowhere to go: in the brownout-plus-throttle scenario five of nine
    /// stores saturate and four chains stall. This is the second sink Appendix C
    /// already asks for — construction consuming materials, Phase 5. "Quota is
    /// pressure; building is agency."
    @Test func assessmentUnderstatesAPowerLimitedColony() {
        var brownout = seedColony()
        guard let plant = brownout.productionChains.firstIndex(where: { $0.name == "Power Plant" }) else {
            Issue.record("No Power Plant in seed data")
            return
        }
        brownout.productionChains[plant].energyProduced = 90

        let healthy = CapacityProbe.measure(colony: seedColony(), economyRate: 1.0)
        let starved = CapacityProbe.measure(colony: brownout, economyRate: 1.0)

        for good in ["power-cells", "raw-ore", "grain", "raw-ice", "oxygen", "alloy-tools"] {
            let h = healthy[good] ?? 0
            let s = starved[good] ?? 0
            #expect(s < h, "\(good): a brownout colony assessed \(s), no lower than the healthy \(h)")
            #expect(s > 0, "\(good): a brownout colony still produces something, got \(s)")
        }

        // Below the naming floor — a starved colony is not asked for rations.
        #expect((starved["ration-bars"] ?? 1) < QuotaGenerator.minimumCapacityPerGameMinute,
                "expected Ration Bars below the naming floor, got \(starved["ration-bars"] ?? -1)")

        // The anti-exploit property still holds inside the brownout: throttling
        // changes what you deliver, never what you are assessed at.
        var quiet = brownout
        for i in quiet.productionChains.indices {
            quiet.productionChains[i].outputPercent = 0.25
        }
        let throttled = CapacityProbe.measure(colony: quiet, economyRate: 1.0)
        for id in Resource.all.map(\.id) {
            #expect(starved[id] == throttled[id],
                    "\(id): throttling changed a brownout colony's assessment — \(starved[id] ?? -1) vs \(throttled[id] ?? -1)")
        }
    }

    // MARK: - It runs on a copy

    @Test func doesNotMutateTheColony() {
        var colony = seedColony()
        // Set something the probe overwrites internally, so a leak would show.
        colony.productionChains[0].outputPercent = 0.5

        let stockBefore = Resource.all.map { colony.stock.amount(of: $0.id) }
        let throughputBefore = colony.productionChains.map(\.throughput)
        let statusBefore = colony.productionChains.map(\.status)
        let percentBefore = colony.productionChains.map(\.outputPercent)
        let populationBefore = colony.population.total
        let queueBefore = colony.shipyardQueue.count

        _ = CapacityProbe.measure(colony: colony, economyRate: 1.0)

        #expect(Resource.all.map { colony.stock.amount(of: $0.id) } == stockBefore, "stock was mutated")
        #expect(colony.productionChains.map(\.throughput) == throughputBefore, "throughputs were mutated")
        #expect(colony.productionChains.map(\.status) == statusBefore, "statuses were mutated")
        #expect(colony.productionChains.map(\.outputPercent) == percentBefore, "outputPercent was mutated")
        #expect(colony.population.total == populationBefore, "population was mutated")
        #expect(colony.shipyardQueue.count == queueBefore, "shipyard queue was mutated")
    }

    // MARK: - Determinism (the property Phase 4 replay and Phase 9 both need)

    @Test func isDeterministic() {
        let a = CapacityProbe.measure(colony: seedColony(), economyRate: 1.0)
        let b = CapacityProbe.measure(colony: seedColony(), economyRate: 1.0)
        #expect(a == b, "two identical colonies measured differently")
    }

    /// Capacity is per *game-minute*, so the tick size must not change it.
    ///
    /// **1/60 is the case that matters**, and it is the one that caught the
    /// original bug: the probe's settle window was counted in ticks, so at
    /// Phase 4's honest rate it covered 3.3 game-minutes instead of 200 and
    /// measured the seed colony's population ramp rather than its steady state.
    /// Oxygen came back at 5.83/min against a true 2.25 and Ration Bars at 2.30
    /// against 0.15 — every manifest would have inflated by 2–15× the moment
    /// Phase 4 dialled the rate down. The window is game-minutes now.
    @Test func isIndependentOfEconomyRate() {
        let rates: [Double] = [1.0, 0.5, 0.25, 1.0 / 60.0]
        let measurements = rates.map { rate in
            (rate: rate, values: CapacityProbe.measure(colony: seedColony(), economyRate: rate))
        }

        for (rate, values) in measurements {
            for (id, want) in Self.expected {
                let got = values[id] ?? -1
                #expect(abs(got - want) <= Self.tolerance(for: want),
                        "at economyRate \(rate), \(id): expected \(want), got \(got)")
            }
        }
    }
}
