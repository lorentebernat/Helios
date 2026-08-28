// ShipRouteTarget.swift
// Navigation payload for pushing RouteSelectView from a specific ship.
// Wraps the id (rather than pushing a raw UUID) so it can't collide with
// ChainDetail.ID nav destinations.

import Foundation

struct ShipRouteTarget: Hashable {
    let shipID: Ship.ID
}
