// Colony.swift
// One settlement, at one destination. Colony.ID IS the destination slug —
// one colony per destination, so there's no separate identifier to keep in sync.
//
// A struct by design: no Observation, no SwiftUI, so the simulation stays
// portable. Mutate through GameState by index, never wholesale-replace.

import Foundation

struct Colony: Identifiable {
    let id: Destination.ID
    var stock: ColonyStock
    var population: Population
    var productionChains: [ChainDetail]
    var shipyardQueue: [ShipBuildOrder]

    // Grid balance, refreshed each tick. Energy is never stored — it's consumed
    // the instant it's made.
    var gridSupply: Double = 0
    var gridDemand: Double = 0

    // Stored, set directly from what ProductionAllocator.run actually used to
    // resolve Phase B — not recomputed here. Previously this was a computed
    // property re-deriving the same ratio from gridSupply/gridDemand, which
    // only agreed with the simulation's own factor by coincidence of both
    // reading the same two numbers. HELIOS.md §18 S7.
    var gridFactor: Double = 1

    /// How much of generation is being drawn. Can exceed 100% under brownout.
    var gridUtilisationPercent: Int {
        guard gridSupply > 0 else { return gridDemand > 0 ? 100 : 0 }
        return Int(((gridDemand / gridSupply) * 100).rounded())
    }

    // MARK: - Registry lookups

    var destination: Destination? { Destination.byID(id) }
    var name: String { destination?.name ?? "Unknown Colony" }
    var worldType: WorldType? { destination?.worldType }

    // MARK: - Tick

    /// Advances this colony one tick. Returns any ship build orders that
    /// completed, for the empire to turn into actual ships — ships are
    /// empire-scoped, so the colony can't create them itself.
    ///
    /// `applyDebugSink` is threaded in rather than read from a mutable
    /// static, because Swift Testing runs tests in parallel by default —
    /// a shared `DebugSink.enabled` toggle would be flaky. `GameState.tick()`
    /// passes `DebugSink.enabled`; tests pass `true`/`false` explicitly.
    /// HELIOS.md §18 S8.
    @discardableResult
    mutating func applyTick(economyRate: Double, fleetRate: Double, applyDebugSink: Bool = true) -> [ShipBuildOrder] {
        // Colonists eat before industry runs.
        population.applyTick(stock: &stock, minutesPerTick: economyRate)

        let grid = ProductionAllocator.run(
            chains: &productionChains,
            stock: &stock,
            economyRate: economyRate
        )
        gridSupply = grid.supply
        gridDemand = grid.demand
        gridFactor = grid.factor

        // TEMPORARY Phase 1 scaffolding, removed when Quota lands in Phase 2.
        // Without it the economy saturates and output % has no visible
        // effect. See DebugSink.swift. HELIOS.md §18 S1.
        if applyDebugSink {
            DebugSink.applyTick(stock: &stock, economyRate: economyRate)
        }

        return advanceShipyard(fleetRate: fleetRate)
    }

    private mutating func advanceShipyard(fleetRate: Double) -> [ShipBuildOrder] {
        for i in shipyardQueue.indices {
            shipyardQueue[i].applyTick(minutesPerTick: fleetRate)
        }
        let finished = shipyardQueue.filter(\.isComplete)
        guard !finished.isEmpty else { return [] }
        shipyardQueue.removeAll(where: \.isComplete)
        return finished
    }

    // MARK: - Seed

    static let seeded = Colony(
        id: "kepler-7",
        stock: ColonyStock([
            "raw-ice": 120,
            "raw-ore": 90,
            "power-cells": 60,
            "water": 40,
            "grain": 30,
            "oxygen": 112,
            "ration-bars": 180,
            "refined-alloy": 0,      // Tool Fab starts blocked
            "alloy-tools": 60
        ]),
        population: .seeded,
        productionChains: ChainDetail.samples,
        shipyardQueue: []
    )
}

// MARK: - Codable (Phase 1.5 Step 5)

// A colony is genuinely mutable state — no registry blueprint to overlay —
// so every field here is saved as-is. The one wrinkle is `productionChains`:
// each element's own `Codable` throws `ChainDetail.UnknownID` if a chain was
// retired from the registry since the save was written, and a colony should
// simply drop that chain rather than fail to load entirely. `ChainSlot`
// isolates the per-element decode so one bad chain can't sink the array.
// HELIOS.md §18 S14, §21.
//
// Declared in an extension so the compiler-synthesised memberwise initialiser
// (used by `seeded` above) stays intact.
extension Colony: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, stock, population, productionChains, shipyardQueue
        case gridSupply, gridDemand, gridFactor
    }

    /// Decodes one element of `productionChains`, converting a chain whose id
    /// is no longer in the registry into `nil` instead of throwing and
    /// failing the whole array.
    private struct ChainSlot: Decodable {
        let chain: ChainDetail?
        init(from decoder: Decoder) throws {
            chain = try? ChainDetail(from: decoder)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Destination.ID.self, forKey: .id)
        stock = try container.decode(ColonyStock.self, forKey: .stock)
        population = try container.decode(Population.self, forKey: .population)
        let slots = try container.decode([ChainSlot].self, forKey: .productionChains)
        productionChains = slots.compactMap(\.chain)
        shipyardQueue = try container.decode([ShipBuildOrder].self, forKey: .shipyardQueue)
        gridSupply = try container.decode(Double.self, forKey: .gridSupply)
        gridDemand = try container.decode(Double.self, forKey: .gridDemand)
        gridFactor = try container.decode(Double.self, forKey: .gridFactor)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(stock, forKey: .stock)
        try container.encode(population, forKey: .population)
        try container.encode(productionChains, forKey: .productionChains)
        try container.encode(shipyardQueue, forKey: .shipyardQueue)
        try container.encode(gridSupply, forKey: .gridSupply)
        try container.encode(gridDemand, forKey: .gridDemand)
        try container.encode(gridFactor, forKey: .gridFactor)
    }
}
