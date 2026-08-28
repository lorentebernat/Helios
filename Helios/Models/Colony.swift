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

    var gridFactor: Double {
        gridDemand <= 0 ? 1 : min(1, gridSupply / gridDemand)
    }

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
    mutating func applyTick(economyRate: Double, fleetRate: Double) -> [ShipBuildOrder] {
        // Colonists eat before industry runs.
        population.applyTick(stock: &stock, minutesPerTick: economyRate)

        let grid = ProductionAllocator.run(
            chains: &productionChains,
            stock: &stock,
            economyRate: economyRate
        )
        gridSupply = grid.supply
        gridDemand = grid.demand

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
