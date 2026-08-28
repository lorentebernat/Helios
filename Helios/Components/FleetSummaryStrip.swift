//
//  FleetSummaryStrip.swift
//  Helios
//
//  Created by Bernat on 04/08/2026.
// FleetSummaryStrip.swift
// Top-of-screen summary: total ships, in-transit count, idle count.

import SwiftUI

struct FleetSummaryStrip: View {
    let ships: [Ship]

    var idleCount: Int { ships.filter { $0.status.isIdle }.count }
    var inTransitCount: Int {
        ships.filter { $0.status == .inTransit }.count
    }

    var body: some View {
        HStack(spacing: GameTheme.Spacing.sm) {
            summaryPill(icon: "paperplane.fill", value: "\(ships.count)", label: "Total", tint: GameTheme.textPrimary)
            summaryPill(icon: "arrow.right.circle.fill", value: "\(inTransitCount)", label: "Transit", tint: GameTheme.accent)
            summaryPill(icon: "exclamationmark.circle.fill", value: "\(idleCount)", label: "Idle", tint: idleCount > 0 ? GameTheme.warn : GameTheme.textSecondary)
        }
    }

    private func summaryPill(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                Text(value)
                    .font(GameTheme.Font.heroValue)
                    .foregroundStyle(tint)
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(GameTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, GameTheme.Spacing.md)
        .glass(cornerRadius: GameTheme.Radius.row, strokeOpacity: GameTheme.GlassStroke.subtle)
    }
}
