// ChainStatus.swift
// The operating state of a production chain — the REASON it isn't at full
// throughput. Magnitude lives separately in ChainDetail.throughput.
//
// NO SwiftUI HERE — tints live in DesignSystem/ModelStyles.swift.
//
// Codable (Phase 1.5 Step 5): synthesised, via SE-0295 enum-with-associated-
// values support. Verified round-tripping in HeliosTests (chainStatusRoundTrips).

import Foundation

enum ChainStatus: Hashable, Codable {
    case running                    // unconstrained (may still be below 100% by player choice)
    case limited(LimitReason)       // throttled; zero throughput is just the extreme
    case stalled                    // output store full, nowhere to put product
    case paused                     // player deliberately set output to 0%

    var isNominal: Bool {
        if case .running = self { return true }
        return false
    }

    // Player-facing note. TODO: localisation will eventually want this in the
    // view layer.
    var note: String {
        switch self {
        case .running: return "Running smoothly"
        case .limited(.input(let id)):
            let name = Resource.byID(id)?.name ?? id
            return "Limited by \(name)"
        case .limited(.power): return "Limited by power"
        case .limited(.workforce): return "Understaffed"
        case .stalled: return "Output full"
        case .paused: return "Paused"
        }
    }
}
