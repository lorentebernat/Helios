//
//  TierRow.swift
//  Helios
//
//  Created by Bernat on 12/08/2026.
//


// TierRow.swift
// One rung of the population ladder: count against habitat capacity, plus
// needs and happiness status. Renders dimmed when the tier has no habitats.

import SwiftUI

struct TierRow: View {
    let state: TierPopulation

    private var isLocked: Bool { !state.isActive }

    private var statusTint: Color {
        if !state.basicNeedsMet { return GameTheme.warn }
        if state.happiness < 1 { return .yellow }
        return .green
    }

    private var statusText: String {
        if !state.basicNeedsMet {
            return "Needs \(Int(state.basicSatisfaction * 100))% met — colonists leaving"
        }
        if state.happiness < 1 { return "Unhappy · \(Int(state.happiness * 100))%" }
        return "Needs met"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(state.tier.displayName)
                    .font(GameTheme.Font.rowTitle)
                    .foregroundStyle(GameTheme.textPrimary)
                Spacer()
                if isLocked {
                    Text("No habitats")
                        .font(GameTheme.Font.caption)
                        .foregroundStyle(GameTheme.textSecondary)
                } else {
                    Text("\(Format.integer(Int(state.count))) / \(Format.integer(Int(state.capacity)))")
                        .font(GameTheme.Font.body)
                        .foregroundStyle(GameTheme.textPrimary)
                }
            }

            if !isLocked {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.08))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [GameTheme.accent, GameTheme.accent.opacity(0.6)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * state.fillFraction)
                    }
                }
                .frame(height: 6)

                HStack(spacing: 5) {
                    Circle()
                        .fill(statusTint)
                        .frame(width: 6, height: 6)
                    Text(statusText)
                        .font(GameTheme.Font.caption)
                        .foregroundStyle(statusTint)
                }
            }
        }
        .padding(GameTheme.Spacing.md)
        .opacity(isLocked ? 0.45 : 1)
        .glass(cornerRadius: GameTheme.Radius.row, strokeOpacity: GameTheme.GlassStroke.subtle)
    }
}
