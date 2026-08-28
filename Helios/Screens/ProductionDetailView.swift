// ProductionDetailView.swift
// Detail screen for a single production chain. Looks the chain up LIVE in
// GameState by id so it ticks in real time; auto-dismisses if it's removed.

import SwiftUI

struct ProductionDetailView: View {
    let chainID: ChainDetail.ID
    @Environment(GameState.self) private var game
    @Environment(\.dismiss) private var dismiss

    private var chain: ChainDetail? {
        game.activeColony.productionChains.first { $0.id == chainID }
    }

    var body: some View {
        ZStack(alignment: .top) {
            VoidBackground()

            if let chain {
                content(for: chain)
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
        .onChange(of: chain == nil) { _, gone in
            if gone { dismiss() }
        }
    }

    @ViewBuilder
    private func content(for chain: ChainDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GameTheme.Spacing.xl) {
                HStack {
                    Button { dismiss() } label: {
                        CircleGlassButton(systemImage: "chevron.left")
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text(chain.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(GameTheme.textPrimary)
                        Text(chain.statusNote)
                            .font(GameTheme.Font.caption)
                            .foregroundStyle(chain.status.tint)
                        Text("\(chain.throughputPercent)% throughput")
                            .font(.system(size: 11))
                            .foregroundStyle(GameTheme.textSecondary)
                    }
                    Spacer()
                    CircleGlassButton(systemImage: "ellipsis")
                }
                .padding(.top, 8)

                if case .limited(.input(let resourceID)) = chain.status {
                    BlockedBanner(missingInputName: Resource.byID(resourceID)?.name ?? resourceID)
                }

                VStack(alignment: .leading, spacing: GameTheme.Spacing.sm) {
                    Text("Production Flow")
                        .font(GameTheme.Font.sectionTitle)
                        .foregroundStyle(GameTheme.textPrimary)

                    ChainFlowDiagram(
                        inputs: chain.inputs,
                        output: chain.output,
                        energyProduced: chain.energyProduced,
                        stock: game.activeColony.stock,
                        isLimited: !chain.status.isNominal
                    )
                    .padding(GameTheme.Spacing.lg)
                    .glass(cornerRadius: GameTheme.Radius.panel, strokeOpacity: GameTheme.GlassStroke.standard)

                    if chain.energyRequired > 0 {
                        Text("Draws \(Format.decimal(chain.energyRequired)) MW · grid at \(game.activeColony.gridUtilisationPercent)%")
                            .font(GameTheme.Font.caption)
                            .foregroundStyle(GameTheme.textSecondary)
                    }
                }

                WorkforceSection(
                    assigned: chain.workforceAssigned,
                    required: chain.workforceRequired,
                    requiredTier: chain.requiredTier
                )

                Spacer(minLength: 100)
            }
            .padding(.horizontal, GameTheme.Spacing.lg)
        }
    }
}

#Preview {
    let state = GameState.seeded()
    NavigationStack {
        ProductionDetailView(chainID: state.activeColony.productionChains[0].id)
    }
    .environment(state)
}
