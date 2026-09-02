//
//  HeliosTests.swift
//  HeliosTests
//
//  Created by Bernat on 04/08/2026.
//

// Pins behaviour of ProductionAllocator and Population — the two most
// intricate pure functions in the simulation, previously untested
// (HELIOS.md §18 S8). Every expected number here was measured against the
// real allocator on 28 Aug 2026 (HELIOS.md Appendix C) and re-verified
// against a line-for-line port of this exact logic before being pinned.
//
// Swift Testing runs tests in parallel by default, so every test builds its
// own GameState.seeded() — nothing is shared — and the debug sink is passed
// in via Colony.applyTick(applyDebugSink:) rather than toggled through a
// mutable static, which would be flaky under parallel execution.

import Testing
@testable import Helios

@Suite("ProductionAllocator & Population")
struct HeliosTests {

    // MARK: - Helpers

    /// Ticks the (single-colony) seeded game state `n` times, with the debug
    /// sink explicitly on or off.
    private func tick(_ state: GameState, _ n: Int, sink: Bool) {
        for _ in 0..<n {
            _ = state.colonies[0].applyTick(economyRate: 1.0, fleetRate: 1.0, applyDebugSink: sink)
        }
    }

    private func chain(_ state: GameState, named name: String) -> ChainDetail {
        guard let found = state.colonies[0].productionChains.first(where: { $0.name == name }) else {
            Issue.record("No chain named \(name) in seed data")
            return state.colonies[0].productionChains[0]
        }
        return found
    }

    private func setOutputPercent(_ state: GameState, named name: String, to value: Double) {
        guard let i = state.colonies[0].productionChains.firstIndex(where: { $0.name == name }) else {
            Issue.record("No chain named \(name) in seed data")
            return
        }
        state.colonies[0].productionChains[i].outputPercent = value
    }

    private func expectApprox(_ actual: Double, _ expected: Double, tolerance: Double, _ label: String = "") {
        #expect(abs(actual - expected) <= tolerance, "\(label): expected \(expected) ± \(tolerance), got \(actual)")
    }

    // MARK: - S1: saturation is real, and only a sink removes it

    @Test func saturatesWithoutASink() {
        let state = GameState.seeded()
        tick(state, 300, sink: false)

        let colony = state.colonies[0]
        let notRunning = colony.productionChains.filter { !$0.status.isNominal }
        #expect(notRunning.count >= 8, "expected at least 8 chains not running, got \(notRunning.count)")

        let ids = Resource.all.map(\.id)
        let meanFill = ids.reduce(0.0) { $0 + colony.stock.fillFraction(of: $1) } / Double(ids.count)
        #expect(meanFill > 0.90, "expected mean store fill > 90%, got \(meanFill)")
    }

    // MARK: - Steady state with the sink on

    @Test func steadyStateWithSink() {
        let state = GameState.seeded()
        tick(state, 2000, sink: true)

        let colony = state.colonies[0]
        let notRunning = colony.productionChains.filter { !$0.status.isNominal }
        #expect(notRunning.count == 2,
                "expected exactly 2 chains not running, got \(notRunning.count): \(notRunning.map(\.name))")

        for c in notRunning {
            guard case .limited(.input(let id)) = c.status else {
                Issue.record("\(c.name) expected .limited(.input(\"refined-alloy\")), got \(c.status)")
                continue
            }
            #expect(id == "refined-alloy", "\(c.name) limited by \(id), expected refined-alloy")
            expectApprox(c.throughput, 0.86, tolerance: 0.02, c.name)
        }
    }

    @Test func sinkKeepsColonistsAlive() {
        let state = GameState.seeded()
        tick(state, 2000, sink: true)

        let colony = state.colonies[0]
        expectApprox(colony.population.total, 450, tolerance: 2, "population total")

        for id in ["oxygen", "ration-bars", "water"] {
            let fraction = colony.stock.fillFraction(of: id)
            expectApprox(fraction, 0.30, tolerance: 0.01, "\(id) reserve fill")
        }
    }

    // MARK: - S15: status reflects the requested rate, not 1.0

    @Test func outputPercentIsHonoured() {
        let state = GameState.seeded()
        setOutputPercent(state, named: "Alloy Tool Fab", to: 0.5)
        tick(state, 2000, sink: true)

        let toolFab = chain(state, named: "Alloy Tool Fab")
        expectApprox(toolFab.throughput, 0.5, tolerance: 0.02, "Alloy Tool Fab throughput")
        #expect(toolFab.status.isNominal,
                "a chain at exactly its requested rate should be .running, got \(toolFab.status)")
    }

    @Test func pauseStopsConsumption() {
        let state = GameState.seeded()
        setOutputPercent(state, named: "Alloy Tool Fab", to: 0)
        tick(state, 2000, sink: true)

        let toolFab = chain(state, named: "Alloy Tool Fab")
        guard case .paused = toolFab.status else {
            Issue.record("expected .paused, got \(toolFab.status)")
            return
        }
        #expect(toolFab.throughput == 0)
        #expect(state.colonies[0].stock.amount(of: "refined-alloy") > 100,
                "refined-alloy should accumulate once nothing draws it")
    }

    // MARK: - S6: throttling a chain frees power for the rest of the colony

    @Test func throttlingFreesPower() {
        let state = GameState.seeded()
        guard let ppIndex = state.colonies[0].productionChains.firstIndex(where: { $0.name == "Power Plant" }) else {
            Issue.record("No Power Plant in seed data")
            return
        }
        state.colonies[0].productionChains[ppIndex].energyProduced = 90
        tick(state, 200, sink: true)

        let hydroBefore = chain(state, named: "Hydroponics Bay")
        expectApprox(hydroBefore.throughput, 0.52, tolerance: 0.02, "Hydroponics before freeing power")

        setOutputPercent(state, named: "Alloy Tool Fab", to: 0)
        setOutputPercent(state, named: "Cell Factory", to: 0)
        tick(state, 500, sink: true)

        let hydroAfter = chain(state, named: "Hydroponics Bay")
        expectApprox(hydroAfter.throughput, 1.0, tolerance: 0.02,
                     "Hydroponics after pausing the two Refined Alloy consumers")
    }

    // MARK: - S15, general form

    @Test func noChainReportsLimitedWhileAtRate() {
        let state = GameState.seeded()
        tick(state, 2000, sink: true)

        for c in state.colonies[0].productionChains where c.outputPercent > 0 {
            let attainment = c.throughput / c.outputPercent
            if attainment >= 0.98 {
                #expect(c.status.isNominal,
                        "\(c.name) at \(attainment) attainment reported \(c.status), expected .running")
            }
        }
    }

    // MARK: - S7: Colony.gridFactor IS the factor the allocator used

    @Test func gridFactorMatchesAllocator() {
        let state = GameState.seeded()
        guard let ppIndex = state.colonies[0].productionChains.firstIndex(where: { $0.name == "Power Plant" }) else {
            Issue.record("No Power Plant in seed data")
            return
        }
        state.colonies[0].productionChains[ppIndex].energyProduced = 90   // force a brownout
        tick(state, 1, sink: true)

        let colony = state.colonies[0]
        let expected = colony.gridDemand <= 0 ? 1 : min(1, colony.gridSupply / colony.gridDemand)
        #expect(colony.gridFactor == expected,
                "gridFactor (\(colony.gridFactor)) should equal supply/demand clamped to 1 (\(expected))")
        #expect(colony.gridFactor < 1, "this scenario should actually be a brownout")
    }

    // MARK: - Population, directly

    @Test func populationDeclinesWhenStarved() {
        var population = Population.seeded
        var stock = ColonyStock()   // empty — zero oxygen, zero everything

        let start = population.state(for: .survivors)?.count ?? 0
        for _ in 0..<100 {
            population.applyTick(stock: &stock, minutesPerTick: 1.0)
        }
        let after = population.state(for: .survivors)?.count ?? -1
        #expect(after < start, "starved survivors should decline, went from \(start) to \(after)")
    }

    @Test func populationGrowsToCapacityAndStops() {
        var population = Population.seeded
        var stock = ColonyStock([
            "oxygen": 1_000_000, "ration-bars": 1_000_000,
            "water": 1_000_000, "alloy-tools": 1_000_000
        ])

        for _ in 0..<200 {
            population.applyTick(stock: &stock, minutesPerTick: 1.0)
        }
        let survivors = population.state(for: .survivors)
        #expect(survivors?.count == survivors?.capacity, "survivors should stop exactly at capacity")
    }

    @Test func promotionRequiresHappiness() {
        var population = Population.seeded
        var indexOf: [ColonistTier: Int] = [:]
        for (i, t) in population.tiers.enumerated() { indexOf[t.tier] = i }

        // Zero survivors, some settlers already present, engineers given
        // room — so a block here is meaningful rather than merely structural
        // (capacity 0 would block promotion regardless of happiness).
        population.tiers[indexOf[.survivors]!].count = 0
        population.tiers[indexOf[.settlers]!].count = 100
        population.tiers[indexOf[.engineers]!].capacity = 50

        // Basic needs abundant, but alloy-tools — the settlers' luxury — is
        // entirely absent, so happiness can never reach 1.
        var stock = ColonyStock([
            "oxygen": 1_000_000, "ration-bars": 1_000_000,
            "water": 1_000_000, "alloy-tools": 0
        ])

        for _ in 0..<50 {
            population.applyTick(stock: &stock, minutesPerTick: 1.0)
        }

        let settlers = population.state(for: .settlers)
        let engineers = population.state(for: .engineers)
        #expect((settlers?.happiness ?? 1) < 1, "settlers should be unhappy — alloy-tools is unavailable")
        #expect(engineers?.count == 0, "no promotion should occur while happiness is below 1")
    }
}
