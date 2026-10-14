//
//  CommissionTests.swift
//  Helios
//
//  Created by Bernat on 13/10/2026.
//


//
//  CommissionTests.swift
//  HeliosTests
//
//  Phase 2 Step 7.
//

// The three-way asymmetry that makes an opt-in contract work: ignoring costs
// nothing, delivering repairs Standing, accepting-and-failing costs more than
// never accepting.

import Testing
import Foundation
@testable import Helios

@Suite("Commissions")
struct CommissionTests {

    private func run(_ state: GameState, ticks: Int) {
        for _ in 0..<ticks { state.tick() }
    }

    /// Runs until a contract is on offer, at a fixed cadence so the window is
    /// predictable.
    private func withCommissionOffered() -> GameState {
        let state = GameState.seeded()
        state.quotaCadenceOverrideMinutes = QuotaGenerator.baseIntervalMinutes
        guard let quota = state.currentQuota else { return state }
        run(state, ticks: quota.intervalTicks)   // the first settlement posts one
        return state
    }

    /// Fills every store to capacity, so a contract is comfortably meetable and
    /// the test measures the mechanism rather than the balance.
    private func stockUp(_ state: GameState) {
        for resource in Resource.all {
            state.colonies[0].stock.deposit(resource.id, resource.capacity)
        }
    }

    /// Empties everything the Empire could draw on, so an accepted contract is
    /// certain to fail.
    private func stripStores(_ state: GameState) {
        for resource in Resource.all {
            state.colonies[0].stock.drain(resource.id, resource.capacity)
        }
    }

    // MARK: - It exists, and one at a time

    @Test func aCommissionIsPostedAtSettlement() {
        let state = withCommissionOffered()
        guard let contract = state.commission else {
            Issue.record("no commission was posted at the first settlement")
            return
        }
        #expect(contract.accepted == false, "a contract must arrive un-accepted")
        #expect(contract.lineCount <= CommissionGenerator.goodsPerCommission)
        #expect(contract.lineCount >= 1)
        #expect(contract.deadlineTick > state.tickCount)
        #expect(contract.creditReward > 0)
    }

    /// Narrow where the quota is broad. That contrast is most of what makes the
    /// two feel like different demands rather than two sizes of the same one.
    @Test func aCommissionIsNarrowerThanTheQuota() {
        let state = withCommissionOffered()
        guard let contract = state.commission, let quota = state.currentQuota else { return }
        #expect(contract.lineCount < quota.lineCount,
                "contract named \(contract.lineCount) goods against a manifest of \(quota.lineCount)")
        #expect(contract.windowMinutes < quota.intervalMinutes,
                "a rush order should be due sooner than the quota it sits alongside")
    }

    @Test func onlyOneCommissionIsOfferedAtATime() {
        let state = withCommissionOffered()
        guard let first = state.commission, let quota = state.currentQuota else { return }

        // Watch every tick across several settlements. A new id may appear only
        // once the previous contract's deadline has passed — sampling a single
        // later tick can't tell "replaced early" from "closed, then reposted".
        var open = first
        var replacements = 0
        for _ in 0..<(quota.intervalTicks * 3) {
            state.tick()
            guard let now = state.commission, now.id != open.id else { continue }
            #expect(state.tickCount >= open.deadlineTick,
                    "contract \(now.id) posted at tick \(state.tickCount) while \(open.id) was open until \(open.deadlineTick)")
            open = now
            replacements += 1
        }
        #expect(replacements > 0, "no later contract was ever posted, so nothing was checked")
    }

    @Test func commissionGenerationIsDeterministic() {
        let a = withCommissionOffered()
        let b = withCommissionOffered()
        #expect(a.commission == b.commission, "two identical games wrote different contracts")
    }

    // MARK: - Ignoring is always safe

    @Test func ignoringACommissionCostsNothing() {
        let state = withCommissionOffered()
        guard let contract = state.commission else { return }

        let standingBefore = state.standing
        let creditsBefore = state.credits

        // Never accepted. Run past the deadline without touching it.
        while state.tickCount < contract.deadlineTick { state.tick() }

        #expect(state.lastCommissionOutcome == .ignored)
        #expect(state.standing.reliability == standingBefore.reliability,
                "ignoring moved reliability from \(standingBefore.reliability) to \(state.standing.reliability)")
        #expect(state.standing.band == standingBefore.band)
        #expect(state.credits == creditsBefore, "ignoring changed credits")
    }

    // MARK: - Delivering pays

    @Test func deliveringACommissionPaysCreditsAndStanding() {
        let state = withCommissionOffered()
        state.standing = Standing(reliability: 0.60, band: .scrutinised)
        stockUp(state)

        guard let contract = state.commission else { return }
        #expect(state.acceptCommission())

        let creditsBefore = state.credits
        while state.tickCount < contract.deadlineTick { state.tick() }

        #expect(state.lastCommissionOutcome == .delivered,
                "a fully stocked colony should have met it, got \(String(describing: state.lastCommissionOutcome))")
        #expect(state.credits >= creditsBefore + contract.creditReward,
                "expected at least \(contract.creditReward) credits for the contract")
        #expect(state.standing.reliability > 0.60,
                "delivering should repair Standing, reliability is \(state.standing.reliability)")
    }

    /// The reconciliation path: the way out of a bad band is to volunteer for
    /// something and deliver it. HELIOS.md §4.3.
    @Test func commissionsCanLiftYouOutOfScrutinised() {
        let state = withCommissionOffered()
        state.standing = Standing(reliability: 0.70, band: .scrutinised)
        stockUp(state)

        guard let contract = state.commission else { return }
        #expect(state.acceptCommission())
        while state.tickCount < contract.deadlineTick { state.tick() }

        #expect(state.lastCommissionOutcome == .delivered)
        #expect(state.standing.band == .indifferent,
                "a delivered contract from 0.70 should clear the 0.75 rise threshold, band is \(state.standing.band.displayName)")
    }

    // MARK: - Accepting and failing costs more than never accepting

    /// **The asymmetry the whole mechanic rests on.** Two identical games, one
    /// accepts a contract it cannot meet and one ignores it.
    @Test func failingAnAcceptedCommissionCostsMoreThanIgnoringIt() {
        let bold = withCommissionOffered()
        let cautious = withCommissionOffered()
        #expect(bold.commission == cautious.commission, "precondition: the same contract")

        guard let contract = bold.commission else { return }

        stripStores(bold)
        stripStores(cautious)
        #expect(bold.acceptCommission())

        let startingReliability = bold.standing.reliability
        while bold.tickCount < contract.deadlineTick { bold.tick() }
        while cautious.tickCount < contract.deadlineTick { cautious.tick() }

        #expect(bold.lastCommissionOutcome == .failed)
        #expect(cautious.lastCommissionOutcome == .ignored)
        #expect(bold.standing.reliability < cautious.standing.reliability,
                "failing (\(bold.standing.reliability)) should cost more than ignoring (\(cautious.standing.reliability))")
        #expect(bold.standing.reliability < startingReliability)
    }

    /// On the contract itself, not the generator's statics: resolution reads
    /// the contract's fields, so swapping them at the call site has to show.
    @Test func failingCostsMoreThanDeliveringPays() {
        let state = withCommissionOffered()
        guard let contract = state.commission else {
            Issue.record("no commission was posted")
            return
        }
        #expect(contract.standingPenalty > contract.standingReward,
                "if the reward matched the penalty, accepting everything would be free and ignoring would be a dominated choice")
    }

    // MARK: - Pass or fail, not graded

    @Test func aNearMissPaysNothing() {
        let state = withCommissionOffered()
        stockUp(state)
        guard let contract = state.commission else { return }

        // Freeze everything that could close the gap during the window. Left
        // running, the colony simply produces the missing unit and the "near
        // miss" is delivered — which is how this test was committed red.
        for i in state.colonies[0].productionChains.indices {
            state.colonies[0].productionChains[i].outputPercent = 0
        }
        state.currentQuota = nil   // nor may the quota compete for the same stores
        state.nextQuota = nil

        // Short a good nobody eats, so population can't widen the gap either.
        let eaten = Set(ColonistTier.allCases.flatMap {
            ($0.basicNeeds + $0.luxuryNeeds).map(\.resourceID)
        })
        guard let shortGood = contract.sortedLines.first(where: { !eaten.contains($0.good) })?.good else {
            Issue.record("contract names only goods the colonists eat: \(contract.sortedLines.map(\.good))")
            return
        }
        #expect(state.acceptCommission())

        // Not a reserved good (it isn't eaten), so all of it is drawable.
        let keep = contract.amount(of: shortGood) - 1
        let held = state.colonies[0].stock.amount(of: shortGood)
        if held > keep { state.colonies[0].stock.drain(shortGood, held - keep) }

        let creditsBefore = state.credits
        let reliabilityBefore = state.standing.reliability
        while state.tickCount < contract.deadlineTick { state.tick() }

        #expect(state.lastCommissionOutcome == .failed,
                "a contract one unit short is failed, not partly paid")
        #expect(state.credits == creditsBefore, "a near miss paid credits")
        #expect(state.standing.reliability < reliabilityBefore)
    }

    // MARK: - It never sabotages the quota, and never touches the reserve

    /// The mandatory demand collects before the optional one, every tick.
    @Test func theQuotaCollectsBeforeTheCommission() {
        let withContract = GameState.seeded()
        let without = GameState.seeded()
        withContract.quotaCadenceOverrideMinutes = QuotaGenerator.baseIntervalMinutes
        without.quotaCadenceOverrideMinutes = QuotaGenerator.baseIntervalMinutes

        guard let quota = withContract.currentQuota else { return }
        run(withContract, ticks: quota.intervalTicks)
        run(without, ticks: quota.intervalTicks)
        withContract.acceptCommission()

        run(withContract, ticks: quota.intervalTicks * 3)
        run(without, ticks: quota.intervalTicks * 3)

        // Equality, not `<=`: the defect is a commission *stealing* from the
        // quota, which lowers its fill — and lower would pass a `<=`.
        let contractFills = withContract.settlementHistory.map(\.fill)
        let plainFills = without.settlementHistory.map(\.fill)
        #expect(contractFills.count == plainFills.count && !plainFills.isEmpty)
        for (i, fill) in contractFills.enumerated() where i < plainFills.count {
            #expect(abs(fill - plainFills[i]) < 1e-9,
                    "cycle \(i): the quota filled \(fill) with a commission running against \(plainFills[i]) without — it must collect first")
        }
    }

    /// Starts with every reserved good a few units above its floor, against a
    /// contract asking far more than that — the case where the floor actually
    /// has to hold. (A fully stocked fixture left 45 points of slack, so the
    /// property could not be violated.) The quota is removed so it can't take
    /// the drawable sliver first and leave the commission nothing to test.
    @Test func commissionsNeverBreachTheReserveFloor() {
        let state = withCommissionOffered()
        guard let contract = state.commission else { return }
        state.currentQuota = nil
        state.nextQuota = nil

        let reservedLines = contract.sortedLines.filter { QuotaLedger.reservedGoods.contains($0.good) }
        #expect(!reservedLines.isEmpty, "precondition: the contract names a reserved good")
        for good in QuotaLedger.reservedGoods {
            let stock = state.colonies[0].stock
            let target = stock.capacity(of: good) * QuotaLedger.reserveFraction + 3
            stock.amount(of: good) > target
                ? state.colonies[0].stock.drain(good, stock.amount(of: good) - target)
                : state.colonies[0].stock.deposit(good, target - stock.amount(of: good))
        }
        for line in reservedLines {
            #expect(line.amount > 3, "precondition: \(line.good) asks more than is drawable")
        }
        #expect(state.acceptCommission())

        var previous = [Resource.ID: Double]()
        var checked = 0
        while state.tickCount < contract.deadlineTick {
            state.tick()
            guard state.commission != nil else { break }   // resolved on the deadline tick
            for good in QuotaLedger.reservedGoods {
                let stock = state.colonies[0].stock
                let amount = stock.amount(of: good)
                let floor = stock.capacity(of: good) * QuotaLedger.reserveFraction
                let now = state.commissionLedger.amountDelivered(of: good)
                if now > (previous[good] ?? 0) + 1e-9 {
                    checked += 1
                    #expect(amount >= floor - 1e-6,
                            "a commission took \(good) and left \(amount), below its floor of \(floor)")
                }
                previous[good] = now
            }
        }
        #expect(checked > 0, "the commission never took a reserved good, so nothing was checked")
    }

    /// Reserved goods are sized from the capacity *above the floor*, not from
    /// the whole tank. Bounded against the floor directly: if headroom forgot
    /// it, a reserved line would come out at `intensity × capacity`, which is
    /// what this rules out. Ids 1–6 rotate through every eligible good.
    @Test func contractsAreSizedWithinTheDrawableHeadroom() {
        let state = withCommissionOffered()
        guard let quota = state.currentQuota else { return }
        let colony = state.colonies[0]

        var reservedSeen = 0
        for id in 1...6 {
            guard let contract = CommissionGenerator.generate(
                id: id, colony: colony, against: quota, offeredAtTick: 0,
                economyRate: GameState.economyRate,
                stipendPerGameMinute: GameState.stipendPerGameMinute
            ) else { continue }

            for line in contract.sortedLines {
                let capacity = colony.stock.capacity(of: line.good)
                let floor = QuotaLedger.reservedGoods.contains(line.good)
                    ? capacity * QuotaLedger.reserveFraction : 0
                if floor > 0 { reservedSeen += 1 }
                let ceiling = CommissionGenerator.intensity * (capacity - floor) + 0.05   // one-decimal rounding
                #expect(line.amount <= ceiling,
                        "\(line.good): asks \(line.amount), headroom above the floor allows \(ceiling)")
            }
        }
        #expect(reservedSeen > 0, "no contract named a reserved good, so the floor was never checked")
    }

    // MARK: - Accepting is a commitment

    @Test func acceptingIsIrreversibleAndIdempotent() {
        let state = withCommissionOffered()
        #expect(state.acceptCommission(), "the first acceptance should take")
        #expect(state.acceptCommission() == false, "accepting twice should be a no-op")
        #expect(state.commission?.accepted == true)
    }

    @Test func acceptingWithNothingOnOfferDoesNothing() {
        let state = GameState.seeded()
        #expect(state.commission == nil, "precondition: nothing on offer yet")
        #expect(state.acceptCommission() == false)
    }

    // MARK: - Persistence and determinism

    @Test func commissionStateSurvivesARoundTrip() throws {
        let original = withCommissionOffered()
        original.acceptCommission()
        run(original, ticks: 20)

        let data = try JSONEncoder().encode(original.snapshot)
        let restored = GameState(save: try JSONDecoder().decode(GameSave.self, from: data))

        #expect(restored.commission == original.commission, "the contract did not survive")
        #expect(restored.commissionLedger == original.commissionLedger, "its ledger did not survive")
        #expect(restored.nextCommissionSerial == original.nextCommissionSerial)
        #expect(restored.lastCommissionOutcome == original.lastCommissionOutcome)

        guard let deadline = original.commission?.deadlineTick else { return }
        while original.tickCount < deadline { original.tick() }
        while restored.tickCount < deadline { restored.tick() }
        #expect(original.lastCommissionOutcome == restored.lastCommissionOutcome,
                "the restored game resolved the contract differently")
        #expect(original.credits == restored.credits)
        #expect(original.standing == restored.standing)
    }

    @Test func commissionsAreDeterministic() {
        let a = GameState.seeded()
        let b = GameState.seeded()
        for _ in 0..<1_200 {
            a.tick()
            b.tick()
            if a.commission != nil { a.acceptCommission() }
            if b.commission != nil { b.acceptCommission() }
        }
        #expect(a.commission == b.commission, "contracts diverged")
        #expect(a.commissionLedger == b.commissionLedger, "contract ledgers diverged")
        #expect(a.standing == b.standing, "standing diverged")
        #expect(a.credits == b.credits, "credits diverged")
        #expect(a.nextCommissionSerial == b.nextCommissionSerial)
    }

    // MARK: - No new currency

    /// Commissions pay Standing and credits. Favour waits for Phase 5, where
    /// Dispensations give it a sink — a currency with a source and no sink is
    /// exactly how credits became S3.
    @Test func commissionsPayNoFavour() {
        let state = withCommissionOffered()
        guard let contract = state.commission else { return }
        #expect(contract.creditReward > 0)
        #expect(contract.standingReward > 0)
        // If a Favour field ever appears on Commission, this test should be the
        // thing that makes someone stop and check §4.4 first.
        #expect(Mirror(reflecting: contract).children.allSatisfy {
            ($0.label ?? "").lowercased().contains("favour") == false
        }, "Favour arrived early — see HELIOS.md §4.4 and §18 S3")
    }
}