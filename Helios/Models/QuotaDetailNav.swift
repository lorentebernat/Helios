//
//  QuotaDetailNav.swift
//  Helios
//
//  Created by Bernat on 13/10/2026.
//


// QuotaDetailNav.swift
// Marker route for pushing the quota detail screen from the colony panel.
//
// A typed wrapper rather than a bare value, for the same reason `ChainID`
// exists: `.navigationDestination(for:)` keys on the payload's *type*, so a
// route carrying a raw `Int` would collide with any other route that ever
// carries one — and a collision is a silently dead tap, not a crash.
// HELIOS.md §18 S14, §23.

enum QuotaDetailNav: Hashable {
    case current
}