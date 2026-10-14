// ResearchProject.swift
// A single research project: cost in Research Points, category, and status.

import Foundation

enum ResearchCategory: String, CaseIterable {
    case production = "Production"
    case fleet = "Fleet"
    case defense = "Defense"
    case habitat = "Habitat"
}

// Codable (Phase 1.5 Step 5): synthesised, via SE-0295 enum-with-associated-
// values support — `status` is a project's saved mutable field.
enum ResearchStatus: Equatable, Codable {
    case locked(requiredTier: String)
    case available
    case inProgress(pointsInvested: Int)
    case completed
}

struct ResearchProject: Identifiable {
    let id: ResearchID
    let icon: String
    let name: String
    let summary: String
    let category: ResearchCategory
    let pointCost: Int

    /// `var`, not `let`: Phase 1.5 Step 5's blueprint-overlay decode assigns
    /// this after rehydrating everything else from `blueprint(for:)`.
    var status: ResearchStatus

    var progress: Double {
        switch status {
        case .inProgress(let invested): return min(1, Double(invested) / Double(pointCost))
        case .completed: return 1
        default: return 0
        }
    }

    /// Looks up the authored blueprint for a research project id — same
    /// rationale as `ChainDetail.blueprint(for:)`. HELIOS.md §18 S14, Phase
    /// 1.5 Step 5.
    static func blueprint(for id: ResearchID) -> ResearchProject? {
        samples.first { $0.id == id }
    }

    static let samples: [ResearchProject] = [
        .init(id: "efficient-power-routing", icon: "bolt.fill", name: "Efficient Power Routing", summary: "+15% output on all Power chains",
              category: .production, pointCost: 400, status: .inProgress(pointsInvested: 260)),
        .init(id: "reinforced-cargo-holds", icon: "shippingbox.fill", name: "Reinforced Cargo Holds", summary: "+20% freighter capacity",
              category: .fleet, pointCost: 250, status: .available),
        .init(id: "adaptive-plating", icon: "shield.fill", name: "Adaptive Plating", summary: "+10% escort hull strength",
              category: .defense, pointCost: 500, status: .locked(requiredTier: "Settlers")),
        .init(id: "closed-loop-recycling", icon: "leaf.fill", name: "Closed-Loop Recycling", summary: "Oxygen chains consume 25% less input",
              category: .habitat, pointCost: 300, status: .completed),
        .init(id: "alloy-synthesis-ii", icon: "wrench.and.screwdriver.fill", name: "Alloy Synthesis II", summary: "Unlocks Refined Alloy chain",
              category: .production, pointCost: 600, status: .locked(requiredTier: "Settlers"))
    ]
}

// MARK: - Codable (Phase 1.5 Step 5)

// Same blueprint-overlay shape as ChainDetail: a save stores only `id` and
// `status`; everything authored (name, icon, summary, category, cost) is
// rehydrated from `blueprint(for:)`. Declared in an extension so the
// compiler-synthesised memberwise initialiser (used by `samples` above)
// stays intact. HELIOS.md §18 S14, §21.
extension ResearchProject: Codable {
    /// Thrown when a saved project's id no longer exists in `samples`. The
    /// project should disappear from the save, not resurface as a husk;
    /// `GameSave`'s decoder catches this per-project via `ResearchSlot` and
    /// drops just that entry.
    struct UnknownID: Error {
        let id: ResearchID
    }

    private enum CodingKeys: String, CodingKey {
        case id, status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(ResearchID.self, forKey: .id)
        guard let blueprint = ResearchProject.blueprint(for: id) else {
            throw UnknownID(id: id)
        }
        self = blueprint
        self.status = try container.decode(ResearchStatus.self, forKey: .status)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(status, forKey: .status)
    }
}
