//
//  ResearchID.swift
//  Helios
//
//  Created by Bernat on 02/09/2026.
//


// ResearchID.swift
// A research project's identity — same rationale as ChainID (HELIOS.md §18
// S14, §21): a wrapper around a hand-authored slug, not a bare String, so it
// can't collide with other navigation routes and survives save/load without
// orphaning references.

import Foundation

struct ResearchID: Hashable, Codable {
    let slug: String
}

extension ResearchID: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self.slug = value
    }
}