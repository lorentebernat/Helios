// FlowResourceCard.swift
// Single input/output card in ChainFlowDiagram. Static data (name/icon/capacity)
// comes from the flow's registry lookup; dynamic stock is passed in.

import SwiftUI

struct FlowResourceCard: View {
    let flow: ChainFlow
    let stock: Double
    var isOutput: Bool = false
    var isBlocked: Bool = false

    private var tint: Color {
        if isBlocked { return GameTheme.warn }
        return isOutput ? GameTheme.accent : GameTheme.textPrimary
    }

    private var fillFraction: Double {
        guard flow.capacity > 0 else { return 0 }
        return min(1, max(0, stock / flow.capacity))
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: flow.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(tint)

            Text(flow.name)
                .font(GameTheme.Font.caption)
                .foregroundStyle(GameTheme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(flow.rateDisplay(isOutput: isOutput))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)

            VStack(spacing: 3) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.08))
                        Capsule()
                            .fill(tint.opacity(0.7))
                            .frame(width: geo.size.width * fillFraction)
                    }
                }
                .frame(height: 5)

                Text("\(Format.decimal(stock))/\(Format.decimal(flow.capacity))")
                    .font(.system(size: 10))
                    .foregroundStyle(GameTheme.textSecondary)
            }
        }
        .padding(GameTheme.Spacing.md)
        .frame(width: 108)
        .glass(
            cornerRadius: GameTheme.Radius.row,
            strokeOpacity: isBlocked ? GameTheme.GlassStroke.prominent : GameTheme.GlassStroke.subtle
        )
    }
}
