//
//  ResourcePill.swift
//  Helios
//
//  Created by Bernat on 04/08/2026.
// Small glass pill showing a single resource value (power %, oxygen, credits).

import SwiftUI

struct ResourcePill: View {
    let icon: String
    let value: String
    var tint: Color = GameTheme.accent

    var body: some View {
        HStack(spacing: GameTheme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(GameTheme.Font.body)
                .foregroundStyle(GameTheme.textPrimary)
        }
        .padding(.horizontal, GameTheme.Spacing.md)
        .padding(.vertical, 7)
        .glass(cornerRadius: GameTheme.Radius.pill, strokeOpacity: GameTheme.GlassStroke.subtle)
    }
}
