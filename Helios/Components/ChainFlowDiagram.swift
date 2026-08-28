// ChainFlowDiagram.swift
// Input(s) -> processing -> output. Stock comes from the colony pool, so cards
// show colony-wide holdings. Chains with no inputs or no material output get a
// badge in place of the missing column.

import SwiftUI

struct ChainFlowDiagram: View {
    let inputs: [ChainFlow]
    let output: ChainFlow?
    let energyProduced: Double
    let stock: ColonyStock
    let isLimited: Bool

    var body: some View {
        HStack(spacing: 0) {
            if inputs.isEmpty {
                badge(icon: "mountain.2.fill", label: "Raw\nextraction")
            } else {
                VStack(spacing: 12) {
                    ForEach(inputs) { input in
                        FlowResourceCard(
                            flow: input,
                            stock: stock.amount(of: input.resourceID),
                            isBlocked: isLimited
                        )
                    }
                }
            }

            VStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isLimited ? GameTheme.warn : GameTheme.accent)
                Text(isLimited ? "LIMITED" : "PROCESSING")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isLimited ? GameTheme.warn : GameTheme.accent)
                    .tracking(0.5)
            }
            .frame(maxWidth: .infinity)

            if let output {
                FlowResourceCard(
                    flow: output,
                    stock: stock.amount(of: output.resourceID),
                    isOutput: true,
                    isBlocked: isLimited
                )
            } else {
                badge(icon: "bolt.fill",
                      label: "\(Format.decimal(energyProduced))\nMW to grid",
                      tint: .yellow)
            }
        }
    }

    private func badge(icon: String, label: String, tint: Color = GameTheme.textSecondary) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(tint)
            Text(label)
                .font(GameTheme.Font.caption)
                .foregroundStyle(GameTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(GameTheme.Spacing.md)
        .frame(width: 108)
        .glass(cornerRadius: GameTheme.Radius.row, strokeOpacity: GameTheme.GlassStroke.subtle)
    }
}
