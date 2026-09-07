// GameState.swift
// Empire-scoped observable state. Colonies hold their own stock, population,
// production and shipyard; the empire holds credits, ships, research — and the
// Empire's demands: the tick counter, the active quota, the one announced after
// it, the ledger of what has been delivered, and the archive of settled cycles.

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

    /// Monotonic counter — the sole source of new ShipIDs. Never reused, never
    /// decremented. Part of saved state so a relaunch can't reissue an id
    /// already in use. HELIOS.md §18 S5.
    var nextShipSerial: Int

    // MARK: - The Empire's clock and demands (Phase 2)

    /// **The clock the whole Empire runs on.** Monotonic, incremented once at
    /// the top of `tick()`, and persisted — an integer in the save file, not a
    /// `Date`. Quota deadlines compare against this and nothing else, which is
    /// what keeps `tick()` pure and clock-free: Phase 4's offline replay and
    /// Phase 9's server reconciliation both depend on it, and the Phase 1.5
    /// `tickIsDeterministic` test stands guard. HELIOS.md §4.8, §14.
    var tickCount: Int

    /// The manifest currently being delivered against. `nil` means no demand at
    /// all, which also means no sink — that is S1, and it is only reachable
    /// deliberately, from a test.
    var currentQuota: Quota?

    /// The manifest after this one, **published the moment the current one
    /// settles**, so the player always has one full interval to retool. A quota
    /// you cannot see coming is a dice roll, not a decision. HELIOS.md §4.2.
    ///
    /// Its window is stamped when it is published, so
    /// `nextQuota.issuedAtTick == currentQuota.dueAtTick` always holds and
    /// promotion needs no re-stamping.
    var nextQuota: Quota?

    /// What has actually left the docks against `currentQuota`.
    var ledger: QuotaLedger

    /// Settled cycles, oldest first, capped at `settlementHistoryLimit`. Step 5
    /// runs Standing's EMA over these; Step 8 shows the last one.
    var settlementHistory: [QuotaSettlement]

    /// Monotonic quota id source, same shape and same reason as
    /// `nextShipSerial`: deterministic ids, no UUID inside `tick()`.
    var nextQuotaSerial: Int

    /// Load factor used when sizing a new manifest. A tuning constant in play,
    /// deliberately **not persisted** — it is balance, not game state — but
    /// exposed as a property so the balance tests can sweep it across
    /// settlements. HELIOS.md Appendix C: the usable band is roughly 0.75–1.2.
    var quotaLoad: Double = QuotaGenerator.standardLoad

    static let settlementHistoryLimit = 20

    // Research (empire-wide — the global/local split is a Phase 5 decision)
    var researchProjects: [ResearchProject]
    var researchPoints: Int
    var researchRatePerMin: Int

    /// When the world last advanced. Phase 4 uses this for offline catch-up.
    var lastTickAt: Date = Date()

    init(
        colonies: [Colony],
        activeColonyID: Colony.ID,
        credits: Int,
        ships: [Ship],
        nextShipSerial: Int,
        tickCount: Int,
        currentQuota: Quota?,
        nextQuota: Quota?,
        ledger: QuotaLedger,
        settlementHistory: [QuotaSettlement],
        nextQuotaSerial: Int,
        researchProjects: [ResearchProject],
        researchPoints: Int,
        researchRatePerMin: Int
    ) {
        self.colonies = colonies
        self.activeColonyID = activeColonyID
        self.credits = credits
        self.ships = ships
        self.nextShipSerial = nextShipSerial
        self.tickCount = tickCount
        self.currentQuota = currentQuota
        self.nextQuota = nextQuota
        self.ledger = ledger
        self.settlementHistory = settlementHistory
        self.nextQuotaSerial = nextQuotaSerial
        self.researchProjects = researchProjects
        self.researchPoints = researchPoints
        self.researchRatePerMin = researchRatePerMin
    }

    static func seeded() -> GameState {
        let colony = Colony.seeded
        // A fresh game starts with a real sink already in place, and with the
        // following cycle already announced.
        let current = QuotaGenerator.generate(
            id: 1, colony: colony, economyRate: economyRate, issuedAtTick: 0
        )
        let next = QuotaGenerator.generate(
            id: 2, colony: colony, economyRate: economyRate, issuedAtTick: current.dueAtTick
        )
        return GameState(
            colonies: [colony],
            activeColonyID: "kepler-7",
            credits: 2_340,
            ships: Ship.samples,
            nextShipSerial: 6,   // seed fleet hand-numbered 1...5 (Ship.swift)
            tickCount: 0,
            currentQuota: current,
            nextQuota: next,
            ledger: .empty(for: current),
            settlementHistory: [],
            nextQuotaSerial: 3,
            researchProjects: ResearchProject.samples,
            researchPoints: 1_840,
            researchRatePerMin: 12
        )
    }

    // MARK: - Persistence

    /// A `Codable` snapshot of everything worth saving. `GameState` itself
    /// does not conform to `Codable` — it's an `@Observable` class bound to
    /// UI object identity, not a value type — so persistence goes through
    /// this computed property and the matching `init(save:)` instead.
    var snapshot: GameSave {
        GameSave(
            colonies: colonies,
            activeColonyID: activeColonyID,
            credits: credits,
            ships: ships,
            nextShipSerial: nextShipSerial,
            tickCount: tickCount,
            currentQuota: currentQuota,
            nextQuota: nextQuota,
            ledger: ledger,
            settlementHistory: settlementHistory,
            nextQuotaSerial: nextQuotaSerial,
            researchProjects: researchProjects,
            researchPoints: researchPoints,
            researchRatePerMin: researchRatePerMin,
            lastTickAt: lastTickAt
        )
    }

    /// Rebuilds a `GameState` from a decoded save.
    convenience init(save: GameSave) {
        self.init(
            colonies: save.colonies,
            activeColonyID: save.activeColonyID,
            credits: save.credits,
            ships: save.ships,
            nextShipSerial: save.nextShipSerial,
            tickCount: save.tickCount,
            currentQuota: save.currentQuota,
            nextQuota: save.nextQuota,
            ledger: save.ledger,
            settlementHistory: save.settlementHistory,
            nextQuotaSerial: save.nextQuotaSerial,
            researchProjects: save.researchProjects,
            researchPoints: save.researchPoints,
            researchRatePerMin: save.researchRatePerMin
        )
        self.lastTickAt = save.lastTickAt
    }

    /// What `HeliosApp` calls at launch: the saved game if `SaveStore` has a
    /// readable one, otherwise a fresh seeded game. HELIOS.md §18 S4.
    static func load() -> GameState {
        guard let save = SaveStore.load() else { return .seeded() }
        let state = GameState(save: save)
        // Elapsed real time between this save and now is discarded, not
        // replayed. Offline catch-up is Phase 4, deliberately not this one.
        state.lastTickAt = Date()
        return state
    }

    /// Writes the current state to disk, on scenePhase transitions rather than
    /// every tick.
    func save() {
        SaveStore.save(snapshot)
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
    // TODO Phase 4: dial economyRate to 1.0/60.0.
    static let economyRate: Double = 1.0   // production, population, research
    static let fleetRate: Double = 1.0     // ship travel, shipyard build time

    // MARK: - Game loop

    /// Advances one tick and records the wall-clock time. What the timer calls.
    func advanceOneTick(now: Date = Date()) {
        tick()
        lastTickAt = now
    }

    /// One pure simulation step — reads no clock and no randomness.
    ///
    /// Order: count the tick, run the colonies (population, industry, then the
    /// Empire's collection paced against `tickCount`), advance the fleet, then
    /// settle if the deadline has arrived. Settling *after* the colonies is what
    /// lets the final instalment land at `scheduledFraction == 1.0` and be
    /// counted, rather than being cut off by a cycle that already rolled over.
    func tick() {
        tickCount += 1

        // A ledger carrying another quota's id is stale — only reachable from a
        // hand-edited save or a test that swapped the quota out.
        if let quota = currentQuota, ledger.quotaID != quota.id {
            ledger.reset(for: quota)
        }

        for i in colonies.indices {
            let finished = colonies[i].applyTick(
                economyRate: Self.economyRate,
                fleetRate: Self.fleetRate,
                quota: currentQuota,
                ledger: &ledger,
                atTick: tickCount
            )
            let colonyID = colonies[i].id
            for order in finished {
                ships.append(
                    Ship(
                        id: nextShipID(),
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

        settleQuotaIfDue()
    }

    /// Closes the cycle when `tickCount` reaches the deadline: archive the
    /// fill, promote the announced manifest, announce the one after it, clear
    /// the ledger.
    ///
    /// Settlement is not bookkeeping — it is what keeps the Empire a
    /// **permanent** sink. A completed manifest has no collectable allowance
    /// left, so without this the Empire stops collecting at the end of the
    /// first interval and the colony saturates by roughly tick 300: S1,
    /// reintroduced by its own fix.
    private func settleQuotaIfDue() {
        guard let settling = currentQuota, settling.isDue(atTick: tickCount) else { return }

        record(
            QuotaSettlement(
                quotaID: settling.id,
                settledAtTick: tickCount,
                fill: settling.fill(from: ledger),
                lineFills: settling.lineFills(from: ledger)
            )
        )

        // The announced manifest becomes the live one. Its window was stamped
        // when it was published, so it starts exactly now and there is nothing
        // to re-stamp. The fallback only fires for a state whose invariant was
        // broken from outside — a hand-edited save, or a test that replaced
        // `currentQuota` without announcing a successor.
        let promoted: Quota
        if let announced = nextQuota, announced.issuedAtTick == tickCount {
            promoted = announced
        } else {
            promoted = generateQuota(issuedAtTick: tickCount, intervalMinutes: settling.intervalMinutes)
        }

        currentQuota = promoted
        ledger.reset(for: promoted)
        nextQuota = generateQuota(issuedAtTick: promoted.dueAtTick, intervalMinutes: promoted.intervalMinutes)
    }

    /// Sizes a manifest from the sector's current assessed capacity.
    ///
    /// The cadence carries forward from the manifest being replaced rather than
    /// resetting to the base figure, so Step 5 can set it once from the Standing
    /// band and have it stick.
    ///
    /// TODO Phase 7: "the sector" is one colony today. Multi-colony assessment
    /// should sum installed capacity across colonies, since Standing and quota
    /// are sector-scoped in the fiction (HELIOS.md §4.1).
    private func generateQuota(issuedAtTick: Int, intervalMinutes: Double) -> Quota {
        QuotaGenerator.generate(
            id: mintQuotaID(),
            colony: colonies[activeIndex],
            economyRate: Self.economyRate,
            issuedAtTick: issuedAtTick,
            intervalMinutes: intervalMinutes,
            load: quotaLoad
        )
    }

    private func record(_ settlement: QuotaSettlement) {
        settlementHistory.append(settlement)
        if settlementHistory.count > Self.settlementHistoryLimit {
            settlementHistory.removeFirst(settlementHistory.count - Self.settlementHistoryLimit)
        }
    }

    /// The only place a ShipID is minted. Monotonic, deterministic given the
    /// same sequence of calls — no UUID, no randomness.
    private func nextShipID() -> ShipID {
        let id = ShipID(serial: nextShipSerial)
        nextShipSerial += 1
        return id
    }

    /// The only place a quota id is minted. Same contract as `nextShipID()`.
    func mintQuotaID() -> Int {
        let id = nextQuotaSerial
        nextQuotaSerial += 1
        return id
    }

    // MARK: - Quota readouts

    /// Overall fill of the active quota, normalised per line.
    var quotaFill: Double {
        currentQuota?.fill(from: ledger) ?? 0
    }

    /// Game-minutes left in the current cycle. What `Format.duration` renders.
    var quotaMinutesRemaining: Double {
        currentQuota?.minutesRemaining(atTick: tickCount) ?? 0
    }

    var lastSettlement: QuotaSettlement? { settlementHistory.last }

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
