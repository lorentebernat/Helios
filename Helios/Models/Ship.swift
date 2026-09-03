// Ship.swift
// Fleet vessel. Mutable transit data lives in FIELDS; ShipStatus carries no
// associated values. Locations are Destination.ID references, resolved to
// names by the view layer (components stay pure).

import Foundation

enum ShipRole: String, CaseIterable {
    case freighter = "Freighter"
    case scout = "Scout"
    case escort = "Escort"
    case explorer = "Explorer"

    var icon: String {
        switch self {
        case .freighter: return "shippingbox.fill"
        case .scout: return "safari.fill"
        case .escort: return "shield.fill"
        case .explorer: return "sparkles"
        }
    }

    /// FUNCTIONAL: divides travel time. Faster ships arrive sooner.
    var speedMultiplier: Double {
        switch self {
        case .freighter: return 1.0
        case .scout: return 2.0
        case .escort: return 1.2
        case .explorer: return 1.5
        }
    }

    // DISPLAY-ONLY for now — no gameplay effect yet. These MUST be made real:
    // cargoCapacity as an actual hauling constraint, shields/weapons once
    // combat exists.
    var cargoCapacity: Int {
        switch self {
        case .freighter: return 120
        case .scout: return 20
        case .escort: return 10
        case .explorer: return 60
        }
    }

    var shields: Int {
        switch self {
        case .freighter: return 1
        case .scout: return 1
        case .escort: return 3
        case .explorer: return 2
        }
    }

    var weapons: Int {
        switch self {
        case .freighter: return 0
        case .scout: return 0
        case .escort: return 4
        case .explorer: return 1
        }
    }

    var buildCost: BuildCost {
        switch self {
        case .scout:
            return BuildCost(credits: 500, materials: [
                MaterialRequirement(resourceID: "refined-alloy", amount: 25),
                MaterialRequirement(resourceID: "power-cells", amount: 20)
            ])
        case .freighter:
            return BuildCost(credits: 800, materials: [
                MaterialRequirement(resourceID: "refined-alloy", amount: 40),
                MaterialRequirement(resourceID: "alloy-tools", amount: 10),
                MaterialRequirement(resourceID: "power-cells", amount: 25)
            ])
        case .escort:
            return BuildCost(credits: 1_200, materials: [
                MaterialRequirement(resourceID: "refined-alloy", amount: 60),
                MaterialRequirement(resourceID: "alloy-tools", amount: 25),
                MaterialRequirement(resourceID: "power-cells", amount: 40)
            ])
        case .explorer:
            return BuildCost(credits: 1_500, materials: [
                MaterialRequirement(resourceID: "refined-alloy", amount: 50),
                MaterialRequirement(resourceID: "alloy-tools", amount: 20),
                MaterialRequirement(resourceID: "power-cells", amount: 50)
            ])
        }
    }

    var buildMinutes: Double {
        switch self {
        case .freighter: return 8
        case .scout: return 5
        case .escort: return 12
        case .explorer: return 15
        }
    }
}

enum ShipStatus: Hashable {
    case idle       // no orders — awaiting assignment (amber: wasted capacity)
    case docked     // RESERVED: at a stop on an assigned trade route. Not yet
                    // reachable in code — activate when trade routes land.
    case inTransit

    var isIdle: Bool { self == .idle }
}

struct Ship: Identifiable, Hashable {
    let id: ShipID
    var name: String
    let role: ShipRole
    var status: ShipStatus
    var locationID: Destination.ID
    var destinationID: Destination.ID?
    var remainingMinutes: Double
    var cargoNote: String?

    /// Takes already-resolved names so the model needn't know the registry.
    func statusLabel(locationName: String, destinationName: String?) -> String {
        switch status {
        case .inTransit:
            let eta = Format.duration(minutes: remainingMinutes)
            return "→ \(destinationName ?? "—") · \(eta)"
        case .docked: return "Docked at \(locationName)"
        case .idle: return "Idle at \(locationName)"
        }
    }

    mutating func applyTick(minutesPerTick: Double) {
        guard status == .inTransit else { return }
        remainingMinutes = max(0, remainingMinutes - minutesPerTick)
        if remainingMinutes <= 0 {
            locationID = destinationID ?? locationID
            destinationID = nil
            status = .idle
        }
    }

    // Serials 1...5 — the seed fleet, hand-numbered so GameState.seeded()
    // starts nextShipSerial at 6. HELIOS.md §18 S5.
    static let samples: [Ship] = [
        Ship(id: ShipID(serial: 1), name: "Meridian Hauler", role: .freighter, status: .inTransit,
             locationID: "vesta", destinationID: "kepler-7",
             remainingMinutes: 12, cargoNote: "Refined Alloy ×80"),
        Ship(id: ShipID(serial: 2), name: "Dust Runner", role: .freighter, status: .idle,
             locationID: "vesta", destinationID: nil,
             remainingMinutes: 0, cargoNote: "Empty hold"),
        Ship(id: ShipID(serial: 3), name: "Pale Comet", role: .scout, status: .inTransit,
             locationID: "kepler-7", destinationID: "sector-12",
             remainingMinutes: 34, cargoNote: nil),
        Ship(id: ShipID(serial: 4), name: "Ironwatch", role: .escort, status: .idle,
             locationID: "kepler-7", destinationID: nil,
             remainingMinutes: 0, cargoNote: nil),
        Ship(id: ShipID(serial: 5), name: "Long Horizon", role: .explorer, status: .inTransit,
             locationID: "kepler-7", destinationID: "anomaly",
             remainingMinutes: 210, cargoNote: "Survey equipment")
    ]
}
