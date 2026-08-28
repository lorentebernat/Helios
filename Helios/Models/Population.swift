// Population.swift
// The colony's population across the tier ladder. Consumption is allocated
// proportionally across tiers, so no tier starves another by array order.

import Foundation

struct Population {
    var tiers: [TierPopulation]

    // Tuning
    static let growthPerMin: Double = 3.0
    static let declinePerMin: Double = 6.0            // scaled by shortfall
    static let unhappyAttritionPerMin: Double = 0.5   // scaled by discontent
    static let promotionPerMin: Double = 2.0

    var total: Double { tiers.reduce(0) { $0 + $1.count } }

    func state(for tier: ColonistTier) -> TierPopulation? {
        tiers.first { $0.tier == tier }
    }

    /// Progressive reveal: every active tier, plus the single next rung (locked).
    var visibleTiers: [TierPopulation] {
        let active = tiers.filter(\.isActive)
        guard let highest = active.last, let upcoming = highest.tier.next else { return active }
        if let lockedRow = tiers.first(where: { $0.tier == upcoming }) {
            return active + [lockedRow]
        }
        return active
    }

    mutating func applyTick(stock: inout ColonyStock, minutesPerTick: Double) {
        resolveNeeds(stock: &stock, minutesPerTick: minutesPerTick)
        for i in tiers.indices {
            tiers[i].applyOutcome(minutesPerTick: minutesPerTick)
        }
        applyPromotions(minutesPerTick: minutesPerTick)
    }

    /// Two passes, mirroring ProductionAllocator: aggregate demand, then share
    /// what exists in proportion to it.
    private mutating func resolveNeeds(stock: inout ColonyStock, minutesPerTick: Double) {
        var demand: [Resource.ID: Double] = [:]

        for t in tiers where t.count > 0 {
            for need in t.tier.basicNeeds + t.tier.luxuryNeeds {
                demand[need.resourceID, default: 0] += t.demand(for: need, minutesPerTick: minutesPerTick)
            }
        }

        var ratio: [Resource.ID: Double] = [:]
        for (id, wanted) in demand {
            ratio[id] = wanted <= 0 ? 1 : min(1, stock.amount(of: id) / wanted)
        }

        for i in tiers.indices {
            guard tiers[i].count > 0 else {
                tiers[i].basicSatisfaction = 1
                tiers[i].happiness = 1
                continue
            }

            // Basic — the tightest need binds.
            var satisfaction = 1.0
            for need in tiers[i].tier.basicNeeds {
                let want = tiers[i].demand(for: need, minutesPerTick: minutesPerTick)
                guard want > 0 else { continue }
                let share = ratio[need.resourceID] ?? 1
                satisfaction = min(satisfaction, share)
                stock.drain(need.resourceID, want * share)
            }
            tiers[i].basicSatisfaction = satisfaction

            // Luxury — happiness is the mean across luxuries, since comfort is
            // cumulative rather than gated by the worst item.
            let luxuries = tiers[i].tier.luxuryNeeds
            if luxuries.isEmpty {
                tiers[i].happiness = 1
            } else {
                var sum = 0.0
                for need in luxuries {
                    let want = tiers[i].demand(for: need, minutesPerTick: minutesPerTick)
                    let share = want > 0 ? (ratio[need.resourceID] ?? 1) : 1
                    sum += share
                    stock.drain(need.resourceID, want * share)
                }
                tiers[i].happiness = sum / Double(luxuries.count)
            }
        }
    }

    /// Highest rung first, so nobody promotes twice in one tick.
    private mutating func applyPromotions(minutesPerTick: Double) {
        for i in tiers.indices.reversed() {
            let from = tiers[i]
            guard from.count > 0,
                  from.basicNeedsMet,
                  from.happiness >= 1,
                  let nextTier = from.tier.next,
                  let j = tiers.firstIndex(where: { $0.tier == nextTier })
            else { continue }

            let free = tiers[j].capacity - tiers[j].count
            guard free > 0 else { continue }

            let moving = min(Self.promotionPerMin * minutesPerTick, from.count, free)
            tiers[i].count -= moving
            tiers[j].count += moving
        }
    }

    static let seeded = Population(tiers: [
        TierPopulation(tier: .survivors,   count: 248, capacity: 300, happiness: 1, basicSatisfaction: 1),
        TierPopulation(tier: .settlers,    count: 0,   capacity: 150, happiness: 1, basicSatisfaction: 1),
        TierPopulation(tier: .engineers,   count: 0,   capacity: 0,   happiness: 1, basicSatisfaction: 1),
        TierPopulation(tier: .synthesists, count: 0,   capacity: 0,   happiness: 1, basicSatisfaction: 1),
        TierPopulation(tier: .ascendant,   count: 0,   capacity: 0,   happiness: 1, basicSatisfaction: 1)
    ])
}
