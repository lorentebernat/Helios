// ProductionChainRow.swift
// Row summarising a chain: icon, name, binding constraint, and achieved
// throughput. Tappable to open ProductionDetailView.

import SwiftUI

struct ProductionChainRow: View {
    let chain: ChainDetail

    var body: some View {
        HStack(spacing: GameTheme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: GameTheme.Radius.iconBadge, style: .continuous)
                    .fill(.white.opacity(0.06))
                    .frame(width: GameTheme.Size.iconBadge, height: GameTheme.Size.iconBadge)
                Image(systemName: chain.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(GameTheme.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(chain.name)
                        .font(GameTheme.Font.rowTitle)
                        .foregroundStyle(GameTheme.textPrimary)

                    // A throttled chain is a deliberate choice, not a warning —
                    // secondary tint, not amber (amber is reserved for alerts
                    // and blocked states, HELIOS.md §16).
                    if chain.outputPercent > 0, chain.outputPercent < 1 {
                        Text("\(Int((chain.outputPercent * 100).rounded()))%")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(GameTheme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.white.opacity(0.08)))
                    }
                }
                Text(chain.statusNote)
                    .font(GameTheme.Font.caption)
                    .foregroundStyle(chain.status.tint)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(chain.outputSummary)
                    .font(GameTheme.Font.body)
                    .foregroundStyle(GameTheme.textPrimary)
                HStack(spacing: 5) {
                    Text("\(chain.throughputPercent)%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(GameTheme.textSecondary)
                    Circle()
                        .fill(chain.status.indicator)
                        .frame(width: 7, height: 7)
                }
            }
        }
        .padding(GameTheme.Spacing.md)
        .glass(cornerRadius: GameTheme.Radius.row, strokeOpacity: GameTheme.GlassStroke.subtle)
        // Paused (0%) dims the whole row, matching locked-tier/locked-research
        // treatment — a visibly inactive chain, not a broken one.
        .opacity(chain.outputPercent <= 0 ? 0.55 : 1)
    }
}
