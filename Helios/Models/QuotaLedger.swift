// QuotaLedger.swift
// What has actually left the docks against a demand — a quota, or an accepted
// commission. Same mechanism, one instance each.
//
// A LEDGER, NOT A SNAPSHOT — the single most important mechanical decision in
// this phase. Deliveries accumulate across the interval; the Empire never
// photographs your stores at the deadline.
//
// Snapshot settlement fails badly, and not subtly: because a snapshot can only
// take what you are *holding*, quota size is silently capped by storage
// capacity rather than by production. At a 960-minute interval the Power Cells
// line is 5,040 units against a 200-unit store — 25× everything the colony can
// physically hold, unmeetable at any level of industry. And because the
// interval lengthens as Standing improves, snapshot settlement would mean the
// better you play, the more impossible the quota becomes.
//
// Ledger delivery removes it completely. Measured over 5,000 ticks at load 1.0,
// stores, population and every chain throughput are identical to four decimal
// places at intervals of 60, 240, 960 and 2,880 game-minutes, and every cycle
// settles at fill 1.0000. HELIOS.md §4.2.
//
// This type holds deliveries and nothing else. Pacing belongs to `Quota`, which
// owns the tick window, and the clock belongs to `GameState.tickCount`. An
// earlier version carried its own `elapsedMinutes` — a second measure of the
// same thing, which is the shape of §18 S7.
//
// `deliver(_:_:)` is the ONE way goods enter a ledger. Phase 3 makes cargo real
// and delivery becomes "a freighter arrived": it swaps the caller and touches
// nothing else — not settlement, not Standing, not the UI.

import Foundation

struct QuotaLedger: Codable, Hashable {

    /// Which demand these deliveries belong to. Holds a `Quota.id` on the quota
    /// ledger and a `Commission.id` on a commission's; a ledger whose id does
    /// not match what is being collected on is stale and gets reset, never
    /// reused.
    var quotaID: Int

    /// Cumulative delivered amount per good. Monotonic within a cycle.
    var delivered: [Resource.ID: Double]

    init(quotaID: Int, delivered: [Resource.ID: Double] = [:]) {
        self.quotaID = quotaID
        self.delivered = delivered
    }

    static func empty(for quota: Quota?) -> QuotaLedger {
        QuotaLedger(quotaID: quota?.id ?? 0)
    }

    /// A commission's ledger. The mechanism is identical; only the thing being
    /// delivered against differs.
    static func empty(forCommission commission: Commission?) -> QuotaLedger {
        QuotaLedger(quotaID: commission?.id ?? 0)
    }

    // MARK: - The delivery seam

    /// The narrow entry point Phase 3 is built around. Everything that puts
    /// goods against a demand goes through here.
    mutating func deliver(_ good: Resource.ID, _ amount: Double) {
        guard amount > 0 else { return }
        delivered[good, default: 0] += amount
    }

    func amountDelivered(of good: Resource.ID) -> Double {
        delivered[good] ?? 0
    }

    mutating func reset(for quota: Quota?) {
        quotaID = quota?.id ?? 0
        delivered = [:]
    }

    // MARK: - What may move right now

    /// The schedule allowance, capped by the line total, less what has already
    /// gone. Zero once the line is complete, which is why settlement has to
    /// start a new cycle — otherwise the Empire stops collecting and the colony
    /// saturates. See `GameState.settleQuotaIfDue()`.
    func collectableNow(of good: Resource.ID, against quota: Quota, atTick tick: Int) -> Double {
        let ceiling = min(quota.scheduledAmount(of: good, atTick: tick), quota.amount(of: good))
        return max(0, ceiling - amountDelivered(of: good))
    }

    /// What is still owed on a line of any size. A commission is delivered as
    /// fast as the colony can manage rather than paced across its window — it
    /// is a rush order — so it needs the amount outstanding and nothing else.
    func outstanding(of good: Resource.ID, owed: Double) -> Double {
        max(0, owed - amountDelivered(of: good))
    }

    /// What is still owed on a quota line, regardless of schedule.
    func outstanding(of good: Resource.ID, against quota: Quota) -> Double {
        outstanding(of: good, owed: quota.amount(of: good))
    }

    // MARK: - The reserve floor: colonists eat first

    /// Basic-need goods may never be drawn below this fraction of capacity.
    ///
    /// Measured over 5,000 ticks at a 240-minute interval: without the floor,
    /// load 3.0 ends with 108 colonists instead of 206, and load 4.0 ends with
    /// **zero** instead of 101. It costs deliveries to do it — fill at load 3.0
    /// is 0.456 with the floor against 0.750 without — and that is the trade.
    ///
    /// The floor binds the **Empire**, not the colonists. `Population.applyTick`
    /// runs before production and before delivery, so colonists draw first and
    /// are not floor-limited; they must not be, or they would starve with food
    /// in the warehouse.
    ///
    /// Note it protects *basic* needs only. Luxuries stay contested on purpose:
    /// above load 1.0 the Empire takes the Alloy Tools the Settlers want, which
    /// blocks promotion. That contest is the intended squeeze, with the player
    /// holding the output-% lever that resolves it. HELIOS.md §4.2.
    static let reserveFraction: Double = 0.3

    /// Derived from `ColonistTier.basicNeeds` rather than hand-listed. DebugSink
    /// hard-coded `{oxygen, ration-bars, water}`; this computes the same set
    /// today and stays correct when tiers 3–5 get their needs in Phase 5.
    static let reservedGoods: Set<Resource.ID> = Set(
        ColonistTier.allCases.flatMap { $0.basicNeeds.map(\.resourceID) }
    )

    /// How much of `good` the dock may take from `stock` without crossing the
    /// reserve floor. Applies to a commission exactly as it does to a quota —
    /// an optional contract is not a licence to take the colonists' food.
    static func drawable(_ good: Resource.ID, from stock: ColonyStock) -> Double {
        guard reservedGoods.contains(good) else { return stock.amount(of: good) }
        let floor = stock.capacity(of: good) * reserveFraction
        return max(0, stock.amount(of: good) - floor)
    }
}
