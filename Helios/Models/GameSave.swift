// GameSave.swift
// The entire persisted game. A save stores ids and mutable fields only —
// never authored data. Chain rates, research costs, ship stats and the world
// registry all live in code, not in the save file, so a future rebalance
// reaches everyone with an existing save instead of being frozen out of it.
// HELIOS.md §18 S14, §21.
//
// VERSION 6 (Phase 2 Step 7) adds the optional contract: `commission`, its
// ledger, its id source and the last outcome. VERSION 5 added each settlement's
// `stipend`; VERSION 4 added `standing`.
//
// The balance knobs on `GameState` — `quotaLoad`,
// `quotaCadenceOverrideMinutes` — are deliberately absent: they are tuning, not
// state, and persisting them would freeze a player on whatever values were live
// when they last saved, which is the same trap the blueprint-overlay decision
// exists to avoid.
//
// No migration between versions: `SaveStore` treats an unsupported version
// exactly like a corrupt file, quarantines it, and starts a fresh game. That
// was settled in Phase 1.5 (§21) precisely so that a format change before
// there are real saves in the wild costs nothing.

import Foundation

struct GameSave {
    var version: Int
    var colonies: [Colony]
    var activeColonyID: Colony.ID
    var credits: Int
    var ships: [Ship]
    var nextShipSerial: Int
    var tickCount: Int
    var standing: Standing
    var currentQuota: Quota?
    var nextQuota: Quota?
    var ledger: QuotaLedger
    var settlementHistory: [QuotaSettlement]
    var nextQuotaSerial: Int
    var commission: Commission?
    var commissionLedger: QuotaLedger
    var nextCommissionSerial: Int
    var lastCommissionOutcome: CommissionOutcome?
    var researchProjects: [ResearchProject]
    var researchPoints: Int
    var researchRatePerMin: Int
    var lastTickAt: Date

    init(
        version: Int = 6,
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
        researchRatePerMin: Int,
        lastTickAt: Date
    ) {
        self.version = version
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
        self.lastTickAt = lastTickAt
    }
}

// MARK: - Codable

extension GameSave: Codable {
    private enum CodingKeys: String, CodingKey {
        case version, colonies, activeColonyID, credits, ships, nextShipSerial
        case tickCount, standing
        case currentQuota, nextQuota, ledger, settlementHistory, nextQuotaSerial
        case commission, commissionLedger, nextCommissionSerial, lastCommissionOutcome
        case researchProjects, researchPoints, researchRatePerMin, lastTickAt
    }

    /// Decodes one element of `researchProjects`, converting a project whose
    /// id is no longer in the registry into `nil` instead of throwing and
    /// failing the whole array — same rationale as `Colony.ChainSlot`.
    private struct ResearchSlot: Decodable {
        let project: ResearchProject?
        init(from decoder: Decoder) throws {
            project = try? ResearchProject(from: decoder)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        colonies = try container.decode([Colony].self, forKey: .colonies)
        activeColonyID = try container.decode(Colony.ID.self, forKey: .activeColonyID)
        credits = try container.decode(Int.self, forKey: .credits)
        ships = try container.decode([Ship].self, forKey: .ships)
        nextShipSerial = try container.decode(Int.self, forKey: .nextShipSerial)
        tickCount = try container.decode(Int.self, forKey: .tickCount)
        standing = try container.decode(Standing.self, forKey: .standing)
        currentQuota = try container.decodeIfPresent(Quota.self, forKey: .currentQuota)
        nextQuota = try container.decodeIfPresent(Quota.self, forKey: .nextQuota)
        ledger = try container.decode(QuotaLedger.self, forKey: .ledger)
        settlementHistory = try container.decode([QuotaSettlement].self, forKey: .settlementHistory)
        nextQuotaSerial = try container.decode(Int.self, forKey: .nextQuotaSerial)
        commission = try container.decodeIfPresent(Commission.self, forKey: .commission)
        commissionLedger = try container.decode(QuotaLedger.self, forKey: .commissionLedger)
        nextCommissionSerial = try container.decode(Int.self, forKey: .nextCommissionSerial)
        lastCommissionOutcome = try container.decodeIfPresent(CommissionOutcome.self, forKey: .lastCommissionOutcome)
        let slots = try container.decode([ResearchSlot].self, forKey: .researchProjects)
        researchProjects = slots.compactMap(\.project)
        researchPoints = try container.decode(Int.self, forKey: .researchPoints)
        researchRatePerMin = try container.decode(Int.self, forKey: .researchRatePerMin)
        lastTickAt = try container.decode(Date.self, forKey: .lastTickAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(colonies, forKey: .colonies)
        try container.encode(activeColonyID, forKey: .activeColonyID)
        try container.encode(credits, forKey: .credits)
        try container.encode(ships, forKey: .ships)
        try container.encode(nextShipSerial, forKey: .nextShipSerial)
        try container.encode(tickCount, forKey: .tickCount)
        try container.encode(standing, forKey: .standing)
        try container.encodeIfPresent(currentQuota, forKey: .currentQuota)
        try container.encodeIfPresent(nextQuota, forKey: .nextQuota)
        try container.encode(ledger, forKey: .ledger)
        try container.encode(settlementHistory, forKey: .settlementHistory)
        try container.encode(nextQuotaSerial, forKey: .nextQuotaSerial)
        try container.encodeIfPresent(commission, forKey: .commission)
        try container.encode(commissionLedger, forKey: .commissionLedger)
        try container.encode(nextCommissionSerial, forKey: .nextCommissionSerial)
        try container.encodeIfPresent(lastCommissionOutcome, forKey: .lastCommissionOutcome)
        try container.encode(researchProjects, forKey: .researchProjects)
        try container.encode(researchPoints, forKey: .researchPoints)
        try container.encode(researchRatePerMin, forKey: .researchRatePerMin)
        try container.encode(lastTickAt, forKey: .lastTickAt)
    }
}
