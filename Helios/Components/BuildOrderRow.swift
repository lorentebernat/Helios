//
//  BuildOrderRow.swift
//  Helios
//
//  Created by Bernat on 11/08/2026.
//


// BuildOrderRow.swift
// A ship under construction: progress bar + time remaining.

import SwiftUI

struct BuildOrderRow: View {
    let order: ShipBuildOrder

    var body: some View {
        HStack(spacing: GameTheme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: GameTheme.Radius.iconBadge, style: .continuous)
                    .fill(.white.opacity(0.06))
                    .frame(width: GameTheme.Size.iconBadge, height: GameTheme.Size.iconBadge)
                Image(systemName: "hammer.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(GameTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(order.name)
                        .font(GameTheme.Font.rowTitle)
                        .foregroundStyle(GameTheme.textPrimary)
                    Text(order.role.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(GameTheme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.white.opacity(0.06)))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.08))
                        Capsule()
                            .fill(GameTheme.accent.opacity(0.8))
                            .frame(width: geo.size.width * order.progress)
                    }
                }
                .frame(height: 4)

                Text("\(Format.duration(minutes: order.remainingMinutes)) remaining")
                    .font(GameTheme.Font.caption)
                    .foregroundStyle(GameTheme.textSecondary)
            }
        }
        .padding(GameTheme.Spacing.md)
        .glass(cornerRadius: GameTheme.Radius.row, strokeOpacity: GameTheme.GlassStroke.subtle)
    }
}
