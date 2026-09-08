//
//  QuotaSettlementTests.swift
//  HeliosTests
//
//  Phase 2 Steps 4–5.
//

// Settlement, the tick counter that drives it, and the promise that the next
// manifest is always visible.
//
// Tests that count cycles pin the cadence: from Step 5 the Standing band sets
// it, and a perfectly delivering colony is promoted twice in the first two
// cycles, so an unpinned cadence goes 240 → 360 → 600 mid-measurement.
// `theCadenceFollowsTheBandWhenNotPinned` covers that on purpose.

import Testing
import Foundation
@testable import Helios

@Suite("Quota settlement")
struct QuotaSettlementTests {

    private func run(_ state: GameState, ticks: Int) {
        for _ in 0..<ticks { state.tick() }
    }

    /// A fresh game with the cadence held at the Indifferent figure.
    private func fixedCadence() -> GameState {
        let state = GameState.seeded()
        state.quotaCadenceOverrideMinutes = QuotaGenerator.baseIntervalMinutes
        return state
    }

    // MARK: - The clock

    @Test func tickCountIsTheClock() {
        let state = GameState.seeded()
        #expect(state.tickCount == 0, "a fresh game starts at tick zero")

        run(state, ticks: 137)
        #expect(state.tickCount == 137, "tickCount should be exactly the number of ticks applied")
    }

    @Test func settlementHappensExactlyOnTheDeadlineTick() {
        let state = GameState.seeded()
        guard let quota = state.currentQuota else { return }

        run(state, ticks: quota.dueAtTick - 1)
        #expect(state.settlementHistory.isEmpty,
                "settled early, at tick \(state.tickCount) against a deadline of \(quota.dueAtTick)")
        #expect(state.currentQuota?.id == quota.id)

        state.tick()
        #expect(state.settlementHistory.count == 1, "did not settle on its deadline tick")
        #expect(state.settlementHistory.last?.settledAtTick == quota.dueAtTick)
    }

    /// Cadence in game-minutes becomes ticks once, in `QuotaGenerator`, so a
    /// deadline is an integer comparison and never a `Date`.
    @Test func cyclesRunAtTheirNominalCadence() {
        let state = fixedCadence()
        guard let quota = state.currentQuota else { return }
        let interval = quota.intervalTicks

        run(state, ticks: interval * 5)
        #expect(state.settlementHistory.count == 5,
                "expected five cycles in \(interval * 5) ticks, got \(state.settlementHistory.count)")
        for (i, settlement) in state.settlementHistory.enumerated() {
            #expect(settlement.settledAtTick == interval * (i + 1),
                    "cycle \(i + 1) settled at tick \(settlement.settledAtTick), expected \(interval * (i + 1))")
        }
    }

    /// Unpinned, the cadence follows Standing — and a perfect run stretches it.
    /// The first cycle runs 240 ticks at Indifferent, then the band promotes and
    /// the announced manifest carries 360, then 600 at Patron.
    @Test func theCadenceFollowsTheBandWhenNotPinned() {
        let state = GameState.seeded()
        run(state, ticks: 240 + 240 + 360)

        let ticks = state.settlementHistory.map(\.settledAtTick)
        #expect(ticks == [240, 480, 840],
                "expected settlements at 240/480/840 as the cadence stretches, got \(ticks)")
        #expect(state.standing.band == .patron)
        #expect(state.quotaCadenceMinutes == 600)
    }

    // MARK: - The next manifest is a promise, not a surprise

    /// A quota you cannot see coming is a dice roll, not a decision — the player
    /// always has one full interval to retool. HELIOS.md §4.2.
    @Test func nextQuotaIsAlwaysVisible() {
        let state = GameState.seeded()
        #expect(state.nextQuota != nil, "a fresh game must already announce the following cycle")

        for _ in 0..<1_200 {
            state.tick()
            #expect(state.nextQuota != nil, "nextQuota went nil at tick \(state.tickCount)")
            guard let current = state.currentQuota, let next = state.nextQuota else { continue }
            #expect(next.issuedAtTick == current.dueAtTick,
                    "the announced quota starts at tick \(next.issuedAtTick) but the current one ends at \(current.dueAtTick)")
            #expect(next.id > current.id, "the announced quota should be the newer one")
        }
    }

    @Test func settlementAdvancesToTheAnnouncedQuota() {
        let state = GameState.seeded()
        guard let quota = state.currentQuota, let announced = state.nextQuota else {
            Issue.record("seeded state is missing a quota")
            return
        }

        run(state, ticks: quota.dueAtTick)

        #expect(state.currentQuota == announced,
                "the promoted quota is not the one that was announced")
        #expect(state.ledger.quotaID == announced.id, "the ledger did not follow the promotion")
        #expect(state.ledger.delivered.isEmpty, "the ledger carried deliveries into the new cycle")
        #expect(state.nextQuota?.id != announced.id, "a new successor should have been announced")
    }

    // MARK: - Fill

    /// Normalised per line, so a 1,260-unit line and a 36-unit line count
    /// equally — otherwise Power Cells would drown out Ration Bars and the
    /// manifest's breadth would stop meaning anything.
    @Test func fillIsNormalisedPerLine() {
        let quota = Quota(
            id: 1,
            lines: ["power-cells": 1_000, "ration-bars": 10],
            intervalMinutes: 240,
            issuedAtTick: 0,
            dueAtTick: 240
        )

        // The huge line met, the tiny one missed entirely: fill must be 0.5,
        // not 0.99.
        var ledger = QuotaLedger(quotaID: 1)
        ledger.deliver("power-cells", 1_000)
        #expect(abs(quota.fill(from: ledger) - 0.5) < 1e-9,
                "expected 0.5, got \(quota.fill(from: ledger))")

        // And the mirror image.
        var mirror = QuotaLedger(quotaID: 1)
        mirror.deliver("ration-bars", 10)
        #expect(abs(quota.fill(from: mirror) - 0.5) < 1e-9,
                "expected 0.5, got \(quota.fill(from: mirror))")
    }

    @Test func fillNeverExceedsOne() {
        let quota = Quota(
            id: 1, lines: ["power-cells": 100], intervalMinutes: 240,
            issuedAtTick: 0, dueAtTick: 240
        )
        var ledger = QuotaLedger(quotaID: 1)
        ledger.deliver("power-cells", 500)
        #expect(quota.fill(from: ledger) == 1, "over-delivery should not pay above 1.0")
    }

    @Test func metCyclesArchiveTheirLineFills() {
        let state = GameState.seeded()
        guard let quota = state.currentQuota else { return }
        run(state, ticks: quota.dueAtTick)

        guard let settled = state.settlementHistory.last else {
            Issue.record("nothing settled")
            return
        }
        #expect(settled.lineFills.count == quota.lineCount,
                "the archive should record every line, got \(settled.lineFills.count) of \(quota.lineCount)")
        #expect(settled.wasMet, "a load-1.0 cycle should come in met, got fill \(settled.fill)")
        #expect(settled.shortfalls.isEmpty, "a met cycle should report no shortfalls")
    }

    @Test func historyIsCappedAndKeepsTheNewest() {
        let state = fixedCadence()
        guard let quota = state.currentQuota else { return }
        let cycles = GameState.settlementHistoryLimit + 5
        run(state, ticks: quota.intervalTicks * cycles)

        #expect(state.settlementHistory.count == GameState.settlementHistoryLimit,
                "history should cap at \(GameState.settlementHistoryLimit), got \(state.settlementHistory.count)")
        #expect(state.settlementHistory.last?.settledAtTick == quota.intervalTicks * cycles,
                "the newest settlement should be the last one")
        let ticks = state.settlementHistory.map(\.settledAtTick)
        #expect(ticks == ticks.sorted(), "history should be oldest-first")
    }

    // MARK: - Persistence

    /// Force-quit mid-cycle and relaunch: same quota, same ledger, same
    /// deadline, same announced successor, same Standing — and it settles on the
    /// same tick with the same manifest.
    @Test func quotaStateSurvivesARoundTrip() throws {
        let original = GameState.seeded()
        guard let firstQuota = original.currentQuota else { return }

        // Past one settlement and partway into the next cycle, so every field
        // under test is non-trivial.
        run(original, ticks: firstQuota.intervalTicks + firstQuota.intervalTicks / 3)
        #expect(original.settlementHistory.count == 1, "precondition: one cycle settled")

        let data = try JSONEncoder().encode(original.snapshot)
        let restored = GameState(save: try JSONDecoder().decode(GameSave.self, from: data))

        #expect(restored.tickCount == original.tickCount, "tickCount did not survive")
        #expect(restored.standing == original.standing, "standing did not survive")
        #expect(restored.currentQuota == original.currentQuota, "currentQuota did not survive")
        #expect(restored.nextQuota == original.nextQuota, "nextQuota did not survive")
        #expect(restored.ledger == original.ledger, "ledger did not survive")
        #expect(restored.settlementHistory == original.settlementHistory, "history did not survive")
        #expect(restored.nextQuotaSerial == original.nextQuotaSerial, "the id source did not survive")

        // And the restored game settles at the same tick, on the same manifest.
        guard let deadline = original.currentQuota?.dueAtTick else { return }
        let toDeadline = deadline - original.tickCount
        run(original, ticks: toDeadline)
        run(restored, ticks: toDeadline)

        #expect(original.settlementHistory.last == restored.settlementHistory.last,
                "the restored game settled differently")
        #expect(original.currentQuota == restored.currentQuota,
                "the restored game promoted a different manifest")
        #expect(original.standing == restored.standing, "standing diverged after the round trip")
        for id in Resource.all.map(\.id) {
            #expect(original.colonies[0].stock.amount(of: id) == restored.colonies[0].stock.amount(of: id),
                    "stock diverged for \(id) after the round trip")
        }
    }

    @Test func settlementRecordRoundTripsThroughCodable() throws {
        let record = QuotaSettlement(
            quotaID: 7,
            settledAtTick: 1_680,
            fill: 0.8125,
            lineFills: ["power-cells": 1.0, "water": 0.25]
        )
        let data = try JSONEncoder().encode(record)
        #expect(try JSONDecoder().decode(QuotaSettlement.self, from: data) == record)
    }

    // MARK: - Determinism, still

    /// The property Phase 4's replay and Phase 9's reconciliation rest on, now
    /// with settlement, promotion, Standing and generation inside the loop.
    @Test func settlementIsDeterministic() {
        let a = GameState.seeded()
        let b = GameState.seeded()

        for _ in 0..<1_000 {
            a.tick()
            b.tick()
        }

        #expect(a.tickCount == b.tickCount)
        #expect(a.standing == b.standing, "standing diverged")
        #expect(a.currentQuota == b.currentQuota, "current manifests diverged")
        #expect(a.nextQuota == b.nextQuota, "announced manifests diverged")
        #expect(a.ledger == b.ledger, "ledgers diverged")
        #expect(a.settlementHistory == b.settlementHistory, "settlement archives diverged")
        #expect(a.nextQuotaSerial == b.nextQuotaSerial, "quota id sources diverged")
    }
}
