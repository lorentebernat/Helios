//
//  StipendTests.swift
//  Helios
//
//  Created by Bernat on 08/09/2026.
//


//
//  StipendTests.swift
//  HeliosTests
//
//  Phase 2 Step 6.
//

// S3's regression tests. Before this step `credits` was mutated in exactly one
// place — `credits -=` — and buying an Escort plus a Scout left the shipyard
// permanently dead. HELIOS.md §18 S3.

import Testing
import Foundation
@testable import Helios

@Suite("Stipend")
struct StipendTests {

    private func run(_ state: GameState, ticks: Int) {
        for _ in 0..<ticks { state.tick() }
    }

    /// A fresh game with the cadence held at the Indifferent figure, so cycle
    /// counts and payments are predictable.
    private func fixedCadence(band: StandingBand = .indifferent) -> GameState {
        let state = GameState.seeded()
        state.standing = Standing(reliability: Standing.riseThresholds.indices.contains(band.rawValue)
                                    ? (Standing.riseThresholds[band.rawValue] - 0.01)
                                    : 1.0,
                                  band: band)
        state.quotaCadenceOverrideMinutes = QuotaGenerator.baseIntervalMinutes
        reissueManifests(state)
        return state
    }

    // MARK: - Credits finally have a source

    @Test func metQuotaPaysAStipend() {
        let state = GameState.seeded()
        guard let quota = state.currentQuota else { return }
        let before = state.credits

        run(state, ticks: quota.dueAtTick)

        #expect(state.credits > before,
                "credits went from \(before) to \(state.credits) across a met cycle")
        guard let settled = state.settlementHistory.last else {
            Issue.record("nothing settled")
            return
        }
        #expect(settled.stipend == state.credits - before,
                "the archive says \(settled.stipend), credits moved by \(state.credits - before)")
        #expect(settled.stipend == 300,
                "a met quota at Indifferent should pay 300, got \(settled.stipend)")
    }

    /// The calibration the brief asks for: usable, not free. 300 credits per met
    /// cycle at Indifferent puts a Freighter (800) within 2.67 cycles.
    @Test func aMetQuotaAtIndifferentAffordsAFreighterEveryFewCycles() {
        let cycles = Double(ShipRole.freighter.buildCost.credits)
            / (GameState.stipendPerGameMinute
               * QuotaGenerator.baseIntervalMinutes
               * StandingBand.indifferent.stipendMultiplier)
        #expect(cycles > 2 && cycles < 4,
                "a Freighter should take a few cycles, not one and not twenty — got \(cycles)")
    }

    @Test func partialDeliveryPaysPartially() {
        // Load 2.0 asks for twice what the colony can spare, so fill settles
        // well short of 1.0 and the payment has to follow it down.
        let state = fixedCadence()
        state.quotaLoad = 2.0
        reissueManifests(state)

        guard let quota = state.currentQuota else { return }
        run(state, ticks: quota.intervalTicks)

        guard let settled = state.settlementHistory.last else {
            Issue.record("nothing settled")
            return
        }
        #expect(settled.fill < 0.99, "precondition: the cycle should come in short, got \(settled.fill)")
        #expect(settled.stipend > 0, "a partial delivery should still be paid something")

        let full = GameState.stipendPerGameMinute
            * quota.intervalMinutes
            * StandingBand.indifferent.stipendMultiplier
        let expected = Int((full * settled.fill).rounded())
        #expect(settled.stipend == expected,
                "expected \(expected) for fill \(settled.fill), got \(settled.stipend)")
    }

    // MARK: - Receivership collects at the dock

    @Test func receivershipPaysNothingButStillTakesTheGoods() {
        let state = GameState.seeded()
        state.standing = Standing(reliability: 0.1, band: .receivership)
        state.quotaCadenceOverrideMinutes = QuotaGenerator.baseIntervalMinutes
        reissueManifests(state)

        guard let quota = state.currentQuota else { return }
        let before = state.credits
        run(state, ticks: quota.intervalTicks)

        guard let settled = state.settlementHistory.last else {
            Issue.record("nothing settled")
            return
        }
        #expect(state.credits == before, "Receivership paid \(state.credits - before)")
        #expect(settled.stipend == 0)

        // The goods left anyway — that is the whole point of the band.
        #expect(settled.fill > 0.99,
                "the Empire should have collected in full and paid nothing, fill was \(settled.fill)")
    }

    // MARK: - The band ladder means what it looks like

    /// Because the stipend is paid per shipment rather than per settlement,
    /// income per game-minute is exactly `stipendMultiplier`. Paid per
    /// settlement it would run 0 / 1.25 / 1.25 / 1.00 / 0.75 and Patron would
    /// earn 40% less per hour than Indifferent — the opposite of §4.1's "bonus
    /// stipend".
    @Test func incomePerGameMinuteRisesWithTheBand() {
        var rates: [(band: StandingBand, perMinute: Double)] = []

        for band in StandingBand.allCases {
            let cadence = QuotaGenerator.baseIntervalMinutes * band.cadenceMultiplier
            let payment = GameState.stipendPerGameMinute * cadence * band.stipendMultiplier
            rates.append((band, payment / cadence))
        }

        for (band, perMinute) in rates {
            let expected = GameState.stipendPerGameMinute * band.stipendMultiplier
            #expect(abs(perMinute - expected) < 1e-9,
                    "\(band.displayName) earns \(perMinute)/min, expected \(expected)")
        }

        let ordered = rates.map(\.perMinute)
        #expect(ordered == ordered.sorted(),
                "income per game-minute must rise with the band, got \(ordered)")
        #expect(ordered.first == 0, "Receivership must pay nothing")
    }

    @Test func theStipendReadoutMatchesWhatIsActuallyPaid() {
        let state = fixedCadence()
        let quoted = state.stipendForAMetQuota
        guard let quota = state.currentQuota else { return }

        run(state, ticks: quota.intervalTicks)
        guard let settled = state.settlementHistory.last else { return }
        #expect(settled.fill > 0.99, "precondition: a met cycle")
        #expect(settled.stipend == quoted,
                "the panel would have shown \(quoted), the Empire paid \(settled.stipend)")
    }

    // MARK: - S3's regression test

    /// **This is S3.** Twenty settled cycles from the seed state must leave the
    /// shipyard usable — not "affordable once", usable indefinitely.
    @Test func shipyardBecomesSustainable() {
        let state = GameState.seeded()
        let startingCredits = state.credits

        var cycles = 0
        while cycles < 20 {
            guard let quota = state.currentQuota else { break }
            let target = quota.dueAtTick
            while state.tickCount < target { state.tick() }
            cycles += 1
        }

        #expect(state.settlementHistory.count >= GameState.settlementHistoryLimit
                || state.settlementHistory.count == 20)

        let earned = state.credits - startingCredits
        #expect(earned >= ShipRole.freighter.buildCost.credits * 2,
                "twenty cycles earned \(earned), not the two Freighters (\(ShipRole.freighter.buildCost.credits * 2)) S3 asks for")

        // And the shipyard is genuinely usable: credits stop being the blocker.
        // Materials still are, which is correct — Refined Alloy is the
        // structural bottleneck, not money. HELIOS.md Appendix C.
        state.colonies[0].stock.deposit("refined-alloy", 200)
        state.colonies[0].stock.deposit("alloy-tools", 50)
        state.colonies[0].stock.deposit("power-cells", 100)
        #expect(state.queueShip(role: .freighter, name: "Regression"),
                "a freighter should be affordable after twenty settled cycles")
        #expect(state.queueShip(role: .freighter, name: "Regression II"),
                "and so should a second one — S3 was 'buy two ships and the shipyard is dead forever'")
    }

    // MARK: - Determinism and persistence

    @Test func stipendPaymentIsDeterministic() {
        let a = GameState.seeded()
        let b = GameState.seeded()
        for _ in 0..<1_000 {
            a.tick()
            b.tick()
        }
        #expect(a.credits == b.credits, "credits diverged: \(a.credits) vs \(b.credits)")
        #expect(a.settlementHistory.map(\.stipend) == b.settlementHistory.map(\.stipend),
                "payment history diverged")
    }

    @Test func paidStipendsSurviveARoundTrip() throws {
        let original = GameState.seeded()
        guard let quota = original.currentQuota else { return }
        run(original, ticks: quota.intervalTicks * 3)
        #expect(original.settlementHistory.contains { $0.stipend > 0 }, "precondition: something was paid")

        let data = try JSONEncoder().encode(original.snapshot)
        let restored = GameState(save: try JSONDecoder().decode(GameSave.self, from: data))

        #expect(restored.credits == original.credits)
        #expect(restored.settlementHistory == original.settlementHistory,
                "the payment archive did not survive the round trip")
    }

    // MARK: - Helper

    /// Re-issues both manifests from the colony as it currently stands, at the
    /// state's current cadence and load.
    private func reissueManifests(_ state: GameState) {
        let cadence = state.quotaCadenceMinutes
        let current = QuotaGenerator.generate(
            id: state.mintQuotaID(),
            colony: state.colonies[0],
            economyRate: GameState.economyRate,
            issuedAtTick: state.tickCount,
            intervalMinutes: cadence,
            load: state.quotaLoad
        )
        let next = QuotaGenerator.generate(
            id: state.mintQuotaID(),
            colony: state.colonies[0],
            economyRate: GameState.economyRate,
            issuedAtTick: current.dueAtTick,
            intervalMinutes: cadence,
            load: state.quotaLoad
        )
        state.currentQuota = current
        state.nextQuota = next
        state.ledger = .empty(for: current)
    }
}