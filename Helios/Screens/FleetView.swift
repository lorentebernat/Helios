// FleetView.swift
// Fleet overview: summary, ships under construction, and the active fleet.

import SwiftUI

struct FleetView: View {
    @Environment(GameState.self) private var game
    @State private var showingBuildSheet = false

    var body: some View {
        ZStack(alignment: .top) {
            VoidBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: GameTheme.Spacing.xl) {
                    HStack {
                        Text("FLEET")
                            .font(GameTheme.Font.label)
                            .foregroundStyle(GameTheme.textSecondary)
                            .tracking(1)
                        Spacer()
                        Button {
                            showingBuildSheet = true
                        } label: {
                            CircleGlassButton(systemImage: "plus")
                        }
                    }
                    .padding(.top, 8)

                    FleetSummaryStrip(ships: game.ships)

                    if !game.activeColony.shipyardQueue.isEmpty {
                        VStack(alignment: .leading, spacing: GameTheme.Spacing.sm) {
                            Text("Under Construction")
                                .font(GameTheme.Font.sectionTitle)
                                .foregroundStyle(GameTheme.textPrimary)

                            VStack(spacing: 10) {
                                ForEach(game.activeColony.shipyardQueue) { order in
                                    BuildOrderRow(order: order)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: GameTheme.Spacing.sm) {
                        Text("All Ships")
                            .font(GameTheme.Font.sectionTitle)
                            .foregroundStyle(GameTheme.textPrimary)

                        VStack(spacing: 10) {
                            ForEach(game.ships) { ship in
                                NavigationLink(value: ShipRouteTarget(shipID: ship.id)) {
                                    ShipRow(
                                        ship: ship,
                                        locationName: Destination.displayName(ship.locationID) ?? "Unknown",
                                        destinationName: Destination.displayName(ship.destinationID)
                                    )
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
        .sheet(isPresented: $showingBuildSheet) {
            BuildShipSheet()
        }
    }
}

#Preview {
    NavigationStack {
        FleetView()
    }
    .environment(GameState.seeded())
}
