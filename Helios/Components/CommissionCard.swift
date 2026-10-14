//
//  CommissionCard.swift
//  Helios
//
//  Created by Bernat on 13/10/2026.
//


// CommissionCard.swift
// The optional contract, as a card you can take or wave away.
//
// Three states, and the card has to make the asymmetry between them obvious
// before the player commits, because the commitment is irreversible:
//
//   - on offer   — the terms, Accept and Ignore
//   - accepted   — progress, and whether it is keeping pace with its window
//   - dismissed  — a single quiet line, because ignoring is *doing nothing*
//
// **AMBER ONLY WHEN BEHIND PACE**, mirroring QuotaLineRow. A freshly accepted
// contract has delivered nothing and has its whole window ahead — that is not
// an alert. An offer the player hasn't accepted is never amber: a commission is
// a rush order you fill by producing during the window, so what is in store
// right now says little about whether it can be met. HELIOS.md §16.
//
// Purely presentational: the screen owns the decision and hands in two
// closures. HELIOS.md §21, "components stay pure functions of their inputs".

import SwiftUI

struct CommissionCard: View {
    let commission: Commission
    let ledger: QuotaLedger
    let tick: Int

    let onAccept: () -> Void
    let onIgnore: () -> Void

    private var progress: Double { commission.fill(from: ledger) }
    private var isMet: Bool { commission.isMet(by: ledger) }
    private var isBehind: Bool { !isMet && commission.isBehindPace(ledger: ledger, atTick: tick) }
    private var tint: Color { isBehind ? GameTheme.warn : GameTheme.accent }

    var body: some View {
        VStack(alignment: .leading, spacing: GameTheme.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("COMMISSION")
                        .font(GameTheme.Font.label)
                        .foregroundStyle(GameTheme.textSecondary)
                        .tracking(1)
                    Text(commission.accepted ? "Accepted" : "Offered")
                        .font(GameTheme.Font.sectionTitle)
                        .foregroundStyle(GameTheme.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Format.duration(minutes: commission.minutesRemaining(atTick: tick)))
                        .font(GameTheme.Font.body)
                        .foregroundStyle(GameTheme.textPrimary)
                        .monospacedDigit()
                    Text("to deliver")
                        .font(GameTheme.Font.footnote)
                        .foregroundStyle(GameTheme.textSecondary)
                }
            }

            VStack(spacing: GameTheme.Spacing.xs) {
                ForEach(commission.sortedLines, id: \.good) { line in
                    lineRow(good: line.good, amount: line.amount)
                }
            }

            if commission.accepted {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(GameTheme.track)
                        Capsule()
                            .fill(tint.opacity(0.75))
                            .frame(width: geo.size.width * min(1, max(0, progress)))
                    }
                }
                .frame(height: GameTheme.Size.progressBar)

                Text(isMet ? "Complete — pays on the deadline"
                     : isBehind ? "Behind pace. A contract is paid in full or not at all."
                     : "On pace. A contract is paid in full or not at all.")
                    .font(GameTheme.Font.caption)
                    .foregroundStyle(isBehind ? GameTheme.warn : GameTheme.textSecondary)
            } else {
                HStack(spacing: GameTheme.Spacing.lg) {
                    Label("\(Format.integer(commission.creditReward))", systemImage: "dollarsign.circle.fill")
                        .font(GameTheme.Font.caption)
                        .foregroundStyle(GameTheme.textSecondary)
                    Label("+\(Format.decimal(commission.standingReward * 100))% standing",
                          systemImage: "arrow.up.circle.fill")
                        .font(GameTheme.Font.caption)
                        .foregroundStyle(GameTheme.textSecondary)
                    Spacer()
                }

                Text("Fail after accepting and it costs \(Format.decimal(commission.standingPenalty * 100))%. Ignoring costs nothing.")
                    .font(GameTheme.Font.footnote)
                    .foregroundStyle(GameTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: GameTheme.Spacing.sm) {
                    Button(action: onAccept) {
                        Text("Accept")
                            .font(GameTheme.Font.button)
                            .foregroundStyle(GameTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .glass(cornerRadius: GameTheme.Radius.pill,
                                   strokeOpacity: GameTheme.GlassStroke.prominent)
                    }
                    .buttonStyle(.plain)

                    Button(action: onIgnore) {
                        Text("Ignore")
                            .font(GameTheme.Font.button)
                            .foregroundStyle(GameTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .glass(cornerRadius: GameTheme.Radius.pill,
                                   strokeOpacity: GameTheme.GlassStroke.subtle)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(GameTheme.Spacing.lg)
        .glass(cornerRadius: GameTheme.Radius.panel, strokeOpacity: GameTheme.GlassStroke.standard)
    }

    /// Extracted rather than inlined: a `let` as the first statement in a
    /// `ForEach` closure breaks type inference (HELIOS.md §23).
    @ViewBuilder
    private func lineRow(good: Resource.ID, amount: Double) -> some View {
        let behind = commission.isBehindPace(good, ledger: ledger, atTick: tick)
        HStack(spacing: GameTheme.Spacing.sm) {
            Image(systemName: Resource.byID(good)?.icon ?? "questionmark.circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(behind ? GameTheme.warn : GameTheme.textSecondary)
                .frame(width: 16)
            Text(Resource.byID(good)?.name ?? good)
                .font(GameTheme.Font.caption)
                .foregroundStyle(GameTheme.textPrimary)
            Spacer()
            Text(commission.accepted
                 ? "\(Format.decimal(ledger.amountDelivered(of: good))) / \(Format.decimal(amount))"
                 : Format.decimal(amount))
                .font(GameTheme.Font.body)
                .foregroundStyle(behind ? GameTheme.warn : GameTheme.textPrimary)
                .monospacedDigit()
        }
    }
}

/// What the card collapses to once waved away. Ignoring is doing nothing, so
/// this changes no state — it only gets the offer out of the way until the
/// Empire posts the next one.
struct DismissedCommissionRow: View {
    let onRestore: () -> Void

    var body: some View {
        Button(action: onRestore) {
            HStack(spacing: GameTheme.Spacing.sm) {
                Image(systemName: "tray")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(GameTheme.textSecondary)
                Text("Commission set aside")
                    .font(GameTheme.Font.caption)
                    .foregroundStyle(GameTheme.textSecondary)
                Spacer()
                Text("Review")
                    .font(GameTheme.Font.caption.weight(.medium))
                    .foregroundStyle(GameTheme.accent)
            }
            .padding(.horizontal, GameTheme.Spacing.lg)
            .padding(.vertical, GameTheme.Spacing.md)
            .glass(cornerRadius: GameTheme.Radius.row, strokeOpacity: GameTheme.GlassStroke.subtle)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews
// GameState.seeded() has no commission, so without these no commission UI
// path is previewable at all — the "dormant cases rot" condition of §23.

private extension Commission {
    func accepting() -> Commission {
        var copy = self
        copy.accepted = true
        return copy
    }
}

#Preview("Offered") {
    CommissionCard(commission: .sample, ledger: .empty(forCommission: .sample),
                   tick: 250, onAccept: {}, onIgnore: {})
        .padding()
        .background(GameTheme.voidBottom)
}

#Preview("Accepted, on pace") {
    CommissionCard(commission: .sample.accepting(),
                   ledger: QuotaLedger(quotaID: 1, delivered: ["raw-ice": 50, "oxygen": 30, "power-cells": 40]),
                   tick: 300, onAccept: {}, onIgnore: {})
        .padding()
        .background(GameTheme.voidBottom)
}

#Preview("Accepted, behind") {
    CommissionCard(commission: .sample.accepting(),
                   ledger: QuotaLedger(quotaID: 1, delivered: ["raw-ice": 87.5, "oxygen": 5]),
                   tick: 340, onAccept: {}, onIgnore: {})
        .padding()
        .background(GameTheme.voidBottom)
}

#Preview("Set aside") {
    DismissedCommissionRow(onRestore: {})
        .padding()
        .background(GameTheme.voidBottom)
}
