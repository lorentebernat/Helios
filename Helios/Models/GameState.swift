// GameState.swift
// Empire-scoped observable state. Colonies hold their own stock, population,
// production and shipyard; the empire holds credits, ships, research — and the
// Empire's business: the tick counter, Standing, the active quota, the one
// announced after it, the optional contract on offer, both ledgers, and the
// archive of settled cycles.

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

    // MARK: - The Empire's clock, posture and demands (Phase 2)

    /// **The clock the whole Empire runs on.** Monotonic, incremented once at
    /// the top of `tick()`, and persisted — an integer in the save file, not a
    /// `Date`. Quota and commission deadlines compare against this and nothing
    /// else, which is what keeps `tick()` pure and clock-free. HELIOS.md §4.8,
    /// §14.
    var tickCount: Int

    /// What the Empire thinks of you: an EMA of delivered-over-demanded, banded
    /// from Receivership to Patron. Sets the cadence and the stipend.
    /// HELIOS.md §4.1.
    var standing: Standing

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

    /// Settled cycles, oldest first, capped at `settlementHistoryLimit`.
    var settlementHistory: [QuotaSettlement]

    /// Monotonic quota id source, same shape and same reason as
    /// `nextShipSerial`: deterministic ids, no UUID inside `tick()`.
    var nextQuotaSerial: Int

    /// The optional contract currently on offer, if any. One at a time — a
    /// standing list of side quests would drown the quota, which is the thing
    /// the game is actually about. HELIOS.md §4.3.
    var commission: Commission?

    /// Deliveries against `commission`. Same mechanism as the quota's, its own
    /// instance.
    var commissionLedger: QuotaLedger

    var nextCommissionSerial: Int

    /// What became of the last one, for the panel.
    var lastCommissionOutcome: CommissionOutcome?

    // MARK: - Balance knobs (tuning, not state — deliberately not persisted)

    /// Load factor used when sizing a new manifest. HELIOS.md Appendix C: the
    /// usable band is roughly 0.75–1.2. Exposed so the balance tests can sweep
    /// it across settlements.
    var quotaLoad: Double = QuotaGenerator.standardLoad

    /// Holds the cadence fixed instead of taking it from the Standing band.
    /// Several balance measurements need a constant cadence while something
    /// else varies — interval-neutrality above all, which cannot be measured if
    /// the interval moves on its own — and it doubles as a debug knob.
    var quotaCadenceOverrideMinutes: Double?

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
        standing: Standing,
        currentQuota: Quota?,
        nextQuota: Quota?,
        ledger: QuotaLedger,
        settlementHistory: [QuotaSettlement],
        nextQuotaSerial: Int,
        commission: Commission?,
        commissionLedger: QuotaLedger,
        nextCommissionSerial: Int,
        lastCommissionOutcome: CommissionOutcome?,
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
        self.standing = standing
        self.currentQuota = currentQuota
        self.nextQuota = nextQuota
        self.ledger = ledger
        self.settlementHistory = settlementHistory
        self.nextQuotaSerial = nextQuotaSerial
        self.commission = commission
        self.commissionLedger = commissionLedger
        self.nextCommissionSerial = nextCommissionSerial
        self.lastCommissionOutcome = lastCommissionOutcome
        self.researchProjects = researchProjects
        self.researchPoints = researchPoints
        self.researchRatePerMin = researchRatePerMin
    }

    static func seeded() -> GameState {
        let colony = Colony.seeded
        let cadence = Standing.initial.cadenceMinutes(base: QuotaGenerator.baseIntervalMinutes)
        // A fresh game starts with a real sink already in place, and with the
        // following cycle already announced.
        let current = QuotaGenerator.generate(
            id: 1, colony: colony, economyRate: economyRate,
            issuedAtTick: 0, intervalMinutes: cadence
        )
        let next = QuotaGenerator.generate(
            id: 2, colony: colony, economyRate: economyRate,
            issuedAtTick: current.dueAtTick, intervalMinutes: cadence
        )
        return GameState(
            colonies: [colony],
            activeColonyID: "kepler-7",
            credits: 2_340,
            ships: Ship.samples,
            nextShipSerial: 6,   // seed fleet hand-numbered 1...5 (Ship.swift)
            tickCount: 0,
            standing: .initial,
            currentQuota: current,
            nextQuota: next,
            ledger: .empty(for: current),
            settlementHistory: [],
            nextQuotaSerial: 3,
            commission: nil,
            commissionLedger: QuotaLedger(quotaID: 0),
            nextCommissionSerial: 1,
            lastCommissionOutcome: nil,
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
            standing: standing,
            currentQuota: currentQuota,
            nextQuota: nextQuota,
            ledger: ledger,
            settlementHistory: settlementHistory,
            nextQuotaSerial: nextQuotaSerial,
            commission: commission,
            commissionLedger: commissionLedger,
            nextCommissionSerial: nextCommissionSerial,
            lastCommissionOutcome: lastCommissionOutcome,
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
            standing: save.standing,
            currentQuota: save.currentQuota,
            nextQuota: save.nextQuota,
            ledger: save.ledger,
            settlementHistory: save.settlementHistory,
            nextQuotaSerial: save.nextQuotaSerial,
            commission: save.commission,
            commissionLedger: save.commissionLedger,
            nextCommissionSerial: save.nextCommissionSerial,
            lastCommissionOutcome: save.lastCommissionOutcome,
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

    /// Credits paid per game-minute of cadence, for a fully met quota at
    /// Indifferent. **This is the number that closes S3** — before it, `credits`
    /// was mutated in exactly one place, `credits -=`, and buying an Escort plus
    /// a Scout left the shipyard permanently dead. HELIOS.md §18 S3.
    ///
    /// Calibrated as the brief asks: a met quota at Indifferent pays 300, so a
    /// Freighter (800 credits) is affordable every 2.67 cycles. Usable, not
    /// free.
    ///
    /// Note it is a rate per game-minute of *cadence*, not a flat figure per
    /// settlement. See `payStipend` for why that distinction is the whole
    /// point.
    static let stipendPerGameMinute: Double = 1.25

    // MARK: - Game loop

    /// Advances one tick and records the wall-clock time. What the timer calls.
    func advanceOneTick(now: Date = Date()) {
        tick()
        lastTickAt = now
    }

    /// One pure simulation step — reads no clock and no randomness.
    ///
    /// Order: count the tick, run the colonies (population, industry, then the
    /// Empire's collection — quota first, commission out of the residual),
    /// advance the fleet, resolve a commission whose deadline has arrived, then
    /// settle the quota if its deadline has. Settling *after* the colonies is
    /// what lets the final instalment land at `scheduledFraction == 1.0` and be
    /// counted, rather than being cut off by a cycle that already rolled over.
    func tick() {
        tickCount += 1

        // A ledger carrying another subject's id is stale — only reachable
        // from a hand-edited save or a test that swapped the demand out.
        if let quota = currentQuota, ledger.quotaID != quota.id {
            ledger.reset(for: quota)
        }
        if let contract = commission, commissionLedger.quotaID != contract.id {
            commissionLedger = .empty(forCommission: contract)
        }

        // TODO Phase 7: one ledger pair is threaded through every colony while
        // the demand is sized from the active colony alone, so with two
        // colonies whichever iterates first consumes the allocation.
        // HELIOS.md §18 S17.
        for i in colonies.indices {
            let finished = colonies[i].applyTick(
                economyRate: Self.economyRate,
                fleetRate: Self.fleetRate,
                atTick: tickCount,
                quota: currentQuota,
                quotaLedger: &ledger,
                commission: commission,
                commissionLedger: &commissionLedger
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

        resolveCommissionIfDue()
        settleQuotaIfDue()
    }

    /// Closes an optional contract at its deadline.
    ///
    /// Three outcomes, and the asymmetry between them is the whole mechanic.
    /// **Ignored costs nothing at all** — not a smaller reward, nothing; that
    /// is what makes "ignoring is always safe" true rather than nearly true.
    /// **Delivered** pays credits and repairs Standing directly.
    /// **Accepted and failed** costs more Standing than never accepting, which
    /// is what stops accepting everything from being free.
    ///
    /// Pass or fail, never graded: 99% delivered pays exactly what 0% pays. A
    /// quota is graded because you had no say in it; a commission is a bet you
    /// took.
    private func resolveCommissionIfDue() {
        guard let contract = commission, contract.isDue(atTick: tickCount) else { return }

        if !contract.accepted {
            lastCommissionOutcome = .ignored
        } else if contract.isMet(by: commissionLedger) {
            credits += contract.creditReward
            standing.adjust(by: contract.standingReward)
            lastCommissionOutcome = .delivered
        } else {
            standing.adjust(by: -contract.standingPenalty)
            lastCommissionOutcome = .failed
        }

        commission = nil
        commissionLedger = QuotaLedger(quotaID: 0)
    }

    /// Closes the cycle when `tickCount` reaches the deadline: compute the fill,
    /// pay for the shipment, archive the result, move Standing, promote the
    /// announced manifest, announce the one after it, clear the ledger, and
    /// post a fresh contract if none is outstanding.
    ///
    /// Settlement is not bookkeeping — it is what keeps the Empire a
    /// **permanent** sink. A completed manifest has no collectable allowance
    /// left, so without this the Empire stops collecting at the end of the
    /// first interval and the colony saturates by roughly tick 300: S1,
    /// reintroduced by its own fix.
    ///
    /// Note where the cadence change lands. Standing moves on the fill of the
    /// cycle just judged, but the manifest **promoted** here was published a
    /// cycle ago and keeps the window it was published with; the new cadence
    /// shapes the manifest **announced** here instead. That one-cycle lag is
    /// the promise being kept: retooling against a manifest that then changes
    /// under you would be worthless. HELIOS.md §4.2.
    private func settleQuotaIfDue() {
        guard let settling = currentQuota, settling.isDue(atTick: tickCount) else { return }

        let fill = settling.fill(from: ledger)

        // Paid BEFORE Standing moves, deliberately: these goods left the docks
        // under the posture the Empire held during the cycle, and that was the
        // price on offer. Otherwise a collapse into Receivership would
        // retroactively confiscate the shipment you just made. The grace is
        // symmetrical with the cadence lag — the settlement that drops you to
        // Receivership still pays at Scrutinised; the next one pays nothing.
        let paid = payStipend(for: settling, fill: fill)

        record(
            QuotaSettlement(
                quotaID: settling.id,
                settledAtTick: tickCount,
                fill: fill,
                lineFills: settling.lineFills(from: ledger),
                stipend: paid
            )
        )

        standing.settle(fill: fill)

        // The announced manifest becomes the live one. Its window was stamped
        // when it was published, so it starts exactly now and there is nothing
        // to re-stamp. The fallback only fires for a state whose invariant was
        // broken from outside — a hand-edited save, or a test that replaced
        // `currentQuota` without announcing a successor.
        //
        // TODO Phase 4: this equality assumes tickCount advances by exactly one
        // between checks. Offline catch-up that skips ticks would fail it and
        // silently replace the announced manifest with a fresh one, breaking
        // the full-interval-to-retool promise. HELIOS.md §18 S16.
        let promoted: Quota
        if let announced = nextQuota, announced.issuedAtTick == tickCount {
            promoted = announced
        } else {
            promoted = generateQuota(issuedAtTick: tickCount)
        }

        currentQuota = promoted
        ledger.reset(for: promoted)
        nextQuota = generateQuota(issuedAtTick: promoted.dueAtTick)

        offerCommissionIfNoneOutstanding()
    }

    /// One contract at a time, posted when the previous one has closed. Offered
    /// at settlement rather than at an arbitrary tick so it arrives alongside
    /// the new manifest — the player sees what is compulsory and what is
    /// optional in the same breath.
    ///
    /// TODO Phase 7: sized from the *active* colony, so with several colonies
    /// the player could change the next contract by switching colonies in the
    /// UI. HELIOS.md §18 S17.
    private func offerCommissionIfNoneOutstanding() {
        guard commission == nil, let quota = currentQuota else { return }
        guard let contract = CommissionGenerator.generate(
            id: nextCommissionSerial,
            colony: colonies[activeIndex],
            against: quota,
            offeredAtTick: tickCount,
            economyRate: Self.economyRate,
            stipendPerGameMinute: Self.stipendPerGameMinute
        ) else { return }

        nextCommissionSerial += 1
        commission = contract
        commissionLedger = .empty(forCommission: contract)
    }

    /// Pays for one settled shipment, and returns what was paid.
    ///
    /// **The stipend is paid per shipment, not per settlement**, which is the
    /// only reason the band ladder means what it looks like. Cadence changes
    /// with the band, so a flat figure per cycle would be distorted by it:
    /// income per game-minute would run 0 / 1.25 / 1.25 / 1.00 / 0.75 from
    /// Receivership to Patron, and Patron would pay 40% *less* per hour than
    /// Indifferent — the opposite of §4.1's "bonus stipend". Scaling by the
    /// cadence the shipment covers makes income per game-minute
    /// `stipendPerGameMinute × stipendMultiplier`: 0 / 0.875 / 1.25 / 1.5 /
    /// 1.875 credits, proportional to the 0 / 0.7 / 1.0 / 1.2 / 1.5 ladder.
    ///
    /// This is the same trap as the demand-rate invariant, in mirror image:
    /// anything expressed per settlement is at the mercy of the cadence, so it
    /// has to be expressed per shipment.
    ///
    /// Partial fill pays partially — deliver 60% and you are paid 60%. At
    /// Receivership the multiplier is zero: the Empire collects at the dock and
    /// pays nothing, and the goods still leave.
    @discardableResult
    private func payStipend(for quota: Quota, fill: Double) -> Int {
        let clampedFill = min(1, max(0, fill))
        let gross = Self.stipendPerGameMinute
            * quota.intervalMinutes
            * clampedFill
            * standing.band.stipendMultiplier
        let paid = Int(gross.rounded())
        guard paid > 0 else { return 0 }
        credits += paid
        return paid
    }

    /// The cadence the Empire is currently using, in game-minutes: the base
    /// figure scaled by the Standing band, unless something has pinned it.
    var quotaCadenceMinutes: Double {
        quotaCadenceOverrideMinutes
            ?? standing.cadenceMinutes(base: QuotaGenerator.baseIntervalMinutes)
    }

    /// What the live manifest would pay if fully met, at the current band. For
    /// the panel, and for reasoning about pacing without running a cycle.
    ///
    /// Uses the live manifest's own window, not `quotaCadenceMinutes`: after a
    /// band move the manifest keeps the window it was issued with for a full
    /// cycle, and the band's new cadence would overstate (or understate) the
    /// payment by up to 50% until then.
    var stipendForAMetQuota: Int {
        Int((Self.stipendPerGameMinute
             * (currentQuota?.intervalMinutes ?? quotaCadenceMinutes)
             * standing.band.stipendMultiplier).rounded())
    }

    /// Sizes a manifest from the sector's current assessed capacity at the
    /// current cadence.
    ///
    /// TODO Phase 7: "the sector" is one colony today. Multi-colony assessment
    /// should sum installed capacity across colonies, since Standing and quota
    /// are sector-scoped in the fiction (HELIOS.md §4.1, §18 S17).
    private func generateQuota(issuedAtTick: Int) -> Quota {
        QuotaGenerator.generate(
            id: mintQuotaID(),
            colony: colonies[activeIndex],
            economyRate: Self.economyRate,
            issuedAtTick: issuedAtTick,
            intervalMinutes: quotaCadenceMinutes,
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

    // MARK: - Readouts

    /// Overall fill of the active quota, normalised per line.
    var quotaFill: Double {
        currentQuota?.fill(from: ledger) ?? 0
    }

    /// Game-minutes left in the current cycle. What `Format.duration` renders.
    var quotaMinutesRemaining: Double {
        currentQuota?.minutesRemaining(atTick: tickCount) ?? 0
    }

    var lastSettlement: QuotaSettlement? { settlementHistory.last }

    /// How far through the live cycle we are, 0...1 — what the panel compares
    /// `quotaFill` against to decide whether the cycle is behind.
    var quotaScheduledFraction: Double {
        currentQuota?.scheduledFraction(atTick: tickCount) ?? 0
    }

    // MARK: - Actions

    /// Opt in. Irreversible by design — the commitment is the whole point of
    /// the bet, and a contract you can back out of at the deadline is just a
    /// reward with extra steps.
    @discardableResult
    func acceptCommission() -> Bool {
        guard let contract = commission, contract.accepted == false else { return false }
        commission?.accepted = true
        return true
    }

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
