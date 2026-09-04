//
//  GameSave.swift
//  Helios
//
//  Created by Bernat on 04/09/2026.
//


// GameSave.swift
// The entire persisted game. A save stores ids and mutable fields only —
// never authored data. Chain rates, research costs, ship stats and the world
// registry all live in code, not in the save file, so a future rebalance
// reaches everyone with an existing save instead of being frozen out of it.
// HELIOS.md §18 S14, §21.
//
// `version` is the first field, from day one — cheap now, impossible to
// retrofit once real saves exist. Phase 1.5 Step 6 is what actually writes
// this to disk; this file just defines the shape and its Codable rules.

import Foundation

struct GameSave {
    var version: Int
    var colonies: [Colony]
    var activeColonyID: Colony.ID
    var credits: Int
    var ships: [Ship]
    var nextShipSerial: Int
    var researchProjects: [ResearchProject]
    var researchPoints: Int
    var researchRatePerMin: Int
    var lastTickAt: Date

    init(
        version: Int = 1,
        colonies: [Colony],
        activeColonyID: Colony.ID,
        credits: Int,
        ships: [Ship],
        nextShipSerial: Int,
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
        try container.encode(researchProjects, forKey: .researchProjects)
        try container.encode(researchPoints, forKey: .researchPoints)
        try container.encode(researchRatePerMin, forKey: .researchRatePerMin)
        try container.encode(lastTickAt, forKey: .lastTickAt)
    }
}