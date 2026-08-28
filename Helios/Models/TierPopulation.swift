// TierPopulation.swift
// Runtime state for one rung of the ladder. Consumption is orchestrated by
// Population, since allocation must be proportional across tiers.

import Foundation

struct TierPopulation: Identifiable, Hashable {
    let tier: ColonistTier
    var count: Double
    var capacity: Double
    var happiness: Double          // 0...1, mean luxury satisfaction
    var basicSatisfaction: Double  // 0...1, tightest basic need

    var id: ColonistTier { tier }

    var basicNeedsMet: Bool { basicSatisfaction >= 0.999 }

    var isActive: Bool { count > 0 || capacity > 0 }

    var fillFraction: Double {
        guard capacity > 0 else { return 0 }
        return min(1, max(0, count / capacity))
    }

    /// Demand for a given need this tick, at current headcount.
    func demand(for need: PopulationNeed, minutesPerTick: Double) -> Double {
        (count / 100) * minutesPerTick * need.per100PerMin
    }

    /// Growth, decline and attrition, once satisfaction has been resolved.
    mutating func applyOutcome(minutesPerTick: Double) {
        guard count > 0 else {
            basicSatisfaction = 1
            happiness = 1
            return
        }

        if basicNeedsMet {
            if count < capacity {
                count = min(capacity, count + Population.growthPerMin * minutesPerTick)
            }
            if happiness < 1 {
                count = max(0, count - Population.unhappyAttritionPerMin * (1 - happiness) * minutesPerTick)
            }
        } else {
            // Proportional: a 5% shortfall costs 5% of full decline.
            let shortfall = 1 - basicSatisfaction
            count = max(0, count - Population.declinePerMin * shortfall * minutesPerTick)
        }
    }
}
