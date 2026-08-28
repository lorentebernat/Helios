// ShipRow.swift
// Single ship row on FleetView. Pure function of its inputs — destination
// names are resolved by the caller, not looked up here.

import SwiftUI

struct ShipRow: View {
    let ship: Ship
    let locationName: String
    let destinationName: String?

    var body: some View {
        HStack(spacing: GameTheme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: GameTheme.Radius.iconBadge, style: .continuous)
                    .fill(.white.opacity(0.06))
                    .frame(width: GameTheme.Size.iconBadge, height: GameTheme.Size.iconBadge)
                Image(systemName: ship.role.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(GameTheme.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(ship.name)
                        .font(GameTheme.Font.rowTitle)
                        .foregroundStyle(GameTheme.textPrimary)
                    Text(ship.role.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(GameTheme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.white.opacity(0.06)))
                }
                Text(ship.statusLabel(locationName: locationName, destinationName: destinationName))
                    .font(GameTheme.Font.caption)
                    .foregroundStyle(ship.status.tint)
                if let cargo = ship.cargoNote {
                    Text(cargo)
                        .font(.system(size: 11))
                        .foregroundStyle(GameTheme.textSecondary)
                }
            }

            Spacer()

            Circle()
                .fill(ship.status.tint)
                .frame(width: 7, height: 7)
        }
        .padding(GameTheme.Spacing.md)
        .glass(cornerRadius: GameTheme.Radius.row, strokeOpacity: GameTheme.GlassStroke.subtle)
    }
}
