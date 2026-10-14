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

    /// A fresh game sitting in `band`, with manifests issued at **that band's
    /// own cadence** — no override. Pinning the cadence to 240 regardless of
    /// band is exactly the decoupling that hid the per-shipment stipend from
    /// every test.
    ///
    /// Reliability sits mid-window, not a hair under the next threshold, so a
    /// test that runs more than one cycle doesn't promote by accident.
    private func atBand(_ band: StandingBand = .indifferent) -> GameState {
        let state = GameState.seeded()
        let i = band.rawValue
        let lower = i > 0 ? Standing.fallThresholds[i - 1] : 0
        let upper = i < Standing.riseThresholds.count ? Standing.riseThresholds[i] : 1
        state.standing = Standing(reliability: (lower + upper) / 2, band: band)
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
        let state = atBand()
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

    /// The stipend is paid per shipment, not per settlement: a real cycle at a
    /// band's own cadence pays `1.25 × cadence × stipendMultiplier`. Paid flat
    /// per settlement, income per game-minute would run 0 / 1.25 / 1.25 / 1.00
    /// / 0.75 and Patron would earn 40% less per hour than Indifferent — the
    /// opposite of §4.1's "bonus stipend". At 240 minutes the two models are
    /// indistinguishable, so these run at 600 and 168.
    @Test(arguments: [(StandingBand.patron, 600.0, 1_125), (.scrutinised, 168.0, 147)])
    func aMetShipmentIsPaidForTheCadenceItCovers(band: StandingBand, cadence: Double, expected: Int) {
        let state = atBand(band)
        guard let quota = state.currentQuota else { return }
        #expect(quota.intervalMinutes == cadence, "precondition: \(band.displayName) runs at \(cadence)")

        run(state, ticks: quota.intervalTicks)
        guard let settled = state.settlementHistory.last else {
            Issue.record("nothing settled")
            return
        }
        #expect(settled.fill > 0.99, "precondition: a met cycle, got \(settled.fill)")
        #expect(settled.stipend == expected,
                "\(band.displayName) at \(cadence) min paid \(settled.stipend), expected \(expected)")
    }

    /// The readout must quote the live manifest's window, not the band's new
    /// cadence. A fresh game promotes to Favourable at the first settlement
    /// while the promoted manifest keeps its 240-minute window — the case that
    /// overstated the payment by 50% (540 shown, 360 paid). Measured on a
    /// fixed cadence the two windows are equal and the bug is invisible.
    @Test func theStipendReadoutMatchesWhatIsActuallyPaid() {
        let state = GameState.seeded()
        guard let first = state.currentQuota else { return }
        run(state, ticks: first.intervalTicks)

        #expect(state.standing.band == .favourable, "precondition: the first settlement promotes")
        #expect(state.currentQuota?.intervalMinutes != state.quotaCadenceMinutes,
                "precondition: the live window and the band's cadence differ")

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