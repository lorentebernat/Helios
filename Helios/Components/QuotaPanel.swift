//
//  QuotaPanel.swift
//  Helios
//
//  Created by Bernat on 13/10/2026.
//


// QuotaPanel.swift
// The Empire, compactly: what band you are in, how long until the deadline,
// and how much of the manifest has left the docks.
//
// Compact on purpose. MainColonyView is already crowded and its redesign is
// Phase 6 — this panel adds a row to it, it does not restructure it.
//
// A pure function of its inputs, like every other component here, so the screen
// resolves the live state and this just draws it. That is why FleetSummaryStrip
// survived three migrations without a change. HELIOS.md §21.

import SwiftUI

struct QuotaPanel: View {
    let band: StandingBand
    let reliability: Double
    let fill: Double
    let minutesRemaining: Double
    let lineCount: Int
    let stipendIfMet: Int

    /// Neutral unless the cycle is actually in trouble. Amber is reserved for
    /// alerts (HELIOS.md §16), and "most of the way through a cycle with most
    /// of the manifest still owed" is one.
    private var isOffTrack: Bool {
        fill < 0.95 && minutesRemaining <= 0.001
    }

    private var barTint: Color {
        isOffTrack ? GameTheme.warn : GameTheme.accent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: GameTheme.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("IMPERIAL QUOTA")
                        .font(GameTheme.Font.label)
                        .foregroundStyle(GameTheme.textSecondary)
                        .tracking(1)
                    Text(band.displayName)
                        .font(GameTheme.Font.heroTitle)
                        .foregroundStyle(GameTheme.textPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Format.duration(minutes: minutesRemaining))
                        .font(GameTheme.Font.heroValue)
                        .foregroundStyle(GameTheme.textPrimary)
                        .monospacedDigit()
                    Text("until assessment")
                        .font(GameTheme.Font.caption)
                        .foregroundStyle(GameTheme.textSecondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [barTint, barTint.opacity(0.6)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * min(1, max(0, fill)))
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(Int((fill * 100).rounded()))% shipped · \(lineCount) goods")
                    .font(GameTheme.Font.caption)
                    .foregroundStyle(GameTheme.textSecondary)
                Spacer()
                Text(band.posture)
                    .font(GameTheme.Font.caption)
                    .foregroundStyle(GameTheme.textSecondary)
            }

            HStack(spacing: GameTheme.Spacing.sm) {
                Label(
                    stipendIfMet > 0 ? "\(Format.integer(stipendIfMet)) on delivery" : "Collected at the dock",
                    systemImage: stipendIfMet > 0 ? "dollarsign.circle.fill" : "exclamationmark.triangle.fill"
                )
                .font(GameTheme.Font.caption)
                .foregroundStyle(stipendIfMet > 0 ? GameTheme.textSecondary : GameTheme.warn)

                Spacer()

                Text("Reliability \(Int((reliability * 100).rounded()))%")
                    .font(GameTheme.Font.caption)
                    .foregroundStyle(GameTheme.textSecondary)
            }
        }
        .padding(GameTheme.Spacing.xl)
        .glass(cornerRadius: GameTheme.Radius.hero, strokeOpacity: GameTheme.GlassStroke.prominent)
    }
}