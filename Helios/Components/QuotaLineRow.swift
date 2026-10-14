//
//  QuotaLineRow.swift
//  Helios
//
//  Created by Bernat on 13/10/2026.
//


// QuotaLineRow.swift
// One line of a manifest: what the Empire wants, what has gone, and what is
// still in the warehouse.
//
// Borrows FlowResourceCard's vocabulary — icon, name, a capsule fill bar, a
// "have / want" caption underneath — laid out horizontally because a manifest
// is a list rather than a diagram. Same shapes, different axis.
//
// **AMBER ONLY WHEN A LINE IS ACTUALLY BEHIND.** The quota's own schedule says
// how much should have gone by now; a line that matches it is fine however
// little of the total has shipped, because the rest of the interval is still
// coming. Colouring by raw progress would paint almost every line amber for
// most of every cycle, which is how a warning colour stops meaning anything.
// Amber is reserved for alerts. HELIOS.md §16.

import SwiftUI

struct QuotaLineRow: View {
    let good: Resource.ID
    let demanded: Double
    let delivered: Double

    /// What should have gone by now, from the quota's schedule. Pass `nil` for
    /// a manifest that has not started yet — the next cycle's preview.
    let scheduled: Double?

    let stockOnHand: Double

    /// A line is behind when it has missed the pace by more than rounding.
    private var isBehind: Bool {
        guard let scheduled, scheduled > 0 else { return false }
        return delivered < scheduled * (1 - Quota.paceTolerance)
    }

    private var tint: Color { isBehind ? GameTheme.warn : GameTheme.accent }

    private var fraction: Double {
        guard demanded > 0 else { return 0 }
        return min(1, max(0, delivered / demanded))
    }

    private var resource: Resource? { Resource.byID(good) }

    var body: some View {
        HStack(spacing: GameTheme.Spacing.md) {
            Image(systemName: resource?.icon ?? "questionmark.circle")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: GameTheme.Spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(resource?.name ?? good)
                        .font(GameTheme.Font.rowTitle)
                        .foregroundStyle(GameTheme.textPrimary)
                    Spacer()
                    Text("\(Format.decimal(delivered)) / \(Format.decimal(demanded))")
                        .font(GameTheme.Font.body)
                        .foregroundStyle(tint)
                        .monospacedDigit()
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(GameTheme.track)
                        if let scheduled, demanded > 0, scheduled < demanded {
                            // A hairline where the schedule says you should be.
                            // Without it "behind" is a colour with nothing to
                            // compare against.
                            Capsule()
                                .fill(.white.opacity(0.25))
                                .frame(width: 1.5)
                                .offset(x: geo.size.width * min(1, scheduled / demanded))
                        }
                        Capsule()
                            .fill(tint.opacity(0.75))
                            .frame(width: geo.size.width * fraction)
                    }
                }
                .frame(height: GameTheme.Size.progressBar)

                HStack {
                    Text("\(Format.decimal(stockOnHand)) in store")
                        .font(GameTheme.Font.footnote)
                        .foregroundStyle(GameTheme.textSecondary)
                    Spacer()
                    if isBehind {
                        Text("Behind schedule")
                            .font(GameTheme.Font.footnote.weight(.semibold))
                            .foregroundStyle(GameTheme.warn)
                    }
                }
            }
        }
        .padding(GameTheme.Spacing.md)
        .glass(
            cornerRadius: GameTheme.Radius.row,
            strokeOpacity: isBehind ? GameTheme.GlassStroke.prominent : GameTheme.GlassStroke.subtle
        )
    }
}
#Preview {
    VStack(spacing: GameTheme.Spacing.sm) {
        QuotaLineRow(good: "power-cells", demanded: 1_260, delivered: 640, scheduled: 630, stockOnHand: 54)
        QuotaLineRow(good: "water", demanded: 120, delivered: 31, scheduled: 60, stockOnHand: 61)
        QuotaLineRow(good: "grain", demanded: 480, delivered: 0, scheduled: nil, stockOnHand: 30)
    }
    .padding()
    .background(GameTheme.voidBottom)
}
