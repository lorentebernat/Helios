//
//  ResearchSummaryStrip.swift
//  Helios
//
//  Created by Bernat on 04/08/2026.
//
// Top-of-screen Research Points balance and generation rate.

import SwiftUI

struct ResearchSummaryStrip: View {
    let points: Int
    let ratePerMin: Int

    var body: some View {
        HStack(spacing: GameTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("RESEARCH POINTS")
                    .font(GameTheme.Font.label)
                    .foregroundStyle(GameTheme.textSecondary)
                    .tracking(1)
                Text(Format.integer(points))
                    .font(GameTheme.Font.heroTitle)
                    .foregroundStyle(GameTheme.accent)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(ratePerMin)/min")
                    .font(GameTheme.Font.body)
                    .foregroundStyle(GameTheme.textPrimary)
                Text("from Ascendants")
                    .font(.system(size: 11))
                    .foregroundStyle(GameTheme.textSecondary)
            }
        }
        .padding(GameTheme.Spacing.xl)
        .glass(cornerRadius: GameTheme.Radius.hero, strokeOpacity: GameTheme.GlassStroke.prominent)
    }
}
