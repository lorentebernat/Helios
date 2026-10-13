// MainColonyView.swift
// Main colony/planet overview screen. Reads the active colony from GameState.
//
// Phase 2 adds the Empire to this screen as two compact rows — the quota panel
// and, when one is on offer, the commission card. Structurally the screen is
// unchanged: its redesign is Phase 6, and absorbing a Grid readout, standing,
// quota status and throughput badges properly is that phase's job.

import SwiftUI

struct MainColonyView: View {
    @Environment(GameState.self) private var game
    @State private var activeCategory = 0

    /// Which commission offer has been waved away, so the card collapses to a
    /// line. Transient view state, not game state: **ignoring a commission is
    /// doing nothing**, so there is nothing to record in the model. Keyed on
    /// the contract's id, so the next offer arrives expanded.
    /// HELIOS.md §14, "transient view state stays local @State".
    @State private var setAsideCommissionID: Int?

    let categories = [
        ("bolt.fill", "Power"),
        ("shippingbox.fill", "Storage"),
        ("house.fill", "Habitat"),
        ("shield.lefthalf.filled", "Defense"),
        ("leaf.fill", "Life Support")
    ]

    var body: some View {
        ZStack(alignment: .top) {
            VoidBackground()

            PlanetBackdrop(
                diameter: 380,
                baseColor: game.activeColony.worldType?.baseColor ?? GameTheme.accent,
                bandColor: game.activeColony.worldType?.bandColor ?? GameTheme.voidTop,
                seed: game.activeColony.id.hashValue
            )
            .offset(y: -50)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text(game.activeColony.name.uppercased())
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(GameTheme.textSecondary)
                            .tracking(1)
                        Spacer()
                        CircleGlassButton(systemImage: "ellipsis")
                    }
                    .padding(.top, 8)

                    HStack(spacing: 10) {
                        ResourcePill(icon: "bolt.fill",
                                     value: "\(game.activeColony.gridUtilisationPercent)%",
                                     tint: game.activeColony.gridFactor < 1 ? GameTheme.warn : .yellow)
                        ResourcePill(icon: "wind",
                                     value: Format.decimal(game.activeColony.stock.amount(of: "oxygen")),
                                     tint: GameTheme.accent)
                        ResourcePill(icon: "dollarsign.circle.fill",
                                     value: Format.integer(game.credits),
                                     tint: .green)
                    }

                    PopulationPanel(population: game.activeColony.population)

                    quotaSection

                    commissionSection

                    HStack(spacing: 8) {
                        ForEach(categories.indices, id: \.self) { i in
                            Button {
                                activeCategory = i
                            } label: {
                                CategoryChip(
                                    icon: categories[i].0,
                                    label: categories[i].1,
                                    isActive: activeCategory == i,
                                    fillsWidth: true
                                )
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Production Chains")
                                .font(GameTheme.Font.sectionTitle)
                                .foregroundStyle(GameTheme.textPrimary)
                            Spacer()
                            NavigationLink(value: ProductionListNav.all) {
                                Text("View All")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(GameTheme.accent)
                            }
                            .buttonStyle(.plain)
                        }

                        VStack(spacing: 10) {
                            ForEach(game.activeColony.productionChains) { chain in
                                NavigationLink(value: chain.id) {
                                    ProductionChainRow(chain: chain)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, GameTheme.Spacing.lg)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - The Empire

    @ViewBuilder
    private var quotaSection: some View {
        if let quota = game.currentQuota {
            NavigationLink(value: QuotaDetailNav.current) {
                QuotaPanel(
                    band: game.standing.band,
                    reliability: game.standing.reliability,
                    fill: game.quotaFill,
                    minutesRemaining: game.quotaMinutesRemaining,
                    lineCount: quota.lineCount,
                    stipendIfMet: game.stipendForAMetQuota
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var commissionSection: some View {
        if let contract = game.commission {
            if setAsideCommissionID == contract.id && !contract.accepted {
                DismissedCommissionRow {
                    setAsideCommissionID = nil
                }
            } else {
                CommissionCard(
                    commission: contract,
                    progress: game.commissionProgress,
                    wouldBeMet: game.commissionWouldBeMet,
                    minutesRemaining: contract.minutesRemaining(atTick: game.tickCount),
                    shortfalls: shortfalls(for: contract),
                    onAccept: { game.acceptCommission() },
                    onIgnore: { setAsideCommissionID = contract.id }
                )
            }
        }
    }

    /// Goods the colony cannot currently cover from what the Empire is allowed
    /// to draw on. Shown before the player commits, because a commission is
    /// irreversible once accepted and the whole decision is "can I make this".
    private func shortfalls(for contract: Commission) -> [Resource.ID] {
        contract.sortedLines.compactMap { line in
            let available = QuotaLedger.drawable(line.good, from: game.activeColony.stock)
            return available < line.amount ? line.good : nil
        }
    }
}

#Preview {
    NavigationStack {
        MainColonyView()
            .navigationDestination(for: QuotaDetailNav.self) { _ in
                QuotaDetailView()
            }
    }
    .environment(GameState.seeded())
}
