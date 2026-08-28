//
//  ColonyStock.swift
//  Helios
//
//  Created by Bernat on 11/08/2026.
//


// ColonyStock.swift
// Colony-wide resource pool. All chains draw from and deposit into this, which
// is what makes chain interlinking emergent rather than declared.

import Foundation

struct ColonyStock {
    private var amounts: [Resource.ID: Double]

    init(_ seed: [Resource.ID: Double] = [:]) {
        self.amounts = seed
    }

    func amount(of id: Resource.ID) -> Double {
        amounts[id] ?? 0
    }

    func capacity(of id: Resource.ID) -> Double {
        Resource.byID(id)?.capacity ?? 0
    }

    func isFull(_ id: Resource.ID) -> Bool {
        amount(of: id) >= capacity(of: id)
    }

    func has(_ id: Resource.ID, atLeast needed: Double) -> Bool {
        amount(of: id) >= needed
    }

    func fillFraction(of id: Resource.ID) -> Double {
        let cap = capacity(of: id)
        guard cap > 0 else { return 0 }
        return min(1, max(0, amount(of: id) / cap))
    }

    /// Adds stock, clamped to the resource's capacity. Overflow is discarded.
    mutating func deposit(_ id: Resource.ID, _ quantity: Double) {
        amounts[id] = min(capacity(of: id), amount(of: id) + quantity)
    }

    /// All-or-nothing withdrawal. Returns false and changes nothing if short.
    @discardableResult
    mutating func withdraw(_ id: Resource.ID, _ quantity: Double) -> Bool {
        guard has(id, atLeast: quantity) else { return false }
        amounts[id] = amount(of: id) - quantity
        return true
    }
    /// Takes up to `quantity`, clamped at zero. Used by proportional allocation,
    /// where the ratio already guarantees the total is affordable — this just
    /// avoids all-or-nothing failing on floating-point dust.
    mutating func drain(_ id: Resource.ID, _ quantity: Double) {
        amounts[id] = max(0, amount(of: id) - quantity)
    }
}
