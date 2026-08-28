//
//  PopulationNeed.swift
//  Helios
//
//  Created by Bernat on 12/08/2026.
//


// PopulationNeed.swift
// A resource a population tier consumes, expressed per 100 colonists per minute.

import Foundation

struct PopulationNeed: Hashable {
    let resourceID: Resource.ID
    let per100PerMin: Double

    var name: String { Resource.byID(resourceID)?.name ?? resourceID }
    var icon: String { Resource.byID(resourceID)?.icon ?? "questionmark.circle" }
}