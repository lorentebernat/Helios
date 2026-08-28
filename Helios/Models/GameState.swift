// GameState.swift
// Empire-scoped observable state. Colonies hold their own stock, population,
// production and shipyard; the empire holds credits, ships, and research.

import Observation
import Foundation

@Observable
final class GameState {
    // Colonies
    var colonies: [Colony]
    var activeColonyID: Colony.ID

    // Empire
    var credits: Int
    var ships: [Ship]

    // Research (empire-wide — the global/local split is a Phase 5 decision)
    var researchProjects: [ResearchProject]
    var researchPoints: Int
    var researchRatePerMin: Int

    /// When the world last advanced. Phase 3 uses this for offline catch-up.
    var lastTickAt: Date = Date()

    init(
        colonies: [Colony],
        activeColonyID: Colony.ID,
        credits: Int,
        ships: [Ship],
        researchProjects: [ResearchProject],
        researchPoints: Int,
        researchRatePerMin: Int
    ) {
        self.colonies = colonies
        self.activeColonyID = activeColonyID
        self.credits = credits
        self.ships = ships
        self.researchProjects = researchProjects
        self.researchPoints = researchPoints
        self.researchRatePerMin = researchRatePerMin
    }

    static func seeded() -> GameState {
        GameState(
            colonies: [.seeded],
            activeColonyID: "kepler-7",
            credits: 2_340,
            ships: Ship.samples,
            researchProjects: ResearchProject.samples,
            researchPoints: 1_840,
            researchRatePerMin: 12
        )
    }

    // MARK: - Active colony

    /// Index of the active colony. Colonies is never empty by construction.
    private var activeIndex: Int {
        colonies.firstIndex { $0.id == activeColonyID } ?? 0
    }

    /// Read-only view of the colony the UI is currently showing.
    var activeColony: Colony { colonies[activeIndex] }

    // MARK: - Tick tuning

    static let tickInterval: TimeInterval = 1.0

    // Two independent pacing levers.
    // ACCELERATED: 1.0 means one tick applies a full per-minute rate.
    // TODO Phase 3: dial economyRate to 1.0/60.0.
    static let economyRate: Double = 1.0   // production, population, research
    static let fleetRate: Double = 1.0     // ship travel, shipyard build time

    // MARK: - Game loop

    /// Advances one tick and records the wall-clock time. What the timer calls.
    func advanceOneTick(now: Date = Date()) {
        tick()
        lastTickAt = now
    }

    /// One pure simulation step — reads no clock, so Phase 3 can replay it in a
    /// loop for offline catch-up.
    func tick() {
        for i in colonies.indices {
            let finished = colonies[i].applyTick(
                economyRate: Self.economyRate,
                fleetRate: Self.fleetRate
            )
            let colonyID = colonies[i].id
            for order in finished {
                ships.append(
                    Ship(
                        name: order.name,
                        role: order.role,
                        status: .idle,
                        locationID: colonyID,
                        destinationID: nil,
                        remainingMinutes: 0,
                        cargoNote: order.role == .freighter ? "Empty hold" : nil
                    )
                )
            }
        }

        for i in ships.indices {
            ships[i].applyTick(minutesPerTick: Self.fleetRate)
        }
    }

    // MARK: - Actions

    /// Re-routing an in-transit ship is allowed.
    func dispatch(shipID: Ship.ID, to destination: Destination) {
        guard let i = ships.firstIndex(where: { $0.id == shipID }) else { return }
        let travel = Double(destination.travelTimeMinutes) / ships[i].role.speedMultiplier
        ships[i].destinationID = destination.id
        ships[i].remainingMinutes = travel
        ships[i].status = .inTransit
    }

    /// Credits come from the empire; materials from the active colony's stock.
    func canAfford(_ cost: BuildCost) -> Bool {
        guard credits >= cost.credits else { return false }
        let stock = activeColony.stock
        return cost.materials.allSatisfy { stock.has($0.resourceID, atLeast: $0.amount) }
    }

    /// Queues a ship at the active colony's shipyard. Cost is deducted in full
    /// upfront, as in both Anno and OGame.
    @discardableResult
    func queueShip(role: ShipRole, name: String) -> Bool {
        let cost = role.buildCost
        guard canAfford(cost) else { return false }

        credits -= cost.credits
        for material in cost.materials {
            colonies[activeIndex].stock.withdraw(material.resourceID, material.amount)
        }

        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        colonies[activeIndex].shipyardQueue.append(
            ShipBuildOrder(
                name: finalName.isEmpty ? ShipNameGenerator.random() : finalName,
                role: role,
                remainingMinutes: role.buildMinutes,
                totalMinutes: role.buildMinutes
            )
        )
        return true
    }

    /// Sets a chain's player-requested output rate, clamped to 0...1.
    /// Mutates by index (HELIOS.md §14) — views read `activeColony` as a copy
    /// and can't write through it.
    func setOutputPercent(chainID: ChainDetail.ID, to value: Double) {
        let i = activeIndex
        guard let j = colonies[i].productionChains.firstIndex(where: { $0.id == chainID })
        else { return }
        colonies[i].productionChains[j].outputPercent = min(1, max(0, value))
    }
}
