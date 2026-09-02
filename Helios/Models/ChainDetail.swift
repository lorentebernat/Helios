// ChainDetail.swift
// A production chain. `output` is optional because a pure energy producer has
// no material product — and therefore no output store that could fill and
// throttle it, which is what keeps a brownout from deepening itself.

import Foundation

struct ChainDetail: Hashable, Identifiable {
    let id: ChainID
    let icon: String
    let name: String
    var inputs: [ChainFlow]
    var output: ChainFlow?
    var energyProduced: Double         // per minute at full throughput
    var energyRequired: Double         // per minute at full throughput
    var workforceAssigned: Int         // display only for now — Phase 1b makes this computed from actual staffing
    let workforceRequired: Int
    let requiredTier: ColonistTier
    var status: ChainStatus
    var throughput: Double             // 0...1, achieved last tick

    /// Player-set output rate, 0...1. Five stops: 0, 0.25, 0.5, 0.75, 1 — coarse
    /// on purpose, this is a phone. Scales both production and energy draw in
    /// ProductionAllocator, so turning a chain down frees power for the rest of
    /// the colony. HELIOS.md Phase 1.
    var outputPercent: Double = 1

    /// Producers are exempt from the grid factor.
    var isEnergyProducer: Bool { energyProduced > 0 }

    var outputSummary: String {
        if let output { return output.rateDisplay(isOutput: true) }
        return "+\(Format.decimal(energyProduced)) MW"
    }

    var statusNote: String { status.note }
    var throughputPercent: Int { Int((throughput * 100).rounded()) }

    /// Looks up the authored blueprint for a chain id. Used to rehydrate a
    /// saved chain's fixed fields (name, icon, rates, energy figures) around
    /// its saved mutable state — a save stores ids and mutable fields only,
    /// never authored data. HELIOS.md §18 S14, Phase 1.5 Step 5.
    static func blueprint(for id: ChainID) -> ChainDetail? {
        samples.first { $0.id == id }
    }

    // MARK: - Seed network

    static let samples: [ChainDetail] = [
        // Extraction
        .init(id: "ice-harvester", icon: "snowflake", name: "Ice Harvester",
              inputs: [],
              output: ChainFlow(resourceID: "raw-ice", ratePerMin: 20),
              energyProduced: 0, energyRequired: 10,
              workforceAssigned: 3, workforceRequired: 3,
              requiredTier: .survivors, status: .running, throughput: 1,
              outputPercent: 1),

        .init(id: "ore-extractor", icon: "cube.fill", name: "Ore Extractor",
              inputs: [],
              output: ChainFlow(resourceID: "raw-ore", ratePerMin: 15),
              energyProduced: 0, energyRequired: 12,
              workforceAssigned: 4, workforceRequired: 4,
              requiredTier: .survivors, status: .running, throughput: 1,
              outputPercent: 1),

        // Energy — no material output by design
        .init(id: "power-plant", icon: "bolt.fill", name: "Power Plant",
              inputs: [],
              output: nil,
              energyProduced: 240, energyRequired: 0,
              workforceAssigned: 5, workforceRequired: 5,
              requiredTier: .survivors, status: .running, throughput: 1,
              outputPercent: 1),

        // Refining
        .init(id: "water-reclaimer", icon: "drop.fill", name: "Water Reclaimer",
              inputs: [ChainFlow(resourceID: "raw-ice", ratePerMin: 8)],
              output: ChainFlow(resourceID: "water", ratePerMin: 12),
              energyProduced: 0, energyRequired: 15,
              workforceAssigned: 3, workforceRequired: 3,
              requiredTier: .survivors, status: .running, throughput: 1,
              outputPercent: 1),

        .init(id: "oxygen-recycler", icon: "wind", name: "Oxygen Recycler",
              inputs: [ChainFlow(resourceID: "raw-ice", ratePerMin: 10)],
              output: ChainFlow(resourceID: "oxygen", ratePerMin: 12),
              energyProduced: 0, energyRequired: 15,
              workforceAssigned: 4, workforceRequired: 4,
              requiredTier: .survivors, status: .running, throughput: 1,
              outputPercent: 1),

        .init(id: "hydroponics-bay", icon: "leaf.fill", name: "Hydroponics Bay",
              inputs: [ChainFlow(resourceID: "water", ratePerMin: 6)],
              output: ChainFlow(resourceID: "grain", ratePerMin: 10),
              energyProduced: 0, energyRequired: 18,
              workforceAssigned: 5, workforceRequired: 5,
              requiredTier: .survivors, status: .running, throughput: 1,
              outputPercent: 1),

        // Manufacturing
        .init(id: "ration-bar-synth", icon: "fork.knife", name: "Ration Bar Synth",
              inputs: [
                ChainFlow(resourceID: "grain", ratePerMin: 8),
                ChainFlow(resourceID: "water", ratePerMin: 4)
              ],
              output: ChainFlow(resourceID: "ration-bars", ratePerMin: 6),
              energyProduced: 0, energyRequired: 20,
              workforceAssigned: 8, workforceRequired: 8,
              requiredTier: .survivors, status: .running, throughput: 1,
              outputPercent: 1),

        .init(id: "alloy-smelter", icon: "flame.fill", name: "Alloy Smelter",
              inputs: [ChainFlow(resourceID: "raw-ore", ratePerMin: 10)],
              output: ChainFlow(resourceID: "refined-alloy", ratePerMin: 7),
              energyProduced: 0, energyRequired: 30,
              workforceAssigned: 6, workforceRequired: 6,
              requiredTier: .settlers, status: .running, throughput: 1,
              outputPercent: 1),

        .init(id: "alloy-tool-fab", icon: "wrench.and.screwdriver.fill", name: "Alloy Tool Fab",
              inputs: [ChainFlow(resourceID: "refined-alloy", ratePerMin: 5)],
              output: ChainFlow(resourceID: "alloy-tools", ratePerMin: 4),
              energyProduced: 0, energyRequired: 25,
              workforceAssigned: 5, workforceRequired: 6,
              requiredTier: .settlers, status: .running, throughput: 1,
              outputPercent: 1),

        .init(id: "cell-factory", icon: "battery.100.bolt", name: "Cell Factory",
              inputs: [ChainFlow(resourceID: "refined-alloy", ratePerMin: 3)],
              output: ChainFlow(resourceID: "power-cells", ratePerMin: 6),
              energyProduced: 0, energyRequired: 25,
              workforceAssigned: 4, workforceRequired: 4,
              requiredTier: .settlers, status: .running, throughput: 1,
              outputPercent: 1)
    ]
}
