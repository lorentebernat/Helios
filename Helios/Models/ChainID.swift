//
//  ChainID.swift
//  Helios
//
//  Created by Bernat on 02/09/2026.
//


// ChainID.swift
// A production chain's identity: a hand-authored slug, wrapped rather than a
// bare String. ChainDetail.ID is a SwiftUI navigation payload — registering
// `.navigationDestination(for: String.self)` would collide with any other
// route keyed by a raw String. Slugs (not UUIDs) so authored data is
// debuggable and survives save/load: a regenerated UUID would orphan every
// navigation reference and every save file on the next launch. HELIOS.md §18
// S14, §21.
//
// ExpressibleByStringLiteral keeps authored data readable — `id:
// "ice-harvester"` reads exactly like the UUID-default version did.

import Foundation

struct ChainID: Hashable, Codable {
    let slug: String
}

extension ChainID: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self.slug = value
    }
}