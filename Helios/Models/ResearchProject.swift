// ResearchProject.swift
// A single research project: cost in Research Points, category, and status.

import SwiftUI

enum ResearchCategory: String, CaseIterable {
    case production = "Production"
    case fleet = "Fleet"
    case defense = "Defense"
    case habitat = "Habitat"

    var icon: String {
        switch self {
        case .production: return "cube.transparent.fill"
        case .fleet: return "paperplane.fill"
        case .defense: return "shield.lefthalf.filled"
        case .habitat: return "house.fill"
        }
    }
}

enum ResearchStatus: Equatable {
    case locked(requiredTier: String)
    case available
    case inProgress(pointsInvested: Int)
    case completed
}

struct ResearchProject: Identifiable {
    let id = UUID()
    let icon: String
    let name: String
    let summary: String
    let category: ResearchCategory
    let pointCost: Int
    let status: ResearchStatus

    var progress: Double {
        switch status {
        case .inProgress(let invested): return min(1, Double(invested) / Double(pointCost))
        case .completed: return 1
        default: return 0
        }
    }

    static let samples: [ResearchProject] = [
        .init(icon: "bolt.fill", name: "Efficient Power Routing", summary: "+15% output on all Power chains",
              category: .production, pointCost: 400, status: .inProgress(pointsInvested: 260)),
        .init(icon: "shippingbox.fill", name: "Reinforced Cargo Holds", summary: "+20% freighter capacity",
              category: .fleet, pointCost: 250, status: .available),
        .init(icon: "shield.fill", name: "Adaptive Plating", summary: "+10% escort hull strength",
              category: .defense, pointCost: 500, status: .locked(requiredTier: "Settlers")),
        .init(icon: "leaf.fill", name: "Closed-Loop Recycling", summary: "Oxygen chains consume 25% less input",
              category: .habitat, pointCost: 300, status: .completed),
        .init(icon: "wrench.and.screwdriver.fill", name: "Alloy Synthesis II", summary: "Unlocks Refined Alloy chain",
              category: .production, pointCost: 600, status: .locked(requiredTier: "Settlers"))
    ]
}
