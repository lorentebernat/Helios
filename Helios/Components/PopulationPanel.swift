//
//  PopulationPanel.swift
//  Helios
//
//  Created by Bernat on 12/08/2026.
//


// PopulationPanel.swift
// The colony's population across the tier ladder. Progressive reveal: active
// tiers plus the next locked rung; anything beyond stays hidden.

import SwiftUI

struct PopulationPanel: View {
    let population: Population

    var body: some View {
        VStack(alignment: .leading, spacing: GameTheme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("POPULATION")
                        .font(GameTheme.Font.label)
                        .foregroundStyle(GameTheme.textSecondary)
                        .tracking(1)
                    Text("\(Format.integer(Int(population.total))) colonists")
                        .font(GameTheme.Font.heroTitle)
                        .foregroundStyle(GameTheme.textPrimary)
                }
                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(population.visibleTiers) { state in
                    TierRow(state: state)
                }
            }
        }
        .padding(GameTheme.Spacing.xl)
        .glass(cornerRadius: GameTheme.Radius.hero, strokeOpacity: GameTheme.GlassStroke.prominent)
    }
}