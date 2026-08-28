//
//  WorkforceSection.swift
//  Helios
//
//  Created by Bernat on 04/08/2026.
// Assigned/required workforce display for a production chain.

import SwiftUI

struct WorkforceSection: View {
    let assigned: Int
    let required: Int
    let requiredTier: ColonistTier

    var isFullyStaffed: Bool { assigned >= required }

    var body: some View {
        VStack(alignment: .leading, spacing: GameTheme.Spacing.sm) {
            HStack {
                Text("Workforce")
                    .font(GameTheme.Font.rowTitle)
                    .foregroundStyle(GameTheme.textPrimary)
                Spacer()
                Text("\(assigned)/\(required)")
                    .font(GameTheme.Font.body)
                    .foregroundStyle(isFullyStaffed ? GameTheme.textPrimary : GameTheme.warn)
            }

            HStack(spacing: 6) {
                ForEach(0..<required, id: \.self) { i in
                    Image(systemName: i < assigned ? "person.fill" : "person")
                        .font(.system(size: 14))
                        .foregroundStyle(i < assigned ? GameTheme.accent : GameTheme.textSecondary.opacity(0.4))
                }
            }

            Text("Staffed by \(requiredTier.displayName)")
                .font(GameTheme.Font.caption)
                .foregroundStyle(GameTheme.textSecondary)
        }
        .padding(GameTheme.Spacing.lg)
        .glass(cornerRadius: GameTheme.Radius.panel, strokeOpacity: GameTheme.GlassStroke.standard)
    }
}
