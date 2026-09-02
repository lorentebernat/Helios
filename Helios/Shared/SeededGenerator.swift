//
//  SeededGenerator.swift
//  Helios
//
//  Created by Bernat on 02/09/2026.
//


// SeededGenerator.swift
// A deterministic RandomNumberGenerator (SplitMix64) for reproducible
// "randomness" seeded from a stable identifier rather than true entropy.
//
// HELIOS.md §14 requires that any randomness touching the simulation be
// explicitly seeded, for portability to a server-authoritative multiplayer
// model. This type isn't throwaway for that reason alone — Phase 8's combat
// resolver will need exactly this shape of generator too.

import Foundation

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        // Mix the raw seed so nearby/small seeds (e.g. sequential hashValues)
        // don't produce visibly correlated early outputs.
        state = UInt64(bitPattern: Int64(seed)) &+ 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}