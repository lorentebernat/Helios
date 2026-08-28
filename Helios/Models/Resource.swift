//
//  Resource.swift
//  Helios
//
//  Created by Bernat on 11/08/2026.
//


// Resource.swift
// Authored resource registry. Static by design — slug ids so chains and seed
// data can reference them, per-resource storage capacity.

import Foundation

struct Resource: Identifiable, Hashable {
    let id: String          // slug, e.g. "refined-alloy"
    let name: String
    let icon: String
    let capacity: Double

    static let all: [Resource] = [
        .init(id: "raw-ice",       name: "Raw Ice",       icon: "snowflake",                   capacity: 250),
        .init(id: "raw-ore",       name: "Raw Ore",       icon: "cube.fill",                   capacity: 300),
        .init(id: "power-cells",   name: "Power Cells",   icon: "bolt.fill",                   capacity: 200),
        .init(id: "water",         name: "Water",         icon: "drop.fill",                   capacity: 200),
        .init(id: "grain",         name: "Grain",         icon: "leaf.fill",                   capacity: 200),
        .init(id: "oxygen",        name: "Oxygen",        icon: "wind",                        capacity: 200),
        .init(id: "ration-bars",   name: "Ration Bars",   icon: "fork.knife",                  capacity: 400),
        .init(id: "refined-alloy", name: "Refined Alloy", icon: "square.stack.3d.up.fill",     capacity: 150),
        .init(id: "alloy-tools",   name: "Alloy Tools",   icon: "wrench.and.screwdriver.fill", capacity: 150)
    ]

    static func byID(_ id: Resource.ID) -> Resource? {
        all.first { $0.id == id }
    }
}