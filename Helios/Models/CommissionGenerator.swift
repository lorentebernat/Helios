//
//  CommissionGenerator.swift
//  Helios
//
//  Created by Bernat on 13/10/2026.
//


// CommissionGenerator.swift
// How one commission is written. Pure and deterministic, like QuotaGenerator:
// the same colony and the same id always produce the same contract.
//
// A commission is deliberately shaped unlike a quota. The quota is broad (every
// good the colony can spare), steady (paced across a long interval) and graded.
// A commission is narrow (three goods), short (half the current cadence) and
// pass-or-fail. Narrowness is the point: it concentrates demand on a few goods
// so meeting it is a decision about those goods rather than a general effort.
//
// SIZED FROM STORAGE HEADROOM, NOT FROM FLOW OR FROM CURRENT STOCK. Both
// alternatives were measured and both are degenerate:
//
// - Sized from *flow* (capacity × window × intensity), a commission is
//   unmeetable at quota load 1.0, because the quota already takes 100% of the
//   colony's capacity and there is nothing left to divert.
// - Sized from *current stock*, it is always met and it eats the entire buffer
//   in one go — measured, raw-ice 0.48 → 0.07 and alloy-tools 0.46 → 0.005 of
//   capacity — after which every later commission is worth nothing because the
//   buffer never regrows at load 1.0.
//
// Storage headroom is fixed, legible on the card before you accept, and
// independent of the moment you are offered it. Some commissions will be out
// of reach; that is what "ignoring is always safe" is for.

import Foundation

struct CommissionGenerator {

    /// Narrow by design.
    static let goodsPerCommission = 3

    /// Fraction of each good's storage headroom (capacity above any reserve
    /// floor) that the contract asks for.
    static let intensity: Double = 0.35

    /// Window as a fraction of the current quota cadence. Short, because a
    /// commission is a rush order.
    static let deadlineFraction: Double = 0.5

    /// A direct Standing bump on delivery, and a larger one subtracted on
    /// failure. The asymmetry is what makes accepting a genuine bet rather
    /// than free money, and therefore what makes ignoring a live option.
    static let standingReward: Double = 0.10
    static let standingPenalty: Double = 0.15

    /// Paid at a premium over the quota's rate for the same window: a
    /// commission covering half a cadence pays 1.5× what the quota would have
    /// paid over that half. Opt-in and harder, therefore better money.
    static let creditPremium: Double = 1.5

    /// Writes the next contract, or `nil` if the sector has nothing worth
    /// naming — an empty manifest, or goods with no storage headroom at all.
    ///
    /// Goods are chosen by a fixed rotation over the quota's own named goods,
    /// keyed on the commission id: varied across contracts, identical for the
    /// same id. No randomness inside the simulation step. HELIOS.md §18 S5.
    static func generate(
        id: Int,
        colony: Colony,
        against quota: Quota,
        offeredAtTick: Int,
        economyRate: Double,
        stipendPerGameMinute: Double
    ) -> Commission? {
        let candidates = quota.lines.keys.sorted()
        guard !candidates.isEmpty else { return nil }

        let offset = max(0, id - 1) * goodsPerCommission
        var lines: [Resource.ID: Double] = [:]
        for step in 0..<min(goodsPerCommission, candidates.count) {
            let good = candidates[(offset + step) % candidates.count]
            let headroom = storageHeadroom(of: good, in: colony.stock)
            let amount = (headroom * intensity * 10).rounded() / 10
            if amount > 0 { lines[good] = amount }
        }
        guard !lines.isEmpty else { return nil }

        let window = quota.intervalMinutes * deadlineFraction
        let ticks = QuotaGenerator.ticks(forInterval: window, economyRate: economyRate)

        return Commission(
            id: id,
            lines: lines,
            offeredAtTick: offeredAtTick,
            deadlineTick: offeredAtTick + ticks,
            windowMinutes: window,
            standingReward: standingReward,
            standingPenalty: standingPenalty,
            creditReward: Int((stipendPerGameMinute * window * creditPremium).rounded()),
            accepted: false
        )
    }

    /// Capacity the Empire could legitimately draw on: everything above a
    /// basic-need good's reserve floor, all of it for anything else. The same
    /// rule delivery itself obeys, so a contract can never ask for something
    /// the reserve floor forbids handing over.
    static func storageHeadroom(of good: Resource.ID, in stock: ColonyStock) -> Double {
        let capacity = stock.capacity(of: good)
        guard QuotaLedger.reservedGoods.contains(good) else { return capacity }
        return capacity * (1 - QuotaLedger.reserveFraction)
    }
}