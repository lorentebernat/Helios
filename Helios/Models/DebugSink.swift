// DebugSink.swift
//
// TEMPORARY Phase 1 scaffolding — deleted when Quota lands in Phase 2
// (HELIOS.md §19 Phase 2). Drains each resource out of the colony every tick
// so output % is observable at all: without a sink the economy saturates by
// ~tick 60 (every store at capacity) and throttling a chain only changes
// which store fills, not anything visible. HELIOS.md §18 S1, Appendix C.

import Foundation

enum DebugSink {
    // Guarded so this never ships in a release build by accident — it's
    // temporary scaffolding that drains a colony's stores, not a real
    // gameplay mechanic. HELIOS.md §19 Phase 1.5 cleanup.
    #if DEBUG
    static let enabled = true
    #else
    static let enabled = false
    #endif

    /// Per-good drain rate at "load 1.0" — the measured export capacity
    /// (production net of colonist consumption) from HELIOS.md Appendix C,
    /// per game-minute. This is the sweet spot: stores settle at 0–7% for
    /// tradeables instead of sitting saturated or being drained to nothing.
    private static let ratesPerMin: [Resource.ID: Double] = [
        "power-cells":   5.31,
        "raw-ore":       5.09,
        "alloy-tools":   2.80,
        "oxygen":        2.31,
        "raw-ice":       2.07,
        "grain":         2.06,
        "water":         0.56,
        "ration-bars":   0.23,
        "refined-alloy": 0.04
    ]

    /// Basic-need goods the sink may never draw below this fraction of
    /// capacity. Without this floor, high drain empties the colony's
    /// survival stock outright and colonists die — measured in HELIOS.md
    /// Appendix C. Luxuries (e.g. Alloy Tools) are deliberately not
    /// reserved — that contest with the population is the intended squeeze.
    private static let reservedGoods: Set<Resource.ID> = ["oxygen", "ration-bars", "water"]
    private static let reserveFraction = 0.3

    static func applyTick(stock: inout ColonyStock, economyRate: Double) {
        guard enabled else { return }

        for (id, ratePerMin) in ratesPerMin {
            let amount = ratePerMin * economyRate
            if reservedGoods.contains(id) {
                let floor = stock.capacity(of: id) * reserveFraction
                let available = max(0, stock.amount(of: id) - floor)
                stock.drain(id, min(amount, available))
            } else {
                stock.drain(id, amount)
            }
        }
    }
}
