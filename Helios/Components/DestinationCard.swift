//
//  DestinationCard.swift
//  Helios
//
//  Created by Bernat on 04/08/2026.
// Selectable destination row with a small rotating planet thumbnail.

import SwiftUI

struct DestinationCard: View {
    let destination: Destination
    let isSelected: Bool
    let isCurrentLocation: Bool

    var body: some View {
        HStack(spacing: GameTheme.Spacing.md) {
            PlanetBackdrop(
                diameter: 54,
                baseColor: destination.worldType.baseColor,
                bandColor: destination.worldType.bandColor,
                rotationDuration: 22,
                seed: destination.id.stableSeed
            )
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(destination.name)
                        .font(GameTheme.Font.rowTitle)
                        .foregroundStyle(GameTheme.textPrimary)
                    if isCurrentLocation {
                        Text("CURRENT")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(GameTheme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(GameTheme.accent.opacity(0.15)))
                    }
                }

                Text(destination.worldType.rawValue)
                    .font(GameTheme.Font.caption)
                    .foregroundStyle(GameTheme.textSecondary)

                HStack(spacing: 10) {
                    Label(
                        isCurrentLocation ? "—" : "\(destination.travelTimeMinutes)m",
                        systemImage: "clock.fill"
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(GameTheme.textSecondary)

                    HStack(spacing: 3) {
                        Circle().fill(destination.danger.tint).frame(width: 6, height: 6)
                        Text(destination.danger.rawValue)
                            .font(.system(size: 11))
                            .foregroundStyle(destination.danger.tint)
                    }

                    if let tier = destination.colonistTier {
                        Text(tier)
                            .font(.system(size: 11))
                            .foregroundStyle(GameTheme.textSecondary)
                    }
                }
            }

            Spacer()

            if !isCurrentLocation {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? GameTheme.accent : GameTheme.textSecondary.opacity(0.4))
            }
        }
        .padding(GameTheme.Spacing.md)
        .opacity(isCurrentLocation ? 0.6 : 1)
        .glass(
            cornerRadius: GameTheme.Radius.row,
            strokeOpacity: isSelected ? GameTheme.GlassStroke.prominent : GameTheme.GlassStroke.subtle
        )
    }
}
