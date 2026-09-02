// ProductionListView.swift
// Root screen for the Production tab: full list of chains, tap to see detail.
//
// Does NOT register .navigationDestination(for: ChainDetail.ID.self) itself —
// that's owned once per NavigationStack by whichever screen hosts the stack
// (RootView, for both tab 0 and tab 1). Registering it here too used to
// silently duplicate the tab-1 registration. HELIOS.md §18 S14.

import SwiftUI

struct ProductionListView: View {
    @Environment(GameState.self) private var game

    var body: some View {
        ZStack(alignment: .top) {
            VoidBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: GameTheme.Spacing.xl) {
                    HStack {
                        Text("PRODUCTION")
                            .font(GameTheme.Font.label)
                            .foregroundStyle(GameTheme.textSecondary)
                            .tracking(1)
                        Spacer()
                    }
                    .padding(.top, 8)

                    VStack(spacing: 10) {
                        ForEach(game.activeColony.productionChains) { chain in
                            NavigationLink(value: chain.id) {
                                ProductionChainRow(chain: chain)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, GameTheme.Spacing.lg)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    NavigationStack {
        ProductionListView()
            .navigationDestination(for: ChainDetail.ID.self) { id in
                ProductionDetailView(chainID: id)
            }
    }
    .environment(GameState.seeded())
}
