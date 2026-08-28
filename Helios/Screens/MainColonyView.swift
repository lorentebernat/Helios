// MainColonyView.swift
// Main colony/planet overview screen. Reads the active colony from GameState.

import SwiftUI

struct MainColonyView: View {
    @Environment(GameState.self) private var game
    @State private var activeCategory = 0

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
                bandColor: game.activeColony.worldType?.bandColor ?? GameTheme.voidTop
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
}

#Preview {
    NavigationStack {
        MainColonyView()
    }
    .environment(GameState.seeded())
}
