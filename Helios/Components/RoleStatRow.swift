//
//  RoleStatRow.swift
//  Helios
//
//  Created by Bernat on 11/08/2026.
//


// RoleStatRow.swift
// Stat readout for a ship role in the build sheet.
// NOTE: only `speed` currently affects gameplay. Cargo, shields, and weapons
// are display-only placeholders pending real cargo/combat systems.

import SwiftUI

struct RoleStatRow: View {
    let role: ShipRole

    var body: some View {
        HStack(spacing: 0) {
            stat(icon: "speedometer", label: "Speed",
                 value: "×\(Format.decimal(role.speedMultiplier))")
            stat(icon: "shippingbox.fill", label: "Cargo",
                 value: "\(role.cargoCapacity)")
            stat(icon: "shield.lefthalf.filled", label: "Shields",
                 value: "\(role.shields)")
            stat(icon: "scope", label: "Weapons",
                 value: "\(role.weapons)")
        }
        .padding(.vertical, GameTheme.Spacing.md)
        .glass(cornerRadius: GameTheme.Radius.row, strokeOpacity: GameTheme.GlassStroke.subtle)
    }

    private func stat(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(GameTheme.accent)
            Text(value)
                .font(GameTheme.Font.body)
                .foregroundStyle(GameTheme.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(GameTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
