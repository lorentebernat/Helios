// BuildCost.swift
// What it takes to build something. Materials are drawn from the building
// colony's stock, deducted in full at queue time.

import Foundation

struct MaterialRequirement: Hashable {
    let resourceID: Resource.ID
    let amount: Double

    private var resource: Resource? { Resource.byID(resourceID) }
    var name: String { resource?.name ?? resourceID }
    var icon: String { resource?.icon ?? "questionmark.circle" }
}

struct BuildCost: Hashable {
    let credits: Int
    var materials: [MaterialRequirement] = []
}
