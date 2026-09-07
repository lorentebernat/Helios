//
//  HeliosTests.swift
//  HeliosTests
//
//  Created by Bernat on 04/08/2026.
//

// Pins behaviour of ProductionAllocator and Population — the two most
// intricate pure functions in the simulation (HELIOS.md §18 S8). Every
// expected number here was measured against the real allocator and
// re-verified against a line-for-line port of this exact logic before being
// pinned.
//
// Swift Testing runs tests in parallel by default, so every test builds its
// own GameState.seeded() and nothing is shared.
//
// PHASE 2 STEP 3: the debug sink is gone. These tests used to pass
// `applyDebugSink:` to choose whether anything drained the colony; they now
// drive the real quota path through `GameState.tick()`, and switch the sink off
// by clearing `currentQuota` — which is S1 exactly, reachable only on purpose.

import Testing
import Foundation
@testable import Helios

@Suite("ProductionAllocator & Population")
struct HeliosTests {

    // MARK: - Helpers

    /// Ticks the whole game state `n` times, so quota delivery and the ledger's
    /// interval both advance the way they do in play.
    private func tick(_ state: GameState, _ n: Int) {
        for _ in 0..<n { state.tick() }
    }

    /// A seeded game with no demand at all — no manifest, therefore no sink.
    private func seededWithoutQuota() -> GameState {
        let state = GameState.seeded()
        state.currentQuota = nil
        return state
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
        let state = seededWithoutQuota()
        tick(state, 300)

        let colony = state.colonies[0]
        let notRunning = colony.productionChains.filter { !$0.status.isNominal }
        #expect(notRunning.count >= 8, "expected at least 8 chains not running, got \(notRunning.count)")

        let ids = Resource.all.map(\.id)
        let meanFill = ids.reduce(0.0) { $0 + colony.stock.fillFraction(of: $1) } / Double(ids.count)
        #expect(meanFill > 0.90, "expected mean store fill > 90%, got \(meanFill)")
    }

    // MARK: - Steady state with a real quota

    @Test func steadyStateWithQuota() {
        let state = GameState.seeded()
        tick(state, 2000)

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
            expectApprox(c.throughput, 0.875, tolerance: 0.02, c.name)
        }
    }

    @Test func quotaKeepsColonistsAlive() {
        let state = GameState.seeded()
        tick(state, 2000)

        let colony = state.colonies[0]
        expectApprox(colony.population.total, 450, tolerance: 2, "population total")

        // The reserve floor is a floor, not a target. With the manifest sized
        // at load 1.0 the Empire's draw exactly matches net production, so
        // these goods sit wherever the startup transient left them — above the
        // floor, never below it. (The old expectation of exactly 30% came from
        // DebugSink draining *faster* than the colony could produce, which
        // pinned them against the floor. See HELIOS.md Appendix C.)
        for id in ["oxygen", "ration-bars", "water"] {
            let fraction = colony.stock.fillFraction(of: id)
            #expect(fraction >= QuotaLedger.reserveFraction - 0.001,
                    "\(id) at \(fraction) — the Empire crossed the reserve floor")
        }
    }

    // MARK: - S15: status reflects the requested rate, not 1.0

    @Test func outputPercentIsHonoured() {
        let state = GameState.seeded()
        setOutputPercent(state, named: "Alloy Tool Fab", to: 0.5)
        tick(state, 2000)

        let toolFab = chain(state, named: "Alloy Tool Fab")
        expectApprox(toolFab.throughput, 0.5, tolerance: 0.02, "Alloy Tool Fab throughput")
        #expect(toolFab.status.isNominal,
                "a chain at exactly its requested rate should be .running, got \(toolFab.status)")
    }

    @Test func pauseStopsConsumption() {
        let state = GameState.seeded()
        setOutputPercent(state, named: "Alloy Tool Fab", to: 0)
        tick(state, 2000)

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
        tick(state, 200)

        let hydroBefore = chain(state, named: "Hydroponics Bay")
        expectApprox(hydroBefore.throughput, 0.53, tolerance: 0.02, "Hydroponics before freeing power")

        setOutputPercent(state, named: "Alloy Tool Fab", to: 0)
        setOutputPercent(state, named: "Cell Factory", to: 0)
        tick(state, 500)

        let hydroAfter = chain(state, named: "Hydroponics Bay")
        expectApprox(hydroAfter.throughput, 1.0, tolerance: 0.02,
                     "Hydroponics after pausing the two Refined Alloy consumers")
    }

    // MARK: - S15, general form

    @Test func noChainReportsLimitedWhileAtRate() {
        let state = GameState.seeded()
        tick(state, 2000)

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
        tick(state, 1)

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

    // MARK: - S5: no randomness inside tick()

    /// Two independently-seeded states, given the exact same sequence of
    /// actions, must produce byte-identical results — including ship ids and,
    /// now, the generated manifest and its ledger. This is the property Phase
    /// 4's offline replay and Phase 9's server reconciliation both depend on.
    /// HELIOS.md §18 S5.
    @Test func tickIsDeterministic() {
        let a = GameState.seeded()
        let b = GameState.seeded()

        // The seed colony starts with zero Refined Alloy by design, so no ship
        // role is affordable at tick 0. Deposit identically into both colonies
        // so queueShip succeeds the same way in both runs.
        a.colonies[0].stock.deposit("refined-alloy", 100)
        b.colonies[0].stock.deposit("refined-alloy", 100)

        #expect(a.queueShip(role: .scout, name: "Test Scout"))
        #expect(b.queueShip(role: .scout, name: "Test Scout"))

        for _ in 0..<200 {
            a.tick()
            b.tick()
        }

        let colonyA = a.colonies[0]
        let colonyB = b.colonies[0]

        for id in Resource.all.map(\.id) {
            #expect(colonyA.stock.amount(of: id) == colonyB.stock.amount(of: id),
                     "stock diverged for \(id)")
        }

        #expect(colonyA.productionChains.map(\.throughput) == colonyB.productionChains.map(\.throughput),
                "throughputs diverged")

        #expect(a.currentQuota == b.currentQuota, "generated manifests diverged")
        #expect(a.ledger == b.ledger, "quota ledgers diverged")

        #expect(a.ships.map(\.id) == b.ships.map(\.id), "ship ids diverged")
        #expect(a.ships.count == 6, "expected the seed fleet of 5 plus the one queued ship")
    }
}

// MARK: - Persistence (Phase 1.5 Step 5, extended Phase 2 Step 3)

/// `ChainDetail`/`ResearchProject`'s blueprint-overlay `Codable` and
/// `GameSave`'s round trip. Every save/load in these tests goes through real
/// `JSONEncoder`/`JSONDecoder`, not hand-typed JSON, except where a test
/// specifically needs to hand-craft an unknown id.
@Suite("Persistence")
struct PersistenceTests {

    /// Seeds, ticks 500 times, encodes, decodes, and asserts the restored
    /// state ticks identically to the original for another 100 ticks — the
    /// property that actually matters: a loaded save behaves exactly like
    /// the game that was saved, not just "decodes without crashing."
    ///
    /// Phase 2 makes this strictly stronger: 500 ticks is mid-cycle, so the
    /// quota, its ledger and the elapsed interval all have to survive or the
    /// two runs deliver different amounts and diverge immediately.
    @Test func saveRoundTrips() throws {
        let original = GameState.seeded()
        for _ in 0..<500 {
            original.tick()
        }

        let data = try JSONEncoder().encode(original.snapshot)
        let save = try JSONDecoder().decode(GameSave.self, from: data)
        let restored = GameState(save: save)

        #expect(restored.currentQuota == original.currentQuota, "quota did not survive the round trip")
        #expect(restored.ledger == original.ledger, "ledger did not survive the round trip")

        for _ in 0..<100 {
            original.tick()
            restored.tick()
        }

        for id in Resource.all.map(\.id) {
            #expect(original.colonies[0].stock.amount(of: id) == restored.colonies[0].stock.amount(of: id),
                    "stock diverged for \(id) after round-trip")
        }
        #expect(original.colonies[0].productionChains.map(\.throughput) == restored.colonies[0].productionChains.map(\.throughput),
                "throughputs diverged after round-trip")
        #expect(original.colonies[0].productionChains.map(\.status) == restored.colonies[0].productionChains.map(\.status),
                "statuses diverged after round-trip")
        #expect(original.ships.map(\.id) == restored.ships.map(\.id), "ship ids diverged after round-trip")
        #expect(original.credits == restored.credits, "credits diverged after round-trip")
        #expect(original.colonies[0].population.total == restored.colonies[0].population.total,
                "population diverged after round-trip")
        #expect(original.ledger == restored.ledger, "ledger diverged after round-trip")
    }

    /// Hand-crafts a save naming a chain id that isn't in the registry —
    /// decode must succeed with that chain simply absent, not throw and not
    /// resurrect it as a placeholder.
    @Test func unknownChainIsDropped() throws {
        let state = GameState.seeded()
        let data = try JSONEncoder().encode(state.snapshot)

        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Issue.record("save didn't decode as a JSON object")
            return
        }
        guard var colonies = json["colonies"] as? [[String: Any]],
              var chains = colonies[0]["productionChains"] as? [[String: Any]],
              var ghost = chains.first
        else {
            Issue.record("unexpected save JSON shape — missing colonies[0].productionChains")
            return
        }

        let originalCount = chains.count
        ghost["id"] = ["slug": "decommissioned-chain"]
        chains.append(ghost)
        colonies[0]["productionChains"] = chains
        json["colonies"] = colonies

        let mutatedData = try JSONSerialization.data(withJSONObject: json)
        let save = try JSONDecoder().decode(GameSave.self, from: mutatedData)

        #expect(save.colonies[0].productionChains.count == originalCount,
                "unknown chain should have been dropped, not resurrected")
        #expect(!save.colonies[0].productionChains.contains { $0.id.slug == "decommissioned-chain" },
                "the unknown chain id should not appear anywhere in the decoded colony")
    }

    @Test func unknownResearchProjectIsDropped() throws {
        let state = GameState.seeded()
        let data = try JSONEncoder().encode(state.snapshot)

        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Issue.record("save didn't decode as a JSON object")
            return
        }
        guard var projects = json["researchProjects"] as? [[String: Any]],
              var ghost = projects.first
        else {
            Issue.record("unexpected save JSON shape — missing researchProjects")
            return
        }

        let originalCount = projects.count
        ghost["id"] = ["slug": "retired-project"]
        projects.append(ghost)
        json["researchProjects"] = projects

        let mutatedData = try JSONSerialization.data(withJSONObject: json)
        let save = try JSONDecoder().decode(GameSave.self, from: mutatedData)

        #expect(save.researchProjects.count == originalCount,
                "unknown research project should have been dropped, not resurrected")
        #expect(!save.researchProjects.contains { $0.id.slug == "retired-project" },
                "the unknown project id should not appear anywhere in the decoded save")
    }

    @Test func chainStatusRoundTrips() throws {
        let statuses: [ChainStatus] = [
            .running, .stalled, .paused,
            .limited(.power), .limited(.workforce), .limited(.input("refined-alloy"))
        ]

        for status in statuses {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(ChainStatus.self, from: data)
            #expect(decoded == status, "\(status) round-tripped to \(decoded)")
        }
    }

    /// The save format changed shape this step, so the version guard is now
    /// load-bearing rather than theoretical.
    @Test func saveDeclaresTheCurrentVersion() {
        #expect(GameState.seeded().snapshot.version == SaveStore.supportedVersion,
                "a freshly written save must declare the version this build loads")
    }
}
