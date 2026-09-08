//
//  QuotaDeliveryTests.swift
//  HeliosTests
//
//  Phase 2 Steps 3–5.
//

// The ledger's justification, pinned. Every expected figure was measured over
// 3,000–5,000 ticks against this exact logic.
//
// These tests drive `GameState.tick()` and nothing else. An earlier version
// recycled the quota cycle in a local helper — which meant the delivery path
// under test was not the path the app ran, and it hid a real bug: nothing in
// `tick()` closed the cycle, so the sink died at the end of the first interval.
// Anything a test has to do for the simulation to keep working belongs in the
// simulation.

import Testing
import Foundation
@testable import Helios

@Suite("Quota delivery")
struct QuotaDeliveryTests {

    /// A seeded game at a fixed cadence and load, with the successor announced
    /// so settlement promotes rather than regenerates. The cadence is pinned
    /// because otherwise Standing moves it mid-measurement — which is exactly
    /// what these tests are trying to hold still.
    private func seeded(cadence: Double = QuotaGenerator.baseIntervalMinutes,
                        load: Double = QuotaGenerator.standardLoad) -> GameState {
        let state = GameState.seeded()
        state.quotaLoad = load
        state.quotaCadenceOverrideMinutes = cadence

        let current = QuotaGenerator.generate(
            id: 1,
            colony: state.colonies[0],
            economyRate: GameState.economyRate,
            issuedAtTick: state.tickCount,
            intervalMinutes: cadence,
            load: load
        )
        let next = QuotaGenerator.generate(
            id: 2,
            colony: state.colonies[0],
            economyRate: GameState.economyRate,
            issuedAtTick: current.dueAtTick,
            intervalMinutes: cadence,
            load: load
        )
        state.currentQuota = current
        state.nextQuota = next
        state.ledger = .empty(for: current)
        state.nextQuotaSerial = 3
        return state
    }

    private func run(_ state: GameState, ticks: Int) {
        for _ in 0..<ticks { state.tick() }
    }

    private func stores(_ state: GameState) -> [Resource.ID: Double] {
        Dictionary(uniqueKeysWithValues: Resource.all.map {
            ($0.id, state.colonies[0].stock.fillFraction(of: $0.id))
        })
    }

    private func meanStoreFill(_ state: GameState) -> Double {
        let values = stores(state).values
        return values.reduce(0, +) / Double(values.count)
    }

    // MARK: - The sink has to be permanent

    /// **The regression test for the bug Step 3 shipped and then fixed.** A
    /// quota fills up, and a completed manifest has no collectable allowance
    /// left. If nothing closes the cycle, the Empire stops collecting at the end
    /// of the first interval and the colony saturates by roughly tick 300 — S1,
    /// arriving through its own fix. DebugSink drained forever; its replacement
    /// must too.
    @Test func theSinkSurvivesManyCycles() {
        let state = seeded()
        guard let quota = state.currentQuota else {
            Issue.record("seeded state has no quota")
            return
        }

        run(state, ticks: quota.intervalTicks * 12)

        #expect(state.settlementHistory.count == 12,
                "expected twelve settled cycles, got \(state.settlementHistory.count)")
        for settlement in state.settlementHistory {
            #expect(settlement.fill > 0.99,
                    "cycle \(settlement.quotaID) settled at fill \(settlement.fill) — delivery is falling behind across cycles")
        }
        for c in state.colonies[0].productionChains {
            #expect(c.status != .stalled,
                    "\(c.name) reported .stalled after twelve cycles — the sink stopped working")
        }
        #expect(meanStoreFill(state) < 0.55,
                "mean store fill \(meanStoreFill(state)) after twelve cycles — drifting back to saturation")
    }

    // MARK: - The ledger's whole justification

    /// **The reason a quota is a ledger and not a snapshot**, measured across
    /// the five cadences Standing actually uses: 96, 168, 240, 360 and 600
    /// game-minutes.
    ///
    /// Interval length must have no economic effect whatsoever, because that is
    /// what lets cadence be a pure attention-and-planning mechanic: a shorter
    /// interval is a smaller shipment, not a heavier one. Measured over 3,000
    /// ticks, the largest store difference across all five is 0.0001 and the
    /// largest throughput difference is 0.0000, with every cycle settling at
    /// fill 1.0000 whether that is thirty-one cycles or five.
    @Test func cadenceLengthDoesNotChangeTheEconomy() {
        var results: [(cadence: Double,
                       stores: [Resource.ID: Double],
                       population: Double,
                       throughputs: [Double],
                       lastFill: Double,
                       cycles: Int)] = []

        for band in StandingBand.allCases {
            let cadence = QuotaGenerator.baseIntervalMinutes * band.cadenceMultiplier
            let state = seeded(cadence: cadence)
            run(state, ticks: 3_000)
            results.append((cadence,
                            stores(state),
                            state.colonies[0].population.total,
                            state.colonies[0].productionChains.map(\.throughput),
                            state.settlementHistory.last?.fill ?? -1,
                            state.settlementHistory.count))
        }

        guard let baseline = results.first else { return }
        for result in results {
            #expect(result.lastFill > 0.99,
                    "cadence \(result.cadence) settled at fill \(result.lastFill)")
            #expect(result.cycles > 0, "cadence \(result.cadence) never settled")
        }
        for result in results.dropFirst() {
            #expect(abs(result.population - baseline.population) <= 1,
                    "population at cadence \(result.cadence) was \(result.population) vs \(baseline.population) at 96")
            for id in Resource.all.map(\.id) {
                let a = baseline.stores[id] ?? -1
                let b = result.stores[id] ?? -1
                #expect(abs(a - b) <= 0.01,
                        "\(id) at cadence \(result.cadence) settled at \(b) vs \(a) at 96")
            }
            for (i, t) in result.throughputs.enumerated() {
                #expect(abs(t - baseline.throughputs[i]) <= 0.01,
                        "chain \(i) throughput at cadence \(result.cadence) was \(t) vs \(baseline.throughputs[i]) at 96")
            }
        }
    }

    // MARK: - Accumulation

    @Test func deliveryAccumulatesAcrossTheInterval() {
        let state = seeded()
        guard let quota = state.currentQuota else {
            Issue.record("seeded state has no quota")
            return
        }

        var previous = [Resource.ID: Double]()
        // One tick short of the deadline, so the ledger under inspection is
        // still this quota's — settlement clears it on the deadline tick.
        for _ in 0..<(quota.intervalTicks - 1) {
            state.tick()
            for line in quota.sortedLines {
                let now = state.ledger.amountDelivered(of: line.good)
                #expect(now >= (previous[line.good] ?? 0) - 1e-9,
                        "\(line.good) ledger went backwards: \(previous[line.good] ?? 0) → \(now)")
                #expect(now <= line.amount + 1e-6,
                        "\(line.good) ledger \(now) exceeded its line of \(line.amount)")
                previous[line.good] = now
            }
        }

        state.tick()   // the deadline tick: final instalment, then settlement
        guard let settled = state.settlementHistory.last else {
            Issue.record("the cycle did not settle on its deadline tick")
            return
        }
        #expect(settled.quotaID == quota.id)
        #expect(settled.settledAtTick == quota.dueAtTick)
        #expect(settled.fill > 0.99,
                "a full interval at load 1.0 should fill the manifest, got \(settled.fill)")
    }

    /// Deliveries are paced by the schedule, so halfway through the interval
    /// roughly half of each line has gone — not all of it, and not none.
    @Test func deliveryIsPacedNotBursted() {
        let state = seeded()
        guard let quota = state.currentQuota else { return }

        run(state, ticks: quota.intervalTicks / 2)

        for line in quota.sortedLines {
            let fraction = state.ledger.amountDelivered(of: line.good) / line.amount
            #expect(fraction > 0.35 && fraction < 0.65,
                    "\(line.good) was \(fraction) delivered at the halfway point")
        }
    }

    // MARK: - Colonists eat first, and the Empire cannot take their food

    @Test func basicNeedsAreReserved() {
        let state = seeded()
        run(state, ticks: 2_000)

        #expect(abs(state.colonies[0].population.total - 450) <= 2,
                "population should hold at 450, got \(state.colonies[0].population.total)")

        for good in QuotaLedger.reservedGoods {
            let fill = state.colonies[0].stock.fillFraction(of: good)
            #expect(fill >= QuotaLedger.reserveFraction - 0.001,
                    "\(good) at \(fill) — below the \(QuotaLedger.reserveFraction) reserve floor")
        }
    }

    /// The rule, stated exactly: the floor binds **the Empire**, not the
    /// colonists.
    ///
    /// This distinction is not pedantry, and an earlier version of this test got
    /// it wrong. `Population.applyTick` runs before production and before
    /// delivery, so colonists draw first and are not floor-limited — they must
    /// not be, or they would starve with food in the warehouse. Measured at load
    /// 4.0 over 3,000 ticks, water reaches 42 against a floor of 60, oxygen 9.1
    /// against 60, and rations 1.5 against 120 — every one of those is a colonist
    /// eating, and the Empire's own draw crosses the floor **zero** times.
    ///
    /// So the invariant is conditional: if the Empire took any of a reserved good
    /// this tick, that good ends the tick at or above its floor.
    @Test func theEmpireNeverDrawsBelowTheReserveFloor() {
        let state = seeded(load: 4.0)
        var previous = [Resource.ID: Double]()

        for _ in 0..<3_000 {
            state.tick()

            for good in QuotaLedger.reservedGoods {
                let stock = state.colonies[0].stock
                let amount = stock.amount(of: good)
                let floor = stock.capacity(of: good) * QuotaLedger.reserveFraction

                let now = state.ledger.amountDelivered(of: good)
                // A drop means the cycle settled and the ledger restarted, so
                // compare against zero rather than last cycle's total.
                let baseline = now < (previous[good] ?? 0) ? 0 : (previous[good] ?? 0)
                if now > baseline + 1e-9 {
                    #expect(amount >= floor - 1e-6,
                            "the Empire took \(good) and left \(amount), below its floor of \(floor)")
                }
                previous[good] = now
            }
        }

        #expect(state.colonies[0].population.total > 0,
                "the colony must survive a punishing quota — Receivership has a floor (HELIOS.md §4.1)")
    }

    /// The floor rule as a pure function, independent of any simulation.
    @Test func drawableStopsAtTheReserveFloor() {
        #expect(QuotaLedger.reservedGoods == ["oxygen", "ration-bars", "water"],
                "the reserved set should derive from ColonistTier.basicNeeds, got \(QuotaLedger.reservedGoods)")

        var full = ColonyStock()
        for resource in Resource.all {
            full.deposit(resource.id, resource.capacity)
        }
        for good in QuotaLedger.reservedGoods {
            let capacity = full.capacity(of: good)
            let expected = capacity - capacity * QuotaLedger.reserveFraction
            #expect(abs(QuotaLedger.drawable(good, from: full) - expected) < 1e-9,
                    "\(good): drawable \(QuotaLedger.drawable(good, from: full)), expected \(expected)")
        }

        // A tradeable is drawable to the last unit.
        #expect(QuotaLedger.drawable("power-cells", from: full) == full.capacity(of: "power-cells"))

        // Below the floor, nothing is drawable at all.
        let thin = ColonyStock(["oxygen": 10])
        #expect(QuotaLedger.drawable("oxygen", from: thin) == 0)
    }

    // MARK: - S1

    /// 5,000 ticks, no player action: nothing saturates, nothing stalls, every
    /// chain but the two structural Refined Alloy consumers runs at the rate it
    /// was asked for.
    @Test func quotaIsTheSinkThatClosesS1() {
        let state = seeded()
        run(state, ticks: 5_000)

        let colony = state.colonies[0]

        for c in colony.productionChains {
            #expect(c.status != .stalled, "\(c.name) reported .stalled — output full is S1")
        }

        let bottlenecked = ["Alloy Tool Fab", "Cell Factory"]
        for c in colony.productionChains where !bottlenecked.contains(c.name) {
            #expect(c.throughput >= c.outputPercent - 0.02,
                    "\(c.name) ran at \(c.throughput) against a requested \(c.outputPercent)")
        }

        #expect(meanStoreFill(state) < 0.55,
                "mean store fill \(meanStoreFill(state)) — the economy is drifting back toward saturation")
        #expect(abs(colony.population.total - 450) <= 2)
    }

    /// Oxygen is the one store that does NOT sit low, and that is understood
    /// rather than accidental. The seed colony starts at 248 Survivors and 0
    /// Settlers and ramps to 450 over ~90 game-minutes; during the ramp nobody
    /// eats the ~200 units of oxygen that difference represents, which is
    /// exactly the capacity of the tank. At load 1.0 the Empire's draw equals
    /// net production, so there is no mechanism that ever removes it.
    ///
    /// It is a full survival buffer, not a saturated economy: the Recycler runs
    /// at 100% (population eats before industry, which opens exactly enough
    /// headroom each tick), nothing reports `.stalled`, and the player's lever
    /// still works — at 50% output, oxygen falls to 3% and population to 268.
    /// Sweeping it would cut life-support slack from ~20 minutes to ~6, which
    /// is a worse colony for a tidier number.
    ///
    /// Pinned so that if it ever changes, it changes on purpose.
    @Test func oxygenHoldsABufferAndTheRecyclerKeepsRunning() {
        let state = seeded()
        run(state, ticks: 5_000)

        let colony = state.colonies[0]
        #expect(colony.stock.fillFraction(of: "oxygen") > 0.90,
                "oxygen was expected to hold a full buffer, got \(colony.stock.fillFraction(of: "oxygen"))")

        guard let recycler = colony.productionChains.first(where: { $0.name == "Oxygen Recycler" }) else {
            Issue.record("No Oxygen Recycler in seed data")
            return
        }
        #expect(recycler.throughput >= 0.98,
                "Oxygen Recycler at \(recycler.throughput) — a full tank must not stall it")
        #expect(recycler.status.isNominal, "Oxygen Recycler reported \(recycler.status)")
    }

    // MARK: - The Empire has no claim on what it did not name

    @Test func unnamedGoodsAreNeverTaken() {
        let state = seeded()
        guard let quota = state.currentQuota else { return }
        #expect(quota.lines["refined-alloy"] == nil, "precondition: Refined Alloy is not on the manifest")

        run(state, ticks: 2_000)
        #expect(state.ledger.amountDelivered(of: "refined-alloy") == 0,
                "the Empire collected a good it never named")
    }
}
