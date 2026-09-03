// ShipRouteTarget.swift
// Navigation payload for pushing RouteSelectView from a specific ship. Wraps
// the id in a dedicated payload type — rather than pushing Ship.ID directly —
// so it can't collide with any other navigation destination that happens to
// be keyed by the same underlying type.

import Foundation

struct ShipRouteTarget: Hashable {
    let shipID: Ship.ID
}
