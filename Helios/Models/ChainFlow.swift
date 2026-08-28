//
//  ChainFlow.swift
//  Helios
//
//  Created by Bernat on 11/08/2026.
//


// ChainFlow.swift
// A resource requirement of a production chain — an input consumed or an output
// produced. NOT a store: stock lives in the colony-wide ColonyStock.

import Foundation

struct ChainFlow: Identifiable, Hashable {
    let resourceID: Resource.ID
    let ratePerMin: Double          // positive magnitude; direction from position

    var id: Resource.ID { resourceID }

    // Static registry lookups.
    private var resource: Resource? { Resource.byID(resourceID) }
    var name: String { resource?.name ?? resourceID }
    var icon: String { resource?.icon ?? "questionmark.circle" }
    var capacity: Double { resource?.capacity ?? 0 }

    func rateDisplay(isOutput: Bool) -> String {
        "\(isOutput ? "+" : "-")\(Format.decimal(ratePerMin))/min"
    }
}