//
//  LimitReason.swift
//  Helios
//
//  Created by Bernat on 20/08/2026.
//


// LimitReason.swift
// Why a chain is running below its desired throughput. Only the single BINDING
// constraint is reported — that's the one the player can act on.

import Foundation

enum LimitReason: Hashable {
    case input(Resource.ID)
    case power        // live — ProductionAllocator's grid factor binds this (HELIOS.md §9)
    case workforce     // not yet produced — waiting on Phase 1b, workforce as a throughput factor
}
