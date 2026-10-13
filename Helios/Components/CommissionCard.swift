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
//   - accepted   — progress, and whether it would pay if the deadline were now
//   - dismissed  — a single quiet line, because ignoring is *doing nothing*
//
// Purely presentational: the screen owns the decision and hands in two
// closures. HELIOS.md §21, "components stay pure functions of their inputs".

import SwiftUI

struct CommissionCard: View {
    let commission: Commission
    let progress: Double
    let wouldBeMet: Bool
    let minutesRemaining: Double

    /// Which goods are already covered by what is in store, so the terms can be
    /// judged without doing the arithmetic by hand.
    let shortfalls: [Resource.ID]

    let onAccept: () -> Void
    let onIgnore: () -> Void

    private var tint: Color {
        guard commission.accepted else { return GameTheme.accent }
        return wouldBeMet ? GameTheme.accent : GameTheme.warn
    }

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
                    Text(Format.duration(minutes: minutesRemaining))
                        .font(GameTheme.Font.body)
                        .foregroundStyle(GameTheme.textPrimary)
                        .monospacedDigit()
                    Text("to deliver")
                        .font(.system(size: 10))
                        .foregroundStyle(GameTheme.textSecondary)
                }
            }

            VStack(spacing: 6) {
                ForEach(commission.sortedLines, id: \.good) { line in
                    HStack(spacing: GameTheme.Spacing.sm) {
                        Image(systemName: Resource.byID(line.good)?.icon ?? "questionmark.circle")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(shortfalls.contains(line.good) ? GameTheme.warn : GameTheme.textSecondary)
                            .frame(width: 16)
                        Text(Resource.byID(line.good)?.name ?? line.good)
                            .font(GameTheme.Font.caption)
                            .foregroundStyle(GameTheme.textPrimary)
                        Spacer()
                        Text(Format.decimal(line.amount))
                            .font(GameTheme.Font.body)
                            .foregroundStyle(shortfalls.contains(line.good) ? GameTheme.warn : GameTheme.textPrimary)
                            .monospacedDigit()
                    }
                }
            }

            if commission.accepted {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.08))
                        Capsule()
                            .fill(tint.opacity(0.75))
                            .frame(width: geo.size.width * min(1, max(0, progress)))
                    }
                }
                .frame(height: 5)

                Text(wouldBeMet
                     ? "Complete — pays on the deadline"
                     : "Short. A contract is paid in full or not at all.")
                    .font(GameTheme.Font.caption)
                    .foregroundStyle(wouldBeMet ? GameTheme.textSecondary : GameTheme.warn)
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
                    .font(.system(size: 10))
                    .foregroundStyle(GameTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: GameTheme.Spacing.sm) {
                    Button(action: onAccept) {
                        Text("Accept")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(GameTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .glass(cornerRadius: GameTheme.Radius.pill,
                                   strokeOpacity: GameTheme.GlassStroke.prominent)
                    }
                    .buttonStyle(.plain)

                    Button(action: onIgnore) {
                        Text("Ignore")
                            .font(.system(size: 13, weight: .medium))
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
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(GameTheme.accent)
            }
            .padding(.horizontal, GameTheme.Spacing.lg)
            .padding(.vertical, GameTheme.Spacing.md)
            .glass(cornerRadius: GameTheme.Radius.row, strokeOpacity: GameTheme.GlassStroke.subtle)
        }
        .buttonStyle(.plain)
    }
}