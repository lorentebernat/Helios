//
//  CategoryChip.swift
//  Helios
//
//  Created by Bernat on 04/08/2026.
// Selectable category icon chip (Power, Storage, Habitat, etc.) on MainColonyView.

import SwiftUI

struct CategoryChip: View {
    let icon: String
    let label: String
    let isActive: Bool
    var fillsWidth: Bool = false

    var body: some View {
        VStack(spacing: GameTheme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isActive ? GameTheme.accent : GameTheme.textSecondary)
            Text(label)
                .font(GameTheme.Font.chipLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(isActive ? GameTheme.textPrimary : GameTheme.textSecondary)
        }
        .frame(width: fillsWidth ? nil : 68, height: 64)
        .frame(maxWidth: fillsWidth ? .infinity : nil)
        .background(
            RoundedRectangle(cornerRadius: GameTheme.Radius.chip, style: .continuous)
                .fill(isActive ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: GameTheme.Radius.chip, style: .continuous)
                .strokeBorder(isActive ? GameTheme.accentDim : .clear, lineWidth: 1)
        )
    }
}
