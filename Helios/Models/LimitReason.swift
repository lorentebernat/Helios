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
    case power        // wired in stage 1b
    case workforce    // wired in stage 1c
}