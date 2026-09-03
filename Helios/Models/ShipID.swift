//
//  ShipID.swift
//  Helios
//
//  Created by Bernat on 03/09/2026.
//


// ShipID.swift
// A ship's identity: a monotonic serial rather than a UUID. Ship.id used to
// be `UUID()`, generated inside GameState.tick() the moment a build order
// completed — the one place the pure simulation step actually violated
// HELIOS.md §14's "no randomness inside tick()" hedge, needed for Phase 4's
// replay and Phase 9's server reconciliation to ever produce identical
// results from identical inputs. A serial, issued from a counter that is
// itself part of saved state (GameState.nextShipSerial), is deterministic:
// the same sequence of actions always issues the same ids. HELIOS.md §18 S5.

import Foundation

struct ShipID: Hashable, Codable {
    let serial: Int
}