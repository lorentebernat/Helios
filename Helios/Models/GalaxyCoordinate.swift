//
//  GalaxyCoordinate.swift
//  Helios
//
//  Created by Bernat on 15/08/2026.
//

import Foundation

struct GalaxyCoordinate: Hashable {
    let galaxy: Int
    let system: Int
    let position: Int

    var display: String { "\(galaxy):\(system):\(position)" }

    /// Abstract distance units. NOT YET WIRED — travel time is still authored
    /// per destination. Phase 2 switches travel to derive from this, alongside
    /// fuel and the speed slider.
    func distance(to other: GalaxyCoordinate) -> Double {
        if galaxy != other.galaxy {
            return 20_000 * Double(abs(galaxy - other.galaxy))
        }
        if system != other.system {
            return 2_700 + 95 * Double(abs(system - other.system))
        }
        if position != other.position {
            return 1_000 + 5 * Double(abs(position - other.position))
        }
        return 5
    }
}
