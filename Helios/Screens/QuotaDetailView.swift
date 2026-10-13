//
//  QuotaDetailView.swift
//  Helios
//
//  Created by Bernat on 13/10/2026.
//


// QuotaDetailView.swift
// The manifest in full: every line, what has gone, what is in store, and what
// the Empire has already announced for next cycle.
//
// Reads live state from GameState by the same pattern as ProductionDetailView —
// nothing is captured at push time, so the screen ticks while you watch it and
// dismisses itself if the quota disappears.
//
// The "Next cycle" section is the point of the screen as much as the current
// one. A quota you cannot see coming is a dice roll rather than a decision, and
// retooling only works if you know what you are retooling *for*. HELIOS.md §4.2.

import SwiftUI

struct QuotaDetailView: View {
    @Environment(GameState.self) private var game
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            VoidBackground()

            if let quota = game.currentQuota {
                content(for: quota)
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
        .onChange(of: game.currentQuota == nil) { _, gone in
            if gone { dismiss() }
        }
    }

    @ViewBuilder
    private func content(for quota: Quota) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GameTheme.Spacing.xl) {
                header(for: quota)

                QuotaPanel(
                    band: game.standing.band,
                    reliability: game.standing.reliability,
                    fill: game.quotaFill,
                    minutesRemaining: game.quotaMinutesRemaining,
                    lineCount: quota.lineCount,
                    stipendIfMet: game.stipendForAMetQuota
                )

                section("This cycle") {
                    ForEach(quota.sortedLines, id: \.good) { line in
                        QuotaLineRow(
                            good: line.good,
                            demanded: line.amount,
                            delivered: game.ledger.amountDelivered(of: line.good),
                            scheduled: quota.scheduledAmount(of: line.good, atTick: game.tickCount),
                            stockOnHand: game.activeColony.stock.amount(of: line.good)
                        )
                    }
                }

                if let next = game.nextQuota {
                    section("Next cycle") {
                        Text("Announced now so there is a full interval to retool. Due \(Format.duration(minutes: next.intervalMinutes)) after this one settles.")
                            .font(GameTheme.Font.caption)
                            .foregroundStyle(GameTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(next.sortedLines, id: \.good) { line in
                            QuotaLineRow(
                                good: line.good,
                                demanded: line.amount,
                                delivered: 0,
                                scheduled: nil,
                                stockOnHand: game.activeColony.stock.amount(of: line.good)
                            )
                        }
                    }
                }

                if let last = game.lastSettlement {
                    section("Last assessment") {
                        lastSettlementSummary(last)
                    }
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, GameTheme.Spacing.lg)
        }
    }

    @ViewBuilder
    private func header(for quota: Quota) -> some View {
        HStack {
            Button { dismiss() } label: {
                CircleGlassButton(systemImage: "chevron.left")
            }
            Spacer()
            VStack(spacing: 2) {
                Text("Manifest \(quota.id)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(GameTheme.textPrimary)
                Text(game.standing.band.posture)
                    .font(GameTheme.Font.caption)
                    .foregroundStyle(GameTheme.textSecondary)
            }
            Spacer()
            CircleGlassButton(systemImage: "ellipsis")
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: GameTheme.Spacing.sm) {
            Text(title)
                .font(GameTheme.Font.sectionTitle)
                .foregroundStyle(GameTheme.textPrimary)
            content()
        }
    }

    @ViewBuilder
    private func lastSettlementSummary(_ settlement: QuotaSettlement) -> some View {
        VStack(alignment: .leading, spacing: GameTheme.Spacing.sm) {
            HStack {
                Text(settlement.wasMet ? "Met in full" : "\(Int((settlement.fill * 100).rounded()))% delivered")
                    .font(GameTheme.Font.body)
                    .foregroundStyle(settlement.wasMet ? GameTheme.textPrimary : GameTheme.warn)
                Spacer()
                Text(settlement.stipend > 0
                     ? "\(Format.integer(settlement.stipend)) paid"
                     : "Nothing paid")
                    .font(GameTheme.Font.body)
                    .foregroundStyle(settlement.stipend > 0 ? GameTheme.textPrimary : GameTheme.warn)
            }

            ForEach(settlement.shortfalls.prefix(3), id: \.good) { shortfall in
                HStack(spacing: GameTheme.Spacing.sm) {
                    Image(systemName: Resource.byID(shortfall.good)?.icon ?? "questionmark.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(GameTheme.warn)
                        .frame(width: 16)
                    Text(Resource.byID(shortfall.good)?.name ?? shortfall.good)
                        .font(GameTheme.Font.caption)
                        .foregroundStyle(GameTheme.textPrimary)
                    Spacer()
                    Text("\(Int((shortfall.fill * 100).rounded()))%")
                        .font(GameTheme.Font.caption)
                        .foregroundStyle(GameTheme.warn)
                        .monospacedDigit()
                }
            }
        }
        .padding(GameTheme.Spacing.lg)
        .glass(cornerRadius: GameTheme.Radius.row, strokeOpacity: GameTheme.GlassStroke.subtle)
    }
}

#Preview {
    NavigationStack {
        QuotaDetailView()
    }
    .environment(GameState.seeded())
}